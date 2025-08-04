local files = require('tdd.files')

local M = {}

M.jump_to_test = function()
    if not files.project_root() then
        return
    end

    local current_file = files.current_file()

    if files.is_test(current_file) then
        return
    end

    local test_files = files.get_tests(current_file)

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

M.jump = function()
    if not files.project_root() then
        return
    end

    local current_file = files.current_file()

    if files.is_test(current_file) then
        M.jump_to_sut()
    else
        M.jump_to_test()
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
