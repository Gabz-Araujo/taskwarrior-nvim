--- Logging utilities for Taskwarrior.nvim
--- @module taskwarrior.utils.logger

local M = {}

-- Default configuration
local config = {
	level = "debug", -- debug, info, warn, error
	use_console = true, -- Whether to log to console
	file = nil, -- Path to log file (nil to disable file logging)
}

-- Log level mapping
local LEVELS = {
	debug = 1,
	info = 2,
	warn = 3,
	error = 4,
}

-- Configure the logger
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- Create log directory if logging to file
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- Create log directory if logging to file
	if config.file then
		local log_dir = vim.fn.fnamemodify(config.file, ":h")
		if vim.fn.isdirectory(log_dir) == 0 then
			vim.fn.mkdir(log_dir, "p")
		end
	end
end

--- Internal logging function
--- @param level string Log level
--- @param msg string Message to log
--- @param ... any Additional values to format
local function log(level, msg, ...)
	if LEVELS[level] < LEVELS[config.level] then
		return
	end

	-- Format the message with any additional arguments
	local formatted_msg
	if select("#", ...) > 0 then
		formatted_msg = string.format(msg, ...)
	else
		formatted_msg = msg
	end

	-- Add timestamp and level
	local entry = string.format("[%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level:upper(), formatted_msg)

	if config.use_console then
		print(entry)
	end

	-- Log to file if configured
	if config.file then
		local file = io.open(config.file, "a")
		if file then
			file:write(entry .. "\n")
			file:close()
		end
	end
end

-- Public logging functions
function M.debug(msg, ...)
	log("debug", msg, ...)
end
function M.info(msg, ...)
	log("info", msg, ...)
end
function M.warn(msg, ...)
	log("warn", msg, ...)
end
function M.error(msg, ...)
	log("error", msg, ...)
end

--- Log a table's contents (useful for debugging)
--- @param tbl table Table to log
--- @param name string? Optional name for the table
--- @param level string? Optional log level (defaults to "debug")
function M.table(tbl, name, level)
	level = level or "debug"
	name = name or "table"

	if LEVELS[level] < LEVELS[config.level] then
		return
	end

	local function inspect_table(t, indent, visited)
		visited = visited or {}
		indent = indent or 0
		if visited[t] then
			return "{ ... recursive ... }"
		end
		visited[t] = true

		local result = "{\n"
		local indent_str = string.rep("  ", indent + 1)

		for k, v in pairs(t) do
			local key_str = type(k) == "string" and k or "[" .. tostring(k) .. "]"
			result = result .. indent_str .. key_str .. " = "

			if type(v) == "table" then
				result = result .. inspect_table(v, indent + 1, visited) .. ",\n"
			elseif type(v) == "string" then
				result = result .. '"' .. v .. '",\n'
			else
				result = result .. tostring(v) .. ",\n"
			end
		end

		result = result .. string.rep("  ", indent) .. "}"
		return result
	end

	log(level, "%s: %s", name, inspect_table(tbl))
end

return M
