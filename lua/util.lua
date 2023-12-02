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

-- A rudimentary way to figure out if buffer contents changed. 
-- Used to avoid re-parsing the same same content without any reason.
M.get_buf_content_fingerprint = function(buf_id)
    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    if #lines >= 4 then
        return #lines..lines[2]..lines[#lines-1]
    else
        return ""
    end
end

return M
