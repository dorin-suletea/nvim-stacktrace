local util = require("util")
local default_config = {
    win_picker_blacklist = {"[dap-repl]"}
}


local M = {}
M.config = nil

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), config or {})
    print("config "..vim.inspect(M.config))
    util.foo()
end

return M
