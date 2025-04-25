local TaskRepositoryImplementation = require("taskwarrior.infrastructure.repositories.task_repository_implementation")
local Result = require("taskwarrior.utils.result")

describe("TaskRepositoryImplementation", function()
	local original_task_module

	before_each(function()
		original_task_module = package.loaded["taskwarrior.domain.entities.task"]

		local MockTask = {}
		MockTask.new = function(task_data)
			local task = {
				id = task_data.id,
				description = task_data.description,
				status = task_data.status or "pending",
				tags = task_data.tags or {},
				annotations = task_data.annotations or {},
				uda = task_data.uda or {},
			}
			return Result.Ok(task)
		end

		MockTask.from_taskwarrior_json = function(task_data)
			local task = {
				id = task_data.id,
				uuid = task_data.uuid,
				description = task_data.description,
				status = task_data.status or "pending",
				tags = task_data.tags or {},
				annotations = task_data.annotations or {},
				uda = task_data.uda or {},
			}
			return Result.Ok(task)
		end

		package.loaded["taskwarrior.domain.entities.task"] = MockTask
	end)

	after_each(function()
		package.loaded["taskwarrior.domain.entities.task"] = original_task_module
	end)

	describe("get_by_id", function()
		it("should return error when Task.new fails", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.get_task = function(self, id)
				return Result.Err({ message = "Adapter failed to get task" })
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:get_by_id(123)

			assert.is_true(result:is_err())
			assert.equals("Adapter failed to get task", result.error.message)
		end)
		it("should return a task when adapter succeeds", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.get_task = function(self, id)
				return Result.Ok({ id = 1, description = "Task 1" })
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:get_by_id(1)

			assert.is_true(result:is_ok())
			assert.equals(1, result.value.id)
			assert.equals("Task 1", result.value.description)
		end)
	end)

	describe("get_all", function()
		it("should return all tasks when adapter succeeds", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.get_tasks = function(self)
				return Result.Ok({
					{ id = 1, description = "Task 1" },
					{ id = 2, description = "Task 2" },
					{ id = 3, description = "Task 3" },
				})
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:get_all()

			assert.is_true(result:is_ok())
			assert.equals(3, #result.value)
			assert.equals(1, result.value[1].id)
			assert.equals("Task 1", result.value[1].description)
			assert.equals(2, result.value[2].id)
			assert.equals("Task 2", result.value[2].description)
			assert.equals(3, result.value[3].id)
			assert.equals("Task 3", result.value[3].description)
		end)

		it("should return empty array when no tasks found", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.get_tasks = function(self)
				return Result.Ok({})
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:get_all()

			assert.is_true(result:is_ok())
			assert.equals(0, #result.value)
		end)

		it("should return error when adapter fails", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.get_tasks = function(self)
				return Result.Err({ message = "Failed to fetch tasks" })
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:get_all()

			assert.is_true(result:is_err())
			assert.equals("Failed to fetch tasks", result.error.message)
		end)

		it("should filter out tasks with invalid data", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.get_tasks = function(self)
				return Result.Ok({
					{ id = 1, description = "Task 1" },
					{ id = 2, description = nil }, -- This should be filtered out
				})
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:get_all()

			assert.is_true(result:is_ok())
			assert.equals(1, #result.value)
			assert.equals(1, result.value[1].id)
			assert.equals("Task 1", result.value[1].description)
		end)
	end)

	describe("save", function()
		it("should successfully save a task", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.add_task = function(self, task)
				-- Simulating the behavior of returning the saved task
				return Result.Ok({
					id = 42, -- Taskwarrior would assign a new ID
					description = task.description,
					status = task.status,
				})
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local task = {
				description = "New task",
				status = "pending",
			}

			local result = repo:save(task)

			assert.is_true(result:is_ok())
			assert.equals(42, result.value.id)
			assert.equals("New task", result.value.description)
			assert.equals("pending", result.value.status)
		end)

		it("should return error when adapter save fails", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.add_task = function(self, task)
				return Result.Err({ message = "Failed to save task" })
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local task = {
				description = "New task",
				status = "pending",
			}

			local result = repo:save(task)

			assert.is_true(result:is_err())
			assert.equals("Failed to save task", result.error.message)
		end)
	end)

	describe("delete", function()
		it("should successfully delete a task", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.delete_task = function(self, id)
				return Result.Ok(true)
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:delete(123)

			assert.is_true(result:is_ok())
			assert.is_true(result.value)
		end)

		it("should return error when adapter delete fails", function()
			local MockTaskwarriorAdapter = {}
			MockTaskwarriorAdapter.delete_task = function(self, id)
				return Result.Err({ message = "Failed to delete task" })
			end

			local repo = TaskRepositoryImplementation.new(MockTaskwarriorAdapter)
			local result = repo:delete(999)

			assert.is_true(result:is_err())
			assert.equals("Failed to delete task", result.error.message)
		end)
	end)
end)
