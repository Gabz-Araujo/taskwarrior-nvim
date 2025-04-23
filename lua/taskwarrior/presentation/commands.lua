local CreateTask = require("taskwarrior.application.commands.create_task")
local Logger = require("taskwarrior.utils.logger")
local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")

local M = {}

--- Create a task from the current line
--- @return boolean success
--- @return string? message
function M.create_task_from_current_line()
	local result = CreateTask.execute_from_current_line()

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
	local result = CreateTask.execute_from_visual_selection()

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

		local result = CreateTask.execute_with_description(input)

		if result:is_ok() then
			vim.notify("Task created: " .. result.value.description, vim.log.levels.INFO)
		else
			vim.notify("Failed to create task: " .. result.error.message, vim.log.levels.ERROR)
		end
	end)

	return true
end

return M
