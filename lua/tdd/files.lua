local class = require('tdd.class')

local function pluralize(word)
    if word == nil
        or word == ''
        or word == 'Xhr'
        or word == 'Api'
        -- (or v1, v2, etc.)
        or word:match("^v%d+$")
    then
        return word
    end

    local last_char = string.sub(word, -1)
    local second_last_char = string.sub(word, -2, -2)

    if last_char == "s" or last_char == "x" or last_char == "z" or
        (last_char == "h" and (second_last_char == "c" or second_last_char == "s")) then
        return word .. "es"
    elseif last_char == "y" then
        return string.sub(word, 1, -2) .. "ies"
    else
        return word .. "s"
    end
end

local project_root = nil;

local M = {}

M.project_root = function()
    if project_root then
        return project_root
    end

    local root_markers = { '.git', 'composer.json', 'artisan' }
    local path = vim.fn.expand('%:p:h')

    while path ~= '/' do
        for _, root_file in ipairs(root_markers) do
            if vim.fn.filereadable(path .. '/' .. root_file) == 1
                or vim.fn.isdirectory(path .. '/' .. root_file) == 1
            then
                project_root = path

                return project_root
            end
        end

        path = vim.fn.fnamemodify(path, ':h')
    end

    return nil
end

-- current file path, relative to project root
M.current_file = function()
    local root = M.project_root()

    if not root then
        return nil
    end

    local current_file = vim.fn.expand('%:p')

    if not current_file or current_file == '' then
        return nil
    end

    return current_file:sub(#root + 2) -- +2 to remove the leading '/'
end

M.create_file = function(file, content)
    if not file or file == '' then
        return
    end

    local full_path = M.project_root() .. '/' .. file

    if M.exists(full_path) then
        return full_path
    end

    local file_dir = vim.fn.fnamemodify(full_path, ":h")

    if vim.fn.isdirectory(file_dir) == 0 then
        vim.fn.mkdir(file_dir, "p")
    end

    vim.fn.writefile(content, full_path)

    return full_path
end

M.open = function(file, create_if_not_exists)
    create_if_not_exists = create_if_not_exists or false

    if not file or file == '' then
        return
    end

    local full_path = M.project_root() .. '/' .. file

    if M.exists(full_path) then
        vim.cmd('edit ' .. full_path)
        return
    end

    if create_if_not_exists == true then
        vim.cmd('edit ' .. M.create_file(file, { "" }))
        return
    end

    print('File does not exist: ' .. full_path)
end

M.is_test = function(file)
    return file:match('tests/.*%Test.php$')
end

M.is_sut = function(file)
    return not M.is_test(file)
end

M.is_controller = function(file)
    return file:find("Http")
        and file:find("Controllers")
        and file:match('%Controller.php$')
end

M.exists = function(file)
    if not file or file == '' then
        return false
    end

    -- if file starts with M.project_root(), remove it
    if file:sub(1, #M.project_root()) == M.project_root() then
        file = file:sub(#M.project_root() + 2)
    end

    return vim.fn.filereadable(M.project_root() .. '/' .. file) == 1
end

local clean_controller_path = function(path)
    local s = path:match("Controllers/(.+)")

    if not s then return nil end

    s = s:gsub("%.php$", "")

    s = s:gsub("Controller$", "")

    return s
end

M.get_tests = function(sut_file)
    local files = {}

    if not sut_file or sut_file == '' or M.is_test(sut_file) then
        return files
    end

    if M.is_controller(sut_file) then
        local methods = class.public_methods(M.project_root() .. '/' .. sut_file)

        for _, method in pairs(methods) do
            -- Just get the file name, without the path and extension
            local combined = clean_controller_path(sut_file)

            if not combined or combined == '' then
                break
            end

            method = method:gsub('^%l', string.upper)

            local parts = {}

            local count = nil

            for part, i in combined:gmatch("[^/]+") do
                count = i

                table.insert(parts, part)
            end

            table.insert(parts, count)

            local last_part = parts[#parts]

            table.remove(parts, #parts)

            for i = 1, #parts do
                parts[i] = pluralize(parts[i])
            end

            if method == '__invoke' then
                table.insert(parts, last_part)
            else
                table.insert(parts, pluralize(last_part))
                table.insert(parts, method)
            end

            table.insert(files, 'tests/Http/' .. table.concat(parts, '/') .. 'Test.php')
        end
    else
        -- Remove the first part of the path, which is typically 'app'
        local test_file = sut_file:sub(sut_file:find('/') + 1):gsub('%.php$', 'Test.php')

        table.insert(files, 'tests/Unit/' .. test_file)
        table.insert(files, 'tests/Feature/' .. test_file)
    end

    return files
end

M.find_sut = function(test_file)
    if not test_file
        or test_file == ''
        or not M.is_test(test_file)
    then
        return nil
    end

    local sut_file = test_file
        :gsub('^tests/[^/]+/', 'app/')
        :gsub('Test%.php$', '.php')

    if not M.exists(sut_file) then
        return nil
    end

    return sut_file
end

M.select_from_files = function(files, create_if_not_exists)
    create_if_not_exists = create_if_not_exists or false

    if #files == 0 then
        return
    end

    table.sort(files, function(a, b)
        return M.exists(a) and not M.exists(b)
    end)

    vim.ui.select(
        files,
        {
            prompt = 'Jump to a file',
            format_item = function(item)
                -- Signify files that do not exist with a *
                return (M.exists(item) and '  ' or '* ') .. item
            end
        },
        function(selected)
            if not selected or selected == '' then
                return
            end

            M.open(selected:gsub('^* ', ''), create_if_not_exists)
        end
    )
end

M.find_sut('tests/Unit/Foo/Bar/ExampleTest.php')

return M
