local util = require("util")

local default_config = {
    target_buffers = {"[dap-repl]"},
    win_picker_blacklist = {"[dap-repl]"}
}


local M = {}
M.config = nil

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), config or {})
    print("config "..vim.inspect(M.config))
end


local function run()
    local all_buffers = util.get_all_visible_buffers()
    print(vim.inspect(all_buffers))

    -- TODO: filter out only buffers in the target list and loop over them
    local lines = vim.api.nvim_buf_get_lines(all_buffers["[dap-repl]"], 0, -1, false)
    print(vim.inspect(lines))

    -- for i , target in pairs(M.config.target_buffers) do
        -- local target_id = vim.fn.bufnr(target)
        -- lua print(vim.fn.bufnr("dap-repl"))
        -- print (target..(target_id or "missing"))
    -- end

end


vim.keymap.set("n", "dx", run, {desc = 'exp'})
    -- local repl_id = vim.fn.bufnr(config.target_buffer)

return M
