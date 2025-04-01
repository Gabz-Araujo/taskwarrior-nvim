local M = {}
local api = require("taskwarrior.api")

local cache = {
	data = nil,
	timestamp = 0,
	ttl = 60, -- seconds
}

function M.get_statusline(format)
	if cache.data and (os.time() - cache.timestamp) < cache.ttl then
		return M.format_statusline(cache.data, format)
	end

	local pending_count = vim.fn.trim(vim.fn.system("task status:pending count"))
	local urgent_count = vim.fn.trim(vim.fn.system("task +PRIORITY.above:M +PENDING count"))
	local overdue_count = vim.fn.trim(vim.fn.system("task +OVERDUE count"))

	cache.data = {
		count = pending_count,
		urgent = urgent_count,
		overdue = overdue_count,
	}
	cache.timestamp = os.time()

	return M.format_statusline(cache.data, format)
end

function M.format_statusline(data, format)
	format = format or "Tasks: %count% (%urgent% urgent)"

	local result = format
	result = result:gsub("%%count%%", data.count)
	result = result:gsub("%%urgent%%", data.urgent)
	result = result:gsub("%%overdue%%", data.overdue)

	return result
end

function M.reset_cache()
	cache.data = nil
	cache.timestamp = 0
end

function M.lualine()
	return M.get_statusline()
end

return M
