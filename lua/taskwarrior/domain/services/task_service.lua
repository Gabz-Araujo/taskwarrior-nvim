local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")
local Logger = require("taskwarrior.utils.logger")

---@class TaskService
local M = {}

---@param task_repository TaskRepository
function M.new(task_repository)
	local self = {
		task_repository = task_repository,
	}
	setmetatable(self, { __index = M })
	return self
end

--- Creates a new task.
--- @param task Task The task to create.
--- @return Result<Task, Error> The result of the task creation operation.
function M:create_task(task)
	if not task then
		Logger.error("Attempted to create a nil task.")
		return Result.Err(Error.invalid_input("Task cannot be nil"))
	end

	local result = self.task_repository:save(task)

	if result:is_ok() then
		Logger.info("Task created successfully: " .. task.description)
		return Result.Ok(task)
	else
		Logger.error("Failed to create task: " .. (result.error or "Unknown error"))
		return Result.Err(Error.repository_error(result.error or "Failed to save task"))
	end
end

--- Completes an existing task.
--- @param task Task The task to complete.
--- @return Result<Task, Error> The result of the task completion operation.
function M:complete_task(task)
	if not task then
		Logger.error("Attempted to complete a nil task.")
		return Result.Err(Error.invalid_input("Task cannot be nil"))
	end

	if task.status == "completed" then
		Logger.warn("Task is already completed: " .. task.description)
		return Result.Ok(task)
	end

	task.status = "done"

	local result = self.task_repository:save(task)

	if result:is_ok() then
		Logger.info("Task completed successfully: " .. task.description)
		return Result.Ok(task)
	else
		Logger.error("Failed to complete task: " .. (result.error or "Unknown error"))
		return Result.Err(Error.repository_error(result.error or "Failed to update task status"))
	end
end

--- Retrieves a task by its ID.
--- @param id number The ID of the task to retrieve.
--- @return Result<Task, Error> The result containing the task or an error.
function M:get_task_by_id(id)
	if not id then
		Logger.error("Attempted to get a task with a nil ID.")
		return Result.Err(Error.invalid_input("Task ID cannot be nil"))
	end

	Logger.debug("Getting task by ID: " .. id)

	local task = self.task_repository:get_by_id(id)

	if task then
		Logger.info("Task retrieved successfully: " .. task.description)
		return Result.Ok(task)
	else
		Logger.warn("Task not found with ID: " .. id)
		return Result.Err(Error.not_found("Task not found with ID: " .. id))
	end
end

--- Retrieves all tasks.
--- @return Result<Task[], Error> The result containing an array of tasks or an error.
function M:get_all_tasks()
	Logger.debug("Getting all tasks.")

	local tasks = self.task_repository:get_all()

	if tasks then
		Logger.info("Retrieved " .. #tasks .. " tasks successfully.")
		return Result.Ok(tasks)
	else
		Logger.warn("No tasks found.")
		return Result.Ok({})
	end
end

return M
