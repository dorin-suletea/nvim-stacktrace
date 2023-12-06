M = {}

M.string_split = function(input, separator)
    local ret = {}
    for part in string.gmatch(input, "([^"..separator.."]+)") do
        table.insert(ret, part)
    end
    return ret
end

M.string_replace_all = function(input, what, with)
    return string.gsub(input, what, with)
end

M.string_find_last = function(input, what)
    return string.find(input, what.."[^"..what.."]*$")
end

M.list_contains = function(list, x)
	for _, v in pairs(list) do
		if v == x then return true end
	end
	return false
end

M.matches_any = function (input, pattern_list)
    for _, i in pairs(pattern_list or {}) do
        if string.match(input, i) ~=nil then
            return true
        end
    end
    return false
end

-- A rudimentary way to figure out if buffer contents changed. 
-- Used to avoid re-parsing the same same content without any reason.
M.get_text_fingerprint = function(lines)
    if #lines >= 4 then
        return #lines..lines[2]..lines[#lines-1]
    else
        return ""
    end
end

M.get_all_visible_buffers = function ()
    local ret = {}
    local tab_page = vim.api.nvim_get_current_tabpage()
    local all_windows = vim.api.nvim_tabpage_list_wins(tab_page)
    for _, id in pairs(all_windows) do
        local win_buf_id = vim.api.nvim_win_get_buf(id)
        local win_buf_name = vim.api.nvim_buf_get_name(win_buf_id)
        local short_name_location = string.find(win_buf_name, "[^/]*$") or 0
        local win_buf_short_name = string.sub(win_buf_name, short_name_location, -1)

        ret[win_buf_short_name] = { win_buf_id = win_buf_id, win_id = id }
    end
    return ret
end

return M
