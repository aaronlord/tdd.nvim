local M = {}

-- Simple default run_test that opens a floating terminal
local function default_run_test(command)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded'
    })

    vim.cmd('terminal ' .. command)

    -- Close buffer when window is closed
    vim.api.nvim_create_autocmd('WinClosed', {
        pattern = tostring(win),
        callback = function()
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end,
    })

    -- Allow q to close the window
    vim.keymap.set('n', 'q', function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, { buffer = buf, noremap = true })
end

-- Helper to create get_test_name from patterns
local function make_get_test_name(patterns)
    return function()
        local buf = vim.api.nvim_get_current_buf()
        local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        for i = cursor_row, 1, -1 do
            local line = lines[i]
            for _, pattern in ipairs(patterns) do
                local name = line:match(pattern)
                if name and name ~= "#[test]" then
                    return name, i
                end
            end
        end
        return nil, nil
    end
end

-- Helper to create command builder
local function make_command(base_cmd, with_filter)
    return function(file, test_name, line_number)
        local root = require('tdd.files').project_root()
        local full_path = root .. '/' .. file
        local cmd = base_cmd .. ' ' .. vim.fn.shellescape(full_path)

        if test_name and with_filter then
            if with_filter == 'filter' then
                cmd = cmd .. ' --filter=' .. vim.fn.shellescape(test_name)
            elseif with_filter == 'scope' then
                cmd = cmd .. '::' .. vim.fn.shellescape(test_name)
            elseif with_filter == 'pytest' then
                cmd = cmd .. '::' .. vim.fn.shellescape(test_name)
            end
        end
        return cmd
    end
end

local defaults = {
    -- Test runners with their execution logic
    runners = {
        pest = {
            get_test_name = make_get_test_name({
                "it%(%s*['\"]([^'\"]+)['\"]",
            }),
            command = make_command('php artisan test', 'filter'),
            run_test = default_run_test,
        },
        phpunit = {
            get_test_name = make_get_test_name({
                "function%s+([a-zA-Z_][a-zA-Z0-9_]*)",
            }),
            command = make_command('phpunit', 'filter'),
            run_test = default_run_test,
        },
        vitest = {
            get_test_name = make_get_test_name({
                "it%(%s*['\"]([^'\"]+)['\"]",
                "test%(%s*['\"]([^'\"]+)['\"]",
            }),
            command = function(file, test_name, line_number)
                local root = require('tdd.files').project_root()
                local full_path = root .. '/' .. file
                local cmd = 'npm run test -- ' .. vim.fn.shellescape(full_path)
                if test_name and line_number then
                    cmd = cmd .. ':' .. line_number .. ' --reporter=verbose'
                end
                return cmd
            end,
            run_test = default_run_test,
        },
        pytest = {
            get_test_name = make_get_test_name({
                "def%s+([a-zA-Z_][a-zA-Z0-9_]*)",
            }),
            command = make_command('pytest', 'pytest'),
            run_test = default_run_test,
        },
        cargo = {
            get_test_name = make_get_test_name({
                "#%[test%]",
                "fn%s+([a-zA-Z_][a-zA-Z0-9_]*)",
            }),
            command = function(file, test_name, line_number)
                local cmd = 'cargo test'
                if test_name then
                    cmd = cmd .. ' ' .. vim.fn.shellescape(test_name)
                end
                return cmd
            end,
            run_test = default_run_test,
        },
    },

    -- Languages with file patterns and runner selection
    languages = {
        php = {
            is_test = function(file)
                return file:match('tests/.*%Test%.php$') ~= nil
            end,
            get_tests = function(sut_file)
                local files = {}
                if not sut_file or sut_file == '' then
                    return files
                end

                local test_file = sut_file
                    :sub(sut_file:find('/') + 1)
                    :gsub('%.php$', 'Test.php')

                table.insert(files, 'tests/Unit/' .. test_file)
                table.insert(files, 'tests/Feature/' .. test_file)
                table.insert(files, 'tests/Http/' .. test_file)
                table.insert(files, 'tests/Console/' .. test_file)
                table.insert(files, 'tests/Browser/' .. test_file)

                return files
            end,
            find_sut = function(test_file)
                if not test_file or test_file == '' then
                    return nil
                end

                local sut_file = test_file
                    :gsub('^tests/[^/]+/', 'app/')
                    :gsub('Test%.php$', '.php')

                return sut_file
            end,
            runner = 'pest',
        },
        rust = {
            is_test = function(file)
                return file:match('.*tests/.*%.rs$') ~= nil or file:match('.*/.*_test%.rs$') ~= nil
            end,
            get_tests = function(sut_file)
                local files = {}
                if not sut_file or sut_file == '' then
                    return files
                end

                local without_ext = sut_file:gsub('%.rs$', '')
                table.insert(files, without_ext .. '_test.rs')
                table.insert(files, 'tests/' .. vim.fn.fnamemodify(without_ext, ':t') .. '_test.rs')

                return files
            end,
            find_sut = function(test_file)
                if not test_file or test_file == '' then
                    return nil
                end

                local sut_file = test_file
                    :gsub('_test%.rs$', '.rs')
                    :gsub('^tests/', 'src/')

                return sut_file
            end,
            runner = 'cargo',
        },
        python = {
            is_test = function(file)
                return file:match('.*test_.*%.py$') ~= nil or file:match('.*/tests/.*%.py$') ~= nil
            end,
            get_tests = function(sut_file)
                local files = {}
                if not sut_file or sut_file == '' then
                    return files
                end

                local dir = vim.fn.fnamemodify(sut_file, ':h')
                local name = vim.fn.fnamemodify(sut_file, ':t'):gsub('%.py$', '')

                table.insert(files, dir .. '/test_' .. name .. '.py')
                table.insert(files, 'tests/test_' .. name .. '.py')

                return files
            end,
            find_sut = function(test_file)
                if not test_file or test_file == '' then
                    return nil
                end

                local sut_file = test_file
                    :gsub('^tests/', 'src/')
                    :gsub('^test_', '')

                return sut_file
            end,
            runner = 'pytest',
        },
        typescript = {
            is_test = function(file)
                return file:match('%.test%.ts$') ~= nil or file:match('%.test%.tsx$') ~= nil or
                    file:match('.*/tests/.*%.ts$') ~= nil
            end,
            get_tests = function(sut_file)
                local files = {}
                if not sut_file or sut_file == '' then
                    return files
                end

                local without_ext = sut_file:gsub('%.tsx?$', ''):gsub('%.vue$', '')
                table.insert(files, without_ext .. '.test.ts')
                table.insert(files, without_ext .. '.test.tsx')
                table.insert(files, 'tests/' .. vim.fn.fnamemodify(without_ext, ':t') .. '.test.ts')

                return files
            end,
            find_sut = function(test_file)
                if not test_file or test_file == '' then
                    return nil
                end

                -- Try .ts first, then .vue
                local ts_file = test_file
                    :gsub('%.test%.tsx?$', '.ts')
                    :gsub('^tests/', 'src/')
                
                local vue_file = test_file
                    :gsub('%.test%.tsx?$', '.vue')
                    :gsub('^tests/', 'src/')
                
                -- Return vue if it exists, otherwise ts
                if vim.fn.filereadable(vue_file) == 1 then
                    return vue_file
                end
                return ts_file
            end,
            runner = 'vitest',
        },
        vue = {
            is_test = function(file)
                return file:match('%.test%.ts$') ~= nil or file:match('.*/tests/.*%.ts$') ~= nil
            end,
            get_tests = function(sut_file)
                local files = {}
                if not sut_file or sut_file == '' then
                    return files
                end

                local without_ext = sut_file:gsub('%.vue$', '')
                table.insert(files, without_ext .. '.test.ts')
                table.insert(files, 'tests/' .. vim.fn.fnamemodify(without_ext, ':t') .. '.test.ts')

                return files
            end,
            find_sut = function(test_file)
                if not test_file or test_file == '' then
                    return nil
                end

                local sut_file = test_file
                    :gsub('%.test%.ts$', '.vue')
                    :gsub('^tests/', 'src/')

                return sut_file
            end,
            runner = 'vitest',
        },
    },
}

local user_config = {}

function M.setup(opts)
    opts = opts or {}
    user_config = opts
end

function M.get_language_config(filetype)
    if not filetype or filetype == '' then
        return nil
    end

    local lang = nil

    -- Start with defaults
    if defaults.languages[filetype] then
        lang = vim.deepcopy(defaults.languages[filetype])
    end

    -- Merge user config
    if user_config.languages and user_config.languages[filetype] then
        if lang then
            for k, v in pairs(user_config.languages[filetype]) do
                lang[k] = v
            end
        else
            lang = user_config.languages[filetype]
        end
    end

    return lang
end

function M.get_runner(filetype)
    local lang_cfg = M.get_language_config(filetype)

    if not lang_cfg then
        return nil
    end

    local runner_name = lang_cfg.runner
    if not runner_name then
        return nil
    end

    local runner = nil

    -- Start with defaults
    if defaults.runners[runner_name] then
        runner = vim.deepcopy(defaults.runners[runner_name])
    end

    -- Merge user config runners
    if user_config.runners and user_config.runners[runner_name] then
        if runner then
            for k, v in pairs(user_config.runners[runner_name]) do
                runner[k] = v
            end
        else
            runner = user_config.runners[runner_name]
        end
    end

    return runner
end

function M.get_test_name(filetype)
    local runner = M.get_runner(filetype)

    if not runner or not runner.get_test_name then
        return nil, nil
    end

    return runner.get_test_name()
end

function M.run_test(file, test_name, line_number, filetype)
    local runner = M.get_runner(filetype)

    if not runner or not runner.run_test then
        vim.notify("No test runner configured for file type: " .. (filetype or "unknown"), vim.log.levels.WARN)
        return
    end

    -- If runner has a command builder, use it
    if runner.command then
        local command = runner.command(file, test_name, line_number)
        runner.run_test(command)
    else
        -- Backward compatibility: call run_test directly with old signature
        runner.run_test(file, test_name, line_number)
    end
end

function M.get_config_for_file(file)
    if not file or file == '' then
        return nil
    end

    -- Get extension from file path
    local ext = file:match("%.([^.]+)$")
    if not ext then
        return nil
    end

    -- Map common extensions to filetypes
    local ext_to_ft = {
        php = 'php',
        rs = 'rust',
        py = 'python',
        ts = 'typescript',
        vue = 'vue',
    }

    local filetype = ext_to_ft[ext]
    if not filetype then
        return nil
    end

    return M.get_language_config(filetype)
end

return M
