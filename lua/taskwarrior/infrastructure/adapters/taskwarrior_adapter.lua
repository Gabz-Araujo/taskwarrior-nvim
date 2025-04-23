local M = {}

local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")
local Logger = require("taskwarrior.utils.logger")

--- Execute a Taskwarrior command
--- @param args string[] Taskwarrior command arguments
--- @param options table? Additional options
--- @return Result Result with parsed JSON output or error
function M.execute_taskwarrior(args, options)
	options = options or {}
	options.json = options.json ~= false -- Default to JSON output

	-- Get taskwarrior configuration
	local config = require("taskwarrior.application.config").get()

	-- Build the command array
	local cmd = { config.taskwarrior.executable or "task" }

	-- Add all other arguments
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	-- Add custom data/config locations if configured
	if config.taskwarrior.data_location then
		table.insert(cmd, "rc.data.location=" .. config.taskwarrior.data_location)
	end

	if config.taskwarrior.config_location then
		table.insert(cmd, "rc.confirmation=no") -- Always disable confirmation in scripts
		table.insert(cmd, "rc:" .. config.taskwarrior.config_location)
	end

	-- Add JSON format for output
	if options.json then
		table.insert(cmd, "rc.json.array=on")
		table.insert(cmd, "export")
	end

	-- Execute the command
	local result = M.execute(cmd, options)

	-- Parse JSON if needed
	if result:is_ok() and options.json then
		local json_output = result.value.stdout

		-- If output is empty, return empty array
		if json_output == nil or json_output == "" then
			result.value.data = {}
			return result
		end

		-- Try to parse JSON
		local success, parsed = pcall(vim.json.decode, json_output)

		if not success then
			return Result.Err(
				Error.taskwarrior_error(
					"Failed to parse Taskwarrior JSON output",
					table.concat(cmd, " "),
					result.value.exit_code,
					"JSON parse error: " .. parsed
				)
			)
		end

		result.value.data = parsed
	end

	return result
end

--- Add a task to Taskwarrior
--- @param task Task The task to add
--- @param options table? Additional options
--- @return Result Result with the added task or error
function M.add_task(task, options)
	options = options or {}

	-- Get command arguments from task
	local args = task:to_command_args()

	-- Create the add command
	local cmd_args = { "add" }
	for _, arg in ipairs(args) do
		table.insert(cmd_args, arg)
	end

	-- Execute the command
	local result = M.execute_taskwarrior(cmd_args, { json = false })

	-- If successful, try to get the task ID from the output
	if result:is_ok() then
		-- Parse the output to get the task ID
		local id_pattern = "Created task (%d+)"
		local id = result.value.stdout:match(id_pattern)

		if not id then
			Logger.warn("Could not extract task ID from output: " .. result.value.stdout)
			return Result.Ok({
				message = "Task added successfully, but could not retrieve details",
				output = result.value.stdout,
			})
		end

		-- Get the full task data
		local get_result = M.execute_taskwarrior({ id }, { json = true })
		if not get_result:is_ok() then
			Logger.warn("Could not retrieve task data: " .. vim.inspect(get_result))
			return Result.Ok({
				id = tonumber(id),
				message = "Task added with ID " .. id .. ", but could not retrieve full details",
				output = result.value.stdout,
			})
		end

		if not get_result.value.data or #get_result.value.data == 0 then
			Logger.warn("Task data was empty for ID: " .. id)
			return Result.Ok({
				id = tonumber(id),
				message = "Task added with ID " .. id .. ", but returned empty details",
				output = result.value.stdout,
			})
		end

		-- Return the full task data
		return Result.Ok({
			task = M.normalize_task_data(get_result.value.data[1]),
			id = tonumber(id),
		})
	end

	return result
end

--- Modify a task in Taskwarrior
--- @param id string|number Task ID or UUID
--- @param modifications table Changes to apply
--- @param options table? Additional options
--- @return Result Result with the modified task or error
function M.modify_task(id, modifications, options)
	options = options or {}

	-- Convert modifications to command arguments
	local mod_args = {}
	for k, v in pairs(modifications) do
		if k == "tags" then
			for _, tag in ipairs(v) do
				if tag:sub(1, 1) == "-" then
					-- Remove tag
					table.insert(mod_args, "-" .. tag:sub(2))
				else
					-- Add tag
					table.insert(mod_args, "+" .. tag)
				end
			end
		else
			table.insert(mod_args, k .. ":" .. tostring(v))
		end
	end

	-- Create the modify command
	local cmd_args = { id, "modify" }
	for _, arg in ipairs(mod_args) do
		table.insert(cmd_args, arg)
	end

	-- Execute the command
	local result = M.execute_taskwarrior(cmd_args, { json = false })

	-- If successful, get the updated task
	if result:is_ok() then
		-- Get the full task data
		local get_result = M.execute_taskwarrior({ id }, { json = true })
		if get_result:is_ok() and get_result.value.data and #get_result.value.data > 0 then
			return Result.Ok({
				task = get_result.value.data[1],
				message = "Task modified successfully",
			})
		end

		-- Fallback if we couldn't get the task
		return Result.Ok({
			message = "Task modified successfully",
			output = result.value.stdout,
		})
	end

	return result
end

--- Delete a task from Taskwarrior
--- @param id string|number Task ID or UUID
--- @param options table? Additional options
--- @return Result Result with success message or error
function M.delete_task(id, options)
	options = options or {}
	options.force = options.force or true -- Default to force delete

	-- Create the delete command
	local cmd_args = { id, "delete" }
	if options.force then
		table.insert(cmd_args, "rc.confirmation=no")
	end

	-- Execute the command
	local result = M.execute_taskwarrior(cmd_args, { json = false })

	-- If successful, return a success message
	if result:is_ok() then
		return Result.Ok({
			message = "Task deleted successfully",
			output = result.value.stdout,
		})
	end

	return result
end

--- Get tasks from Taskwarrior
--- @param filter string|table Filter to apply
--- @param options table? Additional options
--- @return Result Result with tasks or error
function M.get_tasks(filter, options)
	options = options or {}

	-- Convert filter to a list of arguments
	local filter_args = {}
	if type(filter) == "string" then
		if filter ~= "" then
			table.insert(filter_args, filter)
		end
	elseif type(filter) == "table" then
		for _, arg in ipairs(filter) do
			table.insert(filter_args, arg)
		end
	end

	-- Execute the command
	local result = M.execute_taskwarrior(filter_args, { json = true })

	-- If successful, return the tasks
	if result:is_ok() then
		return Result.Ok({
			tasks = result.value.data or {},
			count = #(result.value.data or {}),
		})
	end

	return result
end

--- Execute a shell command
--- @param cmd string[] Command and arguments as a table
--- @param options table? Additional options
--- @return Result Result with command output or error
function M.execute(cmd, options)
	options = options or {}

	-- vim.fn.system accepts an array of command parts directly
	local output = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	-- Check for execution errors
	if exit_code ~= 0 and not options.ignore_errors then
		return Result.Err(
			Error.taskwarrior_error("Taskwarrior command failed", table.concat(cmd, " "), exit_code, output)
		)
	end

	-- Return successful result
	return Result.Ok({
		stdout = output,
		stderr = "", -- vim.fn.system doesn't separate stdout/stderr
		exit_code = exit_code,
	})
end

-- Add this to your DateUtils or in the taskwarrior_adapter file
function M.convert_taskwarrior_date(date)
	if not date then
		return nil
	end

	-- Match the Taskwarrior format: 20250423T160733Z
	local year, month, day, hour, min, sec = date:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)Z$")

	if not year then
		return date
	end -- Return original if not matching

	-- Convert to ISO format with separators
	return string.format("%s-%s-%sT%s:%s:%sZ", year, month, day, hour, min, sec)
end

function M.normalize_task_data(task_data)
	if not task_data then
		return nil
	end

	local normalized = vim.deepcopy(task_data)

	-- Convert date fields
	local date_fields = { "due", "wait", "scheduled", "until", "entry", "modified", "start", "end" }
	for _, field in ipairs(date_fields) do
		if normalized[field] then
			normalized[field] = M.convert_taskwarrior_date(normalized[field])
		end
	end

	return normalized
end

return M
