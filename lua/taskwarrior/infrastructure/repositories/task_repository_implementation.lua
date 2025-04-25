local TaskRepository = require("taskwarrior.domain.repositories.task_repository")
local Task = require("taskwarrior.domain.entities.task")
local Result = require("taskwarrior.utils.result")

--- @class TaskRepositoryImplementation
local TaskRepositoryImplementation = {}
setmetatable(TaskRepositoryImplementation, { __index = TaskRepository })

---@param adapter TaskwarriorAdapter
---@return TaskRepositoryImplementation
function TaskRepositoryImplementation.new(adapter)
	local self = {
		adapter = adapter,
	}
	setmetatable(self, { __index = TaskRepositoryImplementation })
	return self
end

---@param id number
---@return Result<Task, Error>
function TaskRepositoryImplementation:get_by_id(id)
	local result = self.adapter:get_task(id)
	if result:is_ok() then
		local task_data = result.value
		local task_result = Task.new(task_data)
		if task_result:is_ok() then
			return Result.Ok(task_result.value)
		else
			return Result.Err(task_result.error)
		end
	else
		return Result.Err(result.error)
	end
end

---@return Result<Task[], Error>
function TaskRepositoryImplementation:get_all()
	local result = self.adapter:get_tasks()
	if result:is_ok() then
		local tasks_data = result.value
		local tasks = {}
		for _, task_data in ipairs(tasks_data) do
			local task_result = Task.new(task_data)
			if task_result:is_ok() then
				table.insert(tasks, task_result.value)
			end
		end
		return Result.Ok(tasks)
	else
		return Result.Err(result.error)
	end
end

---@param task Task
---@return Result<Task, Error>
function TaskRepositoryImplementation:save(task)
	-- Implementation using the adapter to save to Taskwarrior
	return self.adapter:add_task(task) -- Assuming adapter:add_task returns a Result
end

---@param id number
---@return Result<boolean, Error>
function TaskRepositoryImplementation:delete(id)
	-- Implementation using the adapter to delete from Taskwarrior
	return self.adapter:delete_task(id) -- Assuming adapter:delete_task returns a Result
end

return TaskRepositoryImplementation
