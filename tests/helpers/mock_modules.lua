-- Mock modules for testing
local M = {}

-- Stored original modules
local original_modules = {}

-- Setup mock for Result module
function M.mock_result()
	original_modules.result = package.loaded["taskwarrior.utils.result"]

	package.loaded["taskwarrior.utils.result"] = {
		Ok = function(value)
			return {
				is_ok = function()
					return true
				end,
				is_err = function()
					return false
				end,
				unwrap = function()
					return value
				end,
				unwrap_or = function(_, _)
					return value
				end,
				value = value,
			}
		end,
		Err = function(err)
			return {
				is_ok = function()
					return false
				end,
				is_err = function()
					return true
				end,
				unwrap = function()
					error(err)
				end,
				unwrap_or = function(_, default)
					return default
				end,
				error = err,
			}
		end,
	}
end

-- Setup mock for Error module
function M.mock_error()
	original_modules.error = package.loaded["taskwarrior.utils.error"]

	package.loaded["taskwarrior.utils.error"] = {
		handle_error = function() end,
		not_found_error = function(msg)
			return {
				message = msg,
			}
		end,
		validation_error = function(msg)
			return { message = msg }
		end,
		create_error = function(msg)
			return { message = msg }
		end,
		ERROR_TYPE = {
			VALIDATION = "ValidationError",
			TASKWARRIOR = "TaskwarriorError",
			PARSER = "ParserError",
			FILESYSTEM = "FileSystemError",
			CONFIG = "ConfigError",
			NETWORK = "NetworkError",
			INTERNAL = "InternalError",
		},
		ERROR_LEVEL = {
			DEBUG = 1,
			INFO = 2,
			WARN = 3,
			ERROR = 4,
			CRITICAL = 5,
		},
	}
end

-- Reset all mocks
function M.reset_all()
	for name, module in pairs(original_modules) do
		package.loaded["taskwarrior.utils." .. name] = module
	end
	original_modules = {}
end

return M
