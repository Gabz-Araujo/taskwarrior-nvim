--- Command execution utilities for Taskwarrior.nvim
--- @module taskwarrior.infrastructure.io.command

local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")

local M = {}

--- Execute a system command and return the result
--- @param cmd string|string[] Command to execute (string or array of arguments)
--- @param options table? Additional options
--- @return Result Result with stdout or error
function M.execute(cmd, options)
	options = options or {}

	-- Convert command to string if it's an array
	if type(cmd) == "table" then
		cmd = table.concat(cmd, " ")
	end

	-- Execute command
	local output = ""
	local stderr = ""
	local exit_code

	-- Use vim.fn.system for simplicity, or job system for async
	if options.async then
		-- Implementation for async would go here
		-- Using plenary.nvim or neovim's built-in job API
		return Result.Err(
			Error.create_error(
				"Async command execution not implemented yet",
				Error.ERROR_TYPE.INTERNAL,
				Error.ERROR_LEVEL.ERROR
			)
		)
	else
		-- Synchronous execution
		local result

		-- Use pcall to catch errors
		local success, system_result = pcall(function()
			return vim.fn.system(cmd)
		end)

		if not success then
			return Result.Err(
				Error.create_error(
					"Failed to execute command: " .. system_result,
					Error.ERROR_TYPE.INTERNAL,
					Error.ERROR_LEVEL.ERROR,
					{ command = cmd }
				)
			)
		end

		output = system_result
		exit_code = vim.v.shell_error
	end

	-- Check result
	if exit_code ~= 0 then
		return Result.Err(
			Error.taskwarrior_error("Command failed with exit code " .. exit_code, cmd, exit_code, stderr)
		)
	end

	return Result.Ok({
		stdout = output,
		stderr = stderr,
		exit_code = exit_code,
	})
end

return M
