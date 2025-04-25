local Logger = require("taskwarrior.utils.logger")
local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")

local M = {}

---@private
---@type CreateTaskCommand
local create_task_command

--- Set the create task command
---@param command CreateTaskCommand
function M.set_create_task_command(command)
	create_task_command = command
end

--- Create a task from the current line
--- @return boolean success
--- @return string? message
function M.create_task_from_current_line()
	if not create_task_command then
		Logger.error("Create task command not initialized.")
		return false, "Create task command not initialized"
	end

	local result = create_task_command:execute_from_current_line()

	if result:is_ok() then
		vim.notify("Task created: " .. result.value.description, vim.log.levels.INFO)
		return true, "Task created successfully"
	else
		vim.notify("Failed to create task: " .. result.error.message, vim.log.levels.ERROR)
		return false, result.error.message
	end
end

--- Create a task from visual selection
--- @return boolean success
--- @return string? message
function M.create_task_from_selection()
	if not create_task_command then
		Logger.error("Create task command not initialized.")
		return false, "Create task command not initialized"
	end

	local result = create_task_command:execute_from_visual_selection()

	if result:is_ok() then
		vim.notify("Task created: " .. result.value.description, vim.log.levels.INFO)
		return true, "Task created successfully"
	else
		vim.notify("Failed to create task: " .. result.error.message, vim.log.levels.ERROR)
		return false, result.error.message
	end
end

--- Create a task with a description prompt
--- @return boolean success
--- @return string? message
function M.create_task_with_prompt()
	-- Prompt user for task description
	vim.ui.input({
		prompt = "Task description: ",
	}, function(input)
		if not input or input == "" then
			vim.notify("Task creation canceled", vim.log.levels.INFO)
			return
		end

		if not create_task_command then
			Logger.error("Create task command not initialized.")
			vim.notify("Failed to create task: Create task command not initialized", vim.log.levels.ERROR)
			return false, "Create task command not initialized"
		end

		local result = create_task_command:execute_with_description(input)

		if result:is_ok() then
			vim.notify("Task created: " .. result.value.description, vim.log.levels.INFO)
		else
			vim.notify("Failed to create task: " .. result.error.message, vim.log.levels.ERROR)
		end
	end)

	return true
end

--- Create a task with the given properties
--- @param task_data table Task properties
--- @return Result
function M.create_task(task_data)
	if not create_task_command then
		Logger.error("Create task command not initialized.")
		return Result.Err(Error.new("Create task command not initialized"))
	end

	local result = create_task_command:execute(task_data)
	return result
end

--- Create a task from description text
--- @param description string Task description
--- @param options table|nil Additional options (tags, priority, etc.)
--- @return Result
function M.create_task_from_description(description, options)
	if not create_task_command then
		Logger.error("Create task command not initialized.")
		return Result.Err(Error.new("Create task command not initialized"))
	end

	local result = create_task_command:execute_with_description(description, options)
	return result
end

return M
