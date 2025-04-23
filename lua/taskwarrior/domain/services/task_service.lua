local TaskRepository = require("taskwarrior.infrastructure.repositories.task_repository_implementation")
local Result = require("taskwarrior.utils.result")

local M = {}

-- Create a new task
function M.create_task(task_data)
	local Task = require("taskwarrior.domain.entities.task")
	local task = Task.new(task_data)
	if not task then
		return Result.Err("Failed to create task from provided data")
	end

	return TaskRepository.save(task)
end

-- Complete a task
function M.complete_task(id)
	local result = TaskRepository.get_by_id(id)
	if result:is_err() then
		return result
	end

	local task = result.value
	task:set_status("done")

	return TaskRepository.save(task)
end

-- Get tasks by filter
function M.get_tasks(filter)
	return TaskRepository.get_all(filter)
end

-- Delete a task
function M.delete_task(id)
	return TaskRepository.delete(id)
end

return M
