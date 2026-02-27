local project_root = nil
local config = require('tdd.config')

local M = {}

M.project_root = function()
    if project_root then
        return project_root
    end

    local root_markers = { '.git', 'composer.json', 'package.json' }
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

M.current_ft = function()
    return vim.bo.filetype
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
    local cfg = config.get_config_for_file(file)
    if cfg.is_test then
        return cfg.is_test(file)
    end
    return false
end

M.is_sut = function(file)
    return not M.is_test(file)
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

M.get_tests = function(sut_file)
    local cfg = config.get_config_for_file(sut_file)
    if cfg.get_tests then
        return cfg.get_tests(sut_file)
    end
    return {}
end

M.find_sut = function(test_file)
    local cfg = config.get_config_for_file(test_file)
    if cfg.find_sut then
        local sut = cfg.find_sut(test_file)
        if sut and M.exists(sut) then
            return sut
        end
    end
    return nil
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

M.setup = function(opts)
    -- Config setup is done in init.lua
end

return M
