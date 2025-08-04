local files = require('tdd.files')

local M = {}

M.jump_to_test = function(open_only)
    open_only = open_only or false

    if not files.project_root() then
        return
    end

    local current_file = files.current_file()

    if files.is_test(current_file) then
        return
    end

    local test_files = files.get_tests(current_file)

    if open_only == true then
        -- filter out files that do not exsit
        test_files = vim.tbl_filter(function(file)
            return files.exists(file)
        end, test_files)

        if #test_files == 1 then
            files.open(test_files[1], false)
            return
        end
    end

    files.select_from_files(test_files, true)
end

M.jump_to_sut = function()
    if not files.project_root() then
        return
    end

    local current_file = files.current_file()

    if files.is_sut(current_file) then
        return
    end

    local sut_file = files.find_sut(current_file)

    files.open(sut_file, false)
end

M.jump = function(open_only)
    open_only = open_only or false

    if not files.project_root() then
        return
    end

    local current_file = files.current_file()

    if files.is_test(current_file) then
        M.jump_to_sut()
    else
        M.jump_to_test(open_only)
    end
end

M.when_test = function(fn)
    if not files.project_root() then
        return
    end

    local current_file = files.current_file()

    if not files.is_test(current_file) then
        return
    end

    fn(current_file)
end

M.setup = function(opts)
    opts = opts or {}
end

return M
