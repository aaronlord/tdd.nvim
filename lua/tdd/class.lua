local M = {}

M.public_methods = function(path)
    if not path or path == '' then
        return {}
    end

    if not vim.fn.filereadable(path) then
        return {}
    end

    local content = table.concat(vim.fn.readfile(path), "\n")
    local methods = {}

    for method_name in string.gmatch(content, "public%s+function%s+([%w_]+)%s*%(") do
        if method_name ~= "__construct"
            and method_name ~= "__destruct"
            and method_name ~= "__toString"
            and method_name ~= "__get"
            and method_name ~= "__set"
        then
            table.insert(methods, method_name)
        end
    end

    return methods
end

return M
