## Configuration

Configure tdd.nvim using the `setup()` function. The configuration separates **runners** (test execution logic) from **languages** (file patterns).

### Example: Run tests in tmux with Docker

```lua
local tdd = require('tdd')

tdd.setup({
    runners = {
        pest = {
            get_test_name = function()
                local line = vim.fn.getline('.')
                local test_name = line:match("function%s+test([%w_]+)") or line:match("test%s*%(%-*%s*'([^']+)'") or line:match('test%s*%(%-*%s*"([^"]+)"')
                return test_name, vim.fn.line('.')
            end,
            command = function(file, test_name, line_number)
                if test_name then
                    return string.format('magnus pest --stop-on-defect %s --filter "%s"', file, test_name)
                else
                    return string.format('magnus pest --stop-on-defect %s', file)
                end
            end,
            run_test = function(command)
                vim.fn.system(string.format('tmux select-window -t %q', 2))
                vim.wait(100)
                vim.fn.system(string.format("tmux send-keys -t %s '%s' C-m", 2, command))
            end,
        },
        vitest = {
            get_test_name = function()
                local line = vim.fn.getline('.')
                local test_name = line:match("test%s*%(%-*%s*'([^']+)'") or line:match('test%s*%(%-*%s*"([^"]+)"') or line:match("it%s*%(%-*%s*'([^']+)'") or line:match('it%s*%(%-*%s*"([^"]+)"')
                return test_name, vim.fn.line('.')
            end,
            command = function(file, test_name, line_number)
                if line_number then
                    return string.format('magnus npm run test:run -- %s:%s', file, line_number)
                else
                    return string.format('magnus npm run test:run -- %s', file)
                end
            end,
            run_test = function(command)
                vim.fn.system(string.format('tmux select-window -t %q', 2))
                vim.wait(100)
                vim.fn.system(string.format("tmux send-keys -t %s '%s' C-m", 2, command))
            end,
        },
        pytest = {
            get_test_name = function()
                local line = vim.fn.getline('.')
                local test_name = line:match("def%s+(test_[%w_]+)") or line:match("def%s+(Test[%w_]+)")
                return test_name, vim.fn.line('.')
            end,
            command = function(file, test_name, line_number)
                if test_name then
                    return string.format('magnus pytest %s::%s', file, test_name)
                else
                    return string.format('magnus pytest %s', file)
                end
            end,
            run_test = function(command)
                vim.fn.system(string.format('tmux select-window -t %q', 2))
                vim.wait(100)
                vim.fn.system(string.format("tmux send-keys -t %s '%s' C-m", 2, command))
            end,
        },
    },
})

-- Keybindings
vim.keymap.set("n", "<leader>tt", function()
    tdd.jump(true)
end, { desc = "Jump to test or SUT" })

vim.keymap.set("n", "<leader>tj", function()
    tdd.jump(false)
end, { desc = "Goto the sut or show all test options to select from" })

vim.keymap.set("n", "<leader>tr", function()
    tdd.run_test_file()
end, { desc = "Run the current test file" })

vim.keymap.set('n', '<leader>tf', function()
    tdd.run_test()
end, { desc = "Run the current test" })
```

### Example: Run tests locally

```lua
local tdd = require('tdd')

tdd.setup({
    runners = {
        pest = {
            get_test_name = function() return vim.fn.inputlist({ 'Select test:' }), nil end,
            run_test = function(file, test_name, line_number)
                vim.fn.system(string.format("pest %s --filter=%s", file, test_name))
            end,
        },
    },
})
```

### Swapping Runners

You can change which runner a language uses without modifying language configurations:

```lua
tdd.setup({
    runners = {
        phpunit = {
            run_test = function(file, test_name, line_number)
                vim.fn.system(string.format("phpunit %s", file))
            end,
        },
    },
    languages = {
        php = {
            runner = 'phpunit',  -- Switch from 'pest' to 'phpunit'
        },
    }
})
```
