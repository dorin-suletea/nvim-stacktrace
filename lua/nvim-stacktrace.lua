local util = require("util")

--TODO:
-- documentation
-- stacktrace.

local default_config = {
    win_picker_blacklist = {"dap%-repl", "dap%-terminal", "DAP Stacks"},       -- when jumping to source never consider these buffer names as candidates
    highlight_group = "Tag",                                                   -- use this hl group for highlighting jumpable locations. Check ":hi" for default groups.
    jump_key = "<CR>",                                                         -- will open source code location when this key is pressed in one of the target buffers
}

local M = {}
M.config = {}
M.fingerprint_by_id = {}
M.highlight_ns = nil
M.jumpable = {}

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), config or {})
    M.highlight_ns = vim.api.nvim_create_namespace("nvim-stacktrace-hl")
    vim.api.nvim_set_hl(0, 'StackWinPicker', { bg = "#d79921", fg = "#000000" })
    vim.api.nvim_set_hl(0, 'StackWinPickerNC', { bg = "#d79922", fg = "#000001" })


    -- Re-parse and highlight repl when:
    -- 1) it became visible
    -- 2) nvim-dap finished execution and updated a potentially already visible window)
    local group = vim.api.nvim_create_augroup("nvim-stacktrace-group", { clear=true })
    vim.api.nvim_create_autocmd("BufEnter", { 
        group = group,
        pattern = "\\[dap-repl\\]",
        callback = M.run_repl
    })
    require('dap').listeners.after.event_terminated["dapui_config"] = M.run_repl
end

function M.do_highlight(buffer_id, jumpable_lines )
    vim.api.nvim_buf_clear_namespace(buffer_id, M.highlight_ns, 0, -1)
    for k,v in pairs(jumpable_lines) do
        vim.api.nvim_buf_set_extmark(buffer_id, M.highlight_ns, k, v.highlight.start_column, { end_row = k, end_col = v.highlight.end_column , hl_group = M.config.highlight_group })
    end
end

function M.jump()
    local current_buffer_id = vim.fn.bufnr("%")
    local cursor_line = vim.api.nvim__buf_stats(0).current_lnum

    -- if buffer was parsed
    local jumpable = M.jumpable[current_buffer_id]
    if jumpable ~=nil then
        -- and line contains a valid path
        local jump_point = jumpable[cursor_line - 1]
        if jump_point ~= nil then
            local target_win = M.window_picker(M.config.win_picker_blacklist)                                 -- select window to use
            if target_win ~=nil then
                vim.fn.win_gotoid(target_win)                                                                 -- focus it
                vim.cmd("edit ".."+"..jump_point.navigation.jump_line.." "..jump_point.navigation.file_path)  -- open file at line
            end
        end
    end
end


function M.run_repl()
    local id = vim.fn.bufnr("dap-repl")
    if id == -1 then
        return
    end

    print("running repl")
    local buffer_lines = vim.api.nvim_buf_get_lines(id, 0, -1, false)
    local lines_fingerprint = util.get_text_fingerprint(buffer_lines)

    if lines_fingerprint ~= M.fingerprint_by_id[id] then
        M.fingerprint_by_id[id] = lines_fingerprint
        local stack_lines = M.parse_repl_java_stack(buffer_lines)
        local jumpable_lines = M.retain_workspace_only(stack_lines)
        M.jumpable[id] = jumpable_lines
        vim.api.nvim_buf_set_keymap(id, "n", M.config.jump_key, [[:lua require('nvim-stacktrace').jump() <CR>]], {})
    end

    M.do_highlight(id, M.jumpable[id])
end
-- 
-- Parses java stack traces formatted to the rules of [dap-repl].
-- -- 
-- A stack line is formatted differently depending on the buffer it is displayed in,
-- but essentially it's the same information : class, package, line.
-- --
-- To support a different format or a different language a specialized parser must be provided
-- that can return the same navigation metadata.
-- 
function M.parse_repl_java_stack(lines)
    local stack_locations = {}
    for i, line in pairs(lines) do
        local tag_start,_ = string.find(line,"%(")
        local tag_end, _ = string.find(line,")")
        local line_delimiter = string.find(line,":")
        local file_type_delimiter = util.string_find_last(line,".")
        local at_delimiter = string.find(line,"at ")

        if tag_start ~= nil and tag_end ~= nil and line_delimiter ~= nil and file_type_delimiter ~=nil and at_delimiter ~=nil then
            local class_name =  string.sub(line, tag_start + 1, file_type_delimiter - 1)
            local line_in_class = string.sub(line, line_delimiter + 1, tag_end - 1)
            local package_and_method = string.sub(line, at_delimiter + 3, tag_start - 1)
            local package_name = string.sub(package_and_method, 0, string.find(package_and_method, class_name) - 2)
            stack_locations[i-1] = {
                highlight = {
                    start_column = tag_start,
                    end_column = tag_end - 1
                },
                navigation = {
                    class_name = class_name,
                    package_name = package_name,
                    jump_line = line_in_class
                }
            }
        end
    end
    return stack_locations
end

-- 
-- Retain only files present in user's workspace.
-- -- 
-- Receives a list of already parsed stack locations and returns a sub-set of files in any sub-folder of "." folder.
-- Since decompiling is not yet supported this is effectively "all files we know how to navigate to"
--
function M.retain_workspace_only(stack_locations)
    if #stack_locations == 0 then
        return {}
    end

    -- batch search everything in one go for big performance gains.
    local find_cmd = {"find", "."}
    for _, v in pairs(stack_locations) do
        local search = v.navigation.class_name..".java"
        if not util.list_contains(find_cmd, search) then
            table.insert(find_cmd, "-name")
            table.insert(find_cmd, search)
            table.insert(find_cmd, "-o")
        end
    end
    table.remove(find_cmd, #find_cmd)
    local output = vim.fn.system(find_cmd)
    local lines = util.string_split(output,"\n")

    -- map back file paths to class names.
    local keyed_paths = {}
    for _, line in pairs(lines) do
        local class_start = util.string_find_last(line,"/")
        local class_end = util.string_find_last(line,".")
        local key = string.sub(line, class_start + 1, class_end - 1)
        if (keyed_paths[key] == nil) then
            keyed_paths[key] = {}
        end
        table.insert(keyed_paths[key], line)
    end

    -- We might have classes with the same name but in different packages.
    -- Based on the package and path of the file determine which file each stack trace line jumps to
    local jumpable = {}
    for i, v in pairs(stack_locations) do
        local package_and_class_as_path = util.string_replace_all(v.navigation.package_name, "%.","/").."/"..v.navigation.class_name
        local paths = keyed_paths[v.navigation.class_name]
        if paths ~= nil then  --files with name were found
            for _, p in pairs(paths) do -- find the path corresponding to the package
               if string.find(p, package_and_class_as_path) ~=nil then
                jumpable[i] = {
                    highlight = {
                        start_column = v.highlight.start_column,
                        end_column = v.highlight.end_column
                    },
                    navigation = {
                        class_name = v.navigation.class_name,
                        package_name = v.navigation.package_name,
                        jump_line = v.navigation.jump_line,
                        file_path = p
                    }
                }
               end
            end
        end
    end
    return jumpable
end

-- 
-- Prompts the user to select which buffer to load the class source onto.
-- --
-- Receives a list of buffer names that might be editable but never eligible for opening code in.
-- For example if navigating from a repl trace to code you probably don't want to open the source in [dap-repl] buffer 
-- and lose the stacktrace.
-- --
-- Heavily inspired from : https://github.com/nvim-tree/nvim-tree.lua/blob/8c534822a7d16c83cf69928c53e1d8a13bd2734a/lua/nvim-tree/actions/node/open-file.lua#L121
function M.window_picker(blacklist)
    local usable = {}
    local all_windows = util.get_all_visible_buffers()

    -- Search all open windows and retain only editable ones 
    -- that are not holding a blacklisted buffer.
    for name, info in pairs(all_windows) do
        local win_config = vim.api.nvim_win_get_config(info.win_id)
        local is_blacklisted = util.matches_any(name, blacklist)
        if win_config.focusable
            and not win_config.external
            and not is_blacklisted then
                table.insert(usable, info.win_id)
        end
    end

    -- no eligible windows present
    if #usable == 0 then
        print("error : no eligible window to pick")
        return nil
    end
    -- only one eligible window, return it
    if #usable == 1 then
        return usable[1]
    end
    -- many windows are eligible, make the user select the window
    for i, id in pairs(usable) do
        vim.api.nvim_win_set_option(id, "statusline", "%=" .. i .. "%=")
        vim.api.nvim_win_set_option(id, "winhl", "StatusLine:StackWinPicker,StatusLineNC:StackWinPickerNC")
    end
    vim.cmd "redraw"

    -- get the user selection
    print("Pick window")
    local c = vim.fn.getchar()
    while type(c) ~= "number" do
        c = vim.fn.getchar()
    end
    local user_selection = tonumber(vim.fn.nr2char(c))
    vim.cmd("normal! :")

    if user_selection == nil or user_selection>#usable then
        print("error : Invalid selection "..(user_selection or "nil").." valid range 1.."..#usable)
        return nil
    end

    return usable[user_selection]
end


-- BINGO : this is written in 1 go. We can read the lines like this & use the repl with another strategy.
--
--TODO: 'o' keybinding already jumps to location. we only need to hl
-- TODO: this is sensible but how to know when the entire buffer is written?
function experiment()
    vim.api.nvim_buf_attach(0, true, { 
        on_lines = function (line, handle, tick, first_line, last_line, bytecount,_,_) 

            local buffer_lines = vim.api.nvim_buf_get_lines(handle, 0, -1, false)
            print(vim.inspect(buffer_lines))
        end
    })
        -- local id = vim.fn.bufnr("DAP Stacks")

        -- local buffer_lines = vim.api.nvim_buf_get_lines(id, 0, -1, false)
        -- print(id)
        -- print(vim.inspect(buffer_lines))
        
end

vim.keymap.set("n", "dx", M.run_repl, {desc = 'exp'})

return M
