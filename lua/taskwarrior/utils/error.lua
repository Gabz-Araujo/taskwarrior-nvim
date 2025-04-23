--- Error handling utilities for Taskwarrior.nvim
--- @module taskwarrior.utils.error

local M = {}

--- Error types
M.ERROR_TYPE = {
	VALIDATION = "ValidationError",
	TASKWARRIOR = "TaskwarriorError",
	PARSER = "ParserError",
	FILESYSTEM = "FileSystemError",
	CONFIG = "ConfigError",
	NETWORK = "NetworkError",
	INTERNAL = "InternalError",
}

--- Error levels
M.ERROR_LEVEL = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	CRITICAL = 5,
}

-- Default configuration (can be overridden by user config)
local config = {
	log_level = M.ERROR_LEVEL.WARN, -- Default log level
	log_to_file = false, -- Whether to log to file
	log_path = vim.fn.stdpath("data") .. "/taskwarrior_nvim.log", -- Log file path
	silent = false, -- Whether to show error messages to user
}

--- @class Error
--- @field message string Error message
--- @field type string Error type (from ERROR_TYPE)
--- @field level number Error level (from ERROR_LEVEL)
--- @field traceback string Error traceback
--- @field timestamp number Error timestamp
--- @field context table? Additional error context
local Error = {}
Error.__index = Error

--- Error constructor
--- @param message string Error message
--- @param type string Error type (from ERROR_TYPE)
--- @param level number Error level (from ERROR_LEVEL)
--- @param context table? Additional error context
--- @return Error Error object
function Error:new(message, type, level, context)
	local self = setmetatable({}, Error)
	self.message = message
	self.type = type or M.ERROR_TYPE.INTERNAL
	self.level = level or M.ERROR_LEVEL.ERROR
	self.traceback = debug.traceback()
	self.timestamp = os.time()
	self.context = context or {}
	return self
end

--- Configure error handling
--- @param opts table Configuration options
function M.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)
end

--- Create a new error object with context
--- @param message string Error message
--- @param type string Error type (from ERROR_TYPE)
--- @param level number Error level (from ERROR_LEVEL)
--- @param context table? Additional error context
--- @return Error Error object
function M.create_error(message, type, level, context)
	local err = Error:new(message, type, level, context)

	-- Log the error
	M.log_error(err)

	return err
end

--- Create a validation error
--- @param message string Error message
--- @param field string? Field that failed validation
--- @param value any? Invalid value
--- @return Error Error object
function M.validation_error(message, field, value)
	return M.create_error(message, M.ERROR_TYPE.VALIDATION, M.ERROR_LEVEL.ERROR, { field = field, value = value })
end

--- Create a Taskwarrior error
--- @param message string Error message
--- @param command string? Command that failed
--- @param exit_code number? Exit code
--- @param stderr string? Standard error output
--- @return Error Error object
function M.taskwarrior_error(message, command, exit_code, stderr)
	return M.create_error(
		message,
		M.ERROR_TYPE.TASKWARRIOR,
		M.ERROR_LEVEL.ERROR,
		{ command = command, exit_code = exit_code, stderr = stderr }
	)
end

--- Create a parser error
--- @param message string Error message
--- @param line string? Line being parsed
--- @param line_number number? Line number
--- @return Error Error object
function M.parser_error(message, line, line_number)
	return M.create_error(message, M.ERROR_TYPE.PARSER, M.ERROR_LEVEL.ERROR, { line = line, line_number = line_number })
end

--- Create a filesystem error
--- @param message string Error message
--- @param path string? File path
--- @param operation string? File operation (read/write/delete)
--- @return Error Error object
function M.filesystem_error(message, path, operation)
	return M.create_error(message, M.ERROR_TYPE.FILESYSTEM, M.ERROR_LEVEL.ERROR, { path = path, operation = operation })
end

--- Create a configuration error
--- @param message string Error message
--- @param option string? Configuration option name
--- @param value any? Invalid configuration value
--- @return Error Error object
function M.config_error(message, option, value)
	return M.create_error(message, M.ERROR_TYPE.CONFIG, M.ERROR_LEVEL.ERROR, { option = option, value = value })
end

--- Log an error based on its level
--- @param err Error Error object
local function log_error(err)
	if err.level < config.log_level then
		return -- Skip if below log level threshold
	end

	local log_entry = string.format(
		"[%s] [%s] %s\n%s\n",
		os.date("%Y-%m-%d %H:%M:%S", err.timestamp),
		err.type,
		err.message,
		vim.inspect(err.context)
	)

	-- Log to console
	if config.debug then
		print(log_entry)
	end

	-- Log to file
	if config.log_to_file then
		local file = io.open(config.log_path, "a")
		if file then
			file:write(log_entry)
			file:close()
		end
	end
end
M.log_error = log_error

--- Handle an error appropriately based on type and level
--- @param err Error|string Error object or message string
--- @param source string? Source of the error (for string messages)
--- @return nil
function M.handle_error(err, source)
	-- Convert string messages to error objects
	if type(err) == "string" then
		err = M.create_error(err, nil, nil, { source = source })
	end

	-- Log the error
	M.log_error(err)

	-- Display error to user if not in silent mode and error is significant
	if not config.silent and err.level >= M.ERROR_LEVEL.ERROR then
		vim.notify(string.format("[Taskwarrior.nvim] %s: %s", err.type, err.message), vim.log.levels.ERROR)
	end

	-- For critical errors, we might want to abort the current operation
	if err.level >= M.ERROR_LEVEL.CRITICAL then
		error(string.format("[Taskwarrior.nvim] Critical error: %s", err.message))
	end
end

--- Try to execute a function with error handling
--- @param fn function Function to execute
--- @param ... any Arguments to pass to the function
--- @return boolean success Whether the function executed successfully
--- @return any result The function's return value or Error object
function M.try(fn, ...)
	local status, result = pcall(fn, ...)
	if not status then
		-- Convert Lua error string to our error format
		local err = M.create_error(result, M.ERROR_TYPE.INTERNAL, M.ERROR_LEVEL.ERROR)
		return false, err
	end
	return true, result
end

--- Assert a condition or throw an error
--- @param condition boolean Condition to check
--- @param message string Error message if condition is false
--- @param error_type string? Error type
--- @param context table? Additional error context
--- @return boolean condition The condition value (for chaining)
function M.assert(condition, message, error_type, context)
	if not condition then
		local err = M.create_error(message, error_type or M.ERROR_TYPE.INTERNAL, M.ERROR_LEVEL.ERROR, context)
		M.handle_error(err)
		error(message) -- Halt execution
	end
	return condition
end

return M
