---@diagnostic disable: unused-local
-- tests/infrastructure/task_repository_impl_spec.lua
local mock_modules = require("tests.helpers.mock_modules")
local fixtures = require("tests.helpers.fixtures")

-- Require the mock definitions
local MockTaskwarriorAdapter_Def = require("tests.mocks.taskwarrior_adapter_mock")
local MockTask_Def = require("tests.mocks.task_mock")
local Result -- Will be assigned the mocked version in before_each

describe("Task Repository Implementation", function()
	local TaskRepository
	local MockTaskwarriorAdapter
	local MockTask
	local last_adapter_call

	-- Store original functions
	local original_repo_get_by_id_global
	local original_repo_set_status_global

	before_each(function()
		-- Mock core utilities
		mock_modules.mock_result()
		mock_modules.mock_error()
		Result = package.loaded["taskwarrior.utils.result"] -- Assign mocked Result

		last_adapter_call = nil

		-- Create fresh mocks
		MockTaskwarriorAdapter = vim.deepcopy(MockTaskwarriorAdapter_Def)
		MockTask = vim.deepcopy(MockTask_Def)

		-- Inject mocks
		package.loaded["taskwarrior.infrastructure.adapters.taskwarrior_adapter"] = MockTaskwarriorAdapter
		package.loaded["taskwarrior.domain.entities.task"] = MockTask

		-- Clear and require repository
		package.loaded["taskwarrior.infrastructure.repositories.task_repository_implementation"] = nil
		TaskRepository = require("taskwarrior.infrastructure.repositories.task_repository_implementation")

		-- Store originals
		if not original_repo_get_by_id_global then
			original_repo_get_by_id_global = TaskRepository.get_by_id
		end
		if not original_repo_set_status_global then
			original_repo_set_status_global = TaskRepository.set_status
		end
	end)

	after_each(function()
		-- Restore originals
		if original_repo_get_by_id_global then
			TaskRepository.get_by_id = original_repo_get_by_id_global
		end
		if original_repo_set_status_global then
			TaskRepository.set_status = original_repo_set_status_global
		end

		-- Clear specific package.loaded entries
		package.loaded["taskwarrior.infrastructure.adapters.taskwarrior_adapter"] = nil
		package.loaded["taskwarrior.domain.entities.task"] = nil
		package.loaded["taskwarrior.infrastructure.repositories.task_repository_implementation"] = nil
		last_adapter_call = nil
		mock_modules.reset_all() -- Reset core mocks
	end)

	--===========================================================================
	-- get_by_id Tests
	--===========================================================================
	describe("get_by_id", function()
		it("should return task when adapter finds it", function()
			local target_id = fixtures.task_json.id
			local raw_task_data = fixtures.task_json
			MockTaskwarriorAdapter.get_tasks = function(id_filter)
				last_adapter_call = { name = "get_tasks", args = { id_filter } }
				assert.equal(tostring(target_id), id_filter)
				return Result.Ok({ tasks = { raw_task_data }, count = 1 })
			end
			local result = TaskRepository.get_by_id(target_id)
			assert.is_true(result:is_ok())
			assert.is_true(result.value._is_mock_task)
			assert.equals(target_id, result.value.id)
			assert.is_not_nil(last_adapter_call)
			assert.equals("get_tasks", last_adapter_call.name)
		end)
		it("should return Err when adapter returns empty list", function()
			local target_id = 999
			MockTaskwarriorAdapter.get_tasks = function(id_filter)
				last_adapter_call = { name = "get_tasks", args = { id_filter } }
				assert.equal(tostring(target_id), id_filter)
				return Result.Ok({ tasks = {}, count = 0 })
			end
			local result = TaskRepository.get_by_id(target_id)
			assert.is_true(result:is_err())
			assert.match("Task not found", result.error.message)
			assert.is_not_nil(last_adapter_call)
		end)
		it("should return Err when adapter returns error", function()
			local target_id = 123
			local mock_error = { message = "Adapter Communication Failed" }
			MockTaskwarriorAdapter.get_tasks = function(id_filter)
				last_adapter_call = { name = "get_tasks", args = { id_filter } }
				assert.equal(tostring(target_id), id_filter)
				return Result.Err(mock_error)
			end
			local result = TaskRepository.get_by_id(target_id)
			assert.is_true(result:is_err())
			assert.same(mock_error, result.error)
			assert.is_not_nil(last_adapter_call)
		end)
		it("should return Err when Task.from_taskwarrior_json returns nil", function()
			local target_id = fixtures.task_json.id
			local raw_task_data = fixtures.task_json
			MockTaskwarriorAdapter.get_tasks = function(id_filter)
				last_adapter_call = { name = "get_tasks", args = { id_filter } }
				assert.equal(tostring(target_id), id_filter)
				return Result.Ok({ tasks = { raw_task_data }, count = 1 })
			end
			MockTask.from_taskwarrior_json = function(_data)
				return nil
			end
			local result = TaskRepository.get_by_id(target_id)
			assert.is_true(result:is_err())
			assert.match("Failed to create Task entity", result.error.message)
			assert.is_not_nil(last_adapter_call)
		end)
	end)

	--===========================================================================
	-- get_all Tests
	--===========================================================================
	describe("get_all", function()
		it("should return list of tasks when adapter returns multiple", function()
			local filter = "+pending"
			local raw_tasks = { fixtures.task_json, { id = 2, description = "Task 2", status = "pending" } }
			MockTaskwarriorAdapter.get_tasks = function(f)
				last_adapter_call = { name = "get_tasks", args = { f } }
				assert.equal(filter, f)
				return Result.Ok({ tasks = raw_tasks, count = #raw_tasks })
			end
			local result = TaskRepository.get_all(filter)
			assert.is_true(result:is_ok())
			assert.equals(#raw_tasks, #result.value)
			assert.is_true(result.value[1]._is_mock_task)
			assert.is_true(result.value[2]._is_mock_task)
			assert.equals(fixtures.task_json.id, result.value[1].id)
			assert.equals(2, result.value[2].id)
			assert.is_not_nil(last_adapter_call)
		end)
		it("should return empty list when adapter returns none", function()
			local filter = "project:None"
			MockTaskwarriorAdapter.get_tasks = function(f)
				last_adapter_call = { name = "get_tasks", args = { f } }
				assert.equal(filter, f)
				return Result.Ok({ tasks = {}, count = 0 })
			end
			local result = TaskRepository.get_all(filter)
			assert.is_true(result:is_ok())
			assert.equals(0, #result.value)
			assert.is_not_nil(last_adapter_call)
		end)
		it("should return Err when adapter fails", function()
			local filter = "+tag"
			local mock_error = { message = "Adapter Failed" }
			MockTaskwarriorAdapter.get_tasks = function(f)
				last_adapter_call = { name = "get_tasks", args = { f } }
				assert.equal(filter, f)
				return Result.Err(mock_error)
			end
			local result = TaskRepository.get_all(filter)
			assert.is_true(result:is_err())
			assert.same(mock_error, result.error)
			assert.is_not_nil(last_adapter_call)
		end)
		it("should filter out tasks if Task.from_taskwarrior_json returns nil for one", function()
			local filter = "+maybe"
			local raw_tasks = { fixtures.task_json, { id = 2, description = "Task 2" } }
			MockTaskwarriorAdapter.get_tasks = function(f)
				last_adapter_call = { name = "get_tasks", args = { f } }
				return Result.Ok({ tasks = raw_tasks, count = #raw_tasks })
			end
			local original_from_json = MockTask.from_taskwarrior_json
			MockTask.from_taskwarrior_json = function(data)
				if data.id == 2 then
					return nil
				end
				return original_from_json(data)
			end
			local result = TaskRepository.get_all(filter)
			assert.is_true(result:is_ok())
			assert.equals(1, #result.value)
			assert.equals(fixtures.task_json.id, result.value[1].id)
			assert.is_not_nil(last_adapter_call)
			MockTask.from_taskwarrior_json = original_from_json
		end)
	end)

	--===========================================================================
	-- save (Create)
	--===========================================================================
	describe("save (create)", function()
		local task_to_create
		before_each(function()
			task_to_create = { description = "New Task To Create", priority = "M", tags = { "new" } }
		end)
		it("should call adapter.add_task and return the created task", function()
			local created_task_json = vim.deepcopy(fixtures.task_json)
			created_task_json.description = task_to_create.description
			created_task_json.id = 555
			created_task_json.uuid = "new-uuid-555"
			MockTaskwarriorAdapter.add_task = function(task_arg)
				last_adapter_call = { name = "add_task", args = { task_arg } }
				assert.equals(task_to_create.description, task_arg.description)
				assert.is_nil(task_arg.id)
				return Result.Ok({ task = created_task_json })
			end
			local result = TaskRepository.save(task_to_create)
			assert.is_true(result:is_ok())
			assert.is_true(result.value._is_mock_task)
			assert.equals(created_task_json.id, result.value.id)
			assert.equals(created_task_json.uuid, result.value.uuid)
			assert.equals(task_to_create.description, result.value.description)
			assert.is_not_nil(last_adapter_call)
			assert.equals("add_task", last_adapter_call.name)
		end)
		it("should call final get_by_id if adapter.add_task only returns message", function()
			local created_task_json = vim.deepcopy(fixtures.task_json)
			created_task_json.id = 556
			created_task_json.uuid = "new-uuid-556"
			created_task_json.description = task_to_create.description
			local add_task_called = false
			MockTaskwarriorAdapter.add_task = function(_task_arg)
				add_task_called = true
				return Result.Ok({ message = "Task added.", output = "Created task 556.", id = 556 })
			end
			local final_get_called = false
			MockTaskwarriorAdapter.get_tasks = function(id_filter)
				if id_filter == tostring(created_task_json.id) then
					final_get_called = true
					return Result.Ok({ tasks = { created_task_json }, count = 1 })
				else
					return Result.Err({ message = "get_tasks unexpected filter: " .. id_filter })
				end
			end
			local result = TaskRepository.save(task_to_create)
			assert.is_true(result:is_ok())
			assert.is_true(add_task_called)
			assert.is_true(final_get_called)
			assert.is_true(result.value._is_mock_task)
			assert.equals(created_task_json.id, result.value.id)
			assert.equals(created_task_json.description, result.value.description)
		end)
		it("should return Err if Task._validate fails", function()
			local validation_error = { message = "Invalid Description" }
			MockTask._validate = function(_data)
				return Result.Err(validation_error)
			end
			local result = TaskRepository.save(task_to_create)
			assert.is_true(result:is_err())
			assert.same(validation_error, result.error)
			assert.is_nil(last_adapter_call)
		end)
		it("should return Err if adapter.add_task fails", function()
			local adapter_error = { message = "Failed to add task in TW" }
			MockTaskwarriorAdapter.add_task = function(task_arg)
				last_adapter_call = { name = "add_task", args = { task_arg } }
				return Result.Err(adapter_error)
			end
			local result = TaskRepository.save(task_to_create)
			assert.is_true(result:is_err())
			assert.same(adapter_error, result.error)
			assert.is_not_nil(last_adapter_call)
		end)
		it("should return Err if final get_by_id fails (when add_task only returns id)", function()
			MockTaskwarriorAdapter.add_task = function(_task_arg)
				return Result.Ok({ message = "Task added.", output = "Created task 557.", id = 557 })
			end
			local final_get_error = { message = "Could not fetch created task" }
			MockTaskwarriorAdapter.get_tasks = function(id_filter)
				if id_filter == "557" then
					return Result.Err(final_get_error)
				else
					return Result.Err({ message = "get_tasks unexpected filter: " .. id_filter })
				end
			end
			local result = TaskRepository.save(task_to_create)
			assert.is_true(result:is_err())
			assert.same(final_get_error, result.error)
		end)
	end)

	--===========================================================================
	-- save (Update)
	--===========================================================================
	describe("save (update)", function()
		local task_to_update
		local existing_task_mock

		before_each(function()
			task_to_update = {
				id = fixtures.task_json.id,
				uuid = fixtures.task_json.uuid,
				description = "Updated Task Description",
				priority = fixtures.task_json.priority,
				tags = { "neovim", "updated" },
				_is_mock_task = true,
				diff = MockTask.diff,
				clone = MockTask.clone,
			}
			existing_task_mock = {
				id = fixtures.task_json.id,
				uuid = fixtures.task_json.uuid,
				description = fixtures.task_json.description,
				priority = fixtures.task_json.priority,
				tags = { "neovim", "test" },
				_is_mock_task = true,
				diff = function(self, other)
					local diffs = {}
					if self.description ~= other.description then
						diffs.description = { old = self.description, new = other.description }
					end
					local ts, to = {}, {}
					for _, t in ipairs(self.tags or {}) do
						ts[t] = true
					end
					for _, t in ipairs(other.tags or {}) do
						to[t] = true
					end
					local ad, rm = {}, {}
					for _, t in ipairs(other.tags or {}) do
						if not ts[t] then
							table.insert(ad, t)
						end
					end
					for _, t in ipairs(self.tags or {}) do
						if not to[t] then
							table.insert(rm, t)
						end
					end
					if #ad > 0 or #rm > 0 then
						diffs.tags = { added = ad, removed = rm }
					end
					local aa, sa = {}, {}
					for _, a in ipairs(self.annotations or {}) do
						sa[a.description] = true
					end
					for _, a in ipairs(other.annotations or {}) do
						if not sa[a.description] then
							table.insert(aa, a)
						end
					end
					if #aa > 0 then
						diffs.annotations = { added = aa, removed = {} }
					end
					return diffs
				end,
				clone = MockTask.clone,
			}
		end)

		-- Helper function to mock get_by_id for update scenarios (expects UUID)
		local function mock_get_by_id_for_update_flow()
			TaskRepository.get_by_id = function(id_or_uuid)
				if tostring(id_or_uuid) == tostring(existing_task_mock.uuid) then
					return Result.Ok(vim.deepcopy(existing_task_mock))
				end
				-- Handle potential ID call (though less likely for initial check)
				if tostring(id_or_uuid) == tostring(existing_task_mock.id) then
					return Result.Ok(vim.deepcopy(existing_task_mock))
				end
				return Result.Err({
					message = "Update test: get_by_id mock received unexpected ID/UUID: " .. tostring(id_or_uuid),
				})
			end
		end

		-- NOTE: This test WILL FAIL until the implementation passes ID instead of UUID to adapter
		it("should call adapter.modify_task with diff and return updated task", function()
			-- Arrange
			mock_get_by_id_for_update_flow() -- Mock the initial fetch

			local updated_task_json = vim.deepcopy(fixtures.task_json)
			updated_task_json.id = task_to_update.id
			updated_task_json.description = task_to_update.description
			updated_task_json.tags = task_to_update.tags
			MockTaskwarriorAdapter.modify_task = function(id, modifications)
				last_adapter_call = { name = "modify_task", args = { id, modifications } }
				assert.equals(tostring(task_to_update.id), tostring(id), "modify_task should be called with ID") -- Fails until impl fix
				assert.equals(task_to_update.description, modifications.description)
				assert.is_nil(modifications.priority)
				assert.same({ "+updated", "-test" }, modifications.tags)
				return Result.Ok({ task = updated_task_json })
			end

			-- Act
			local result = TaskRepository.save(task_to_update)

			-- Assert
			assert.is_true(result:is_ok(), result.error and result.error.message or "Should be Ok")
			assert.is_true(result.value._is_mock_task)
			assert.equals(task_to_update.id, result.value.id)
			assert.equals(task_to_update.description, result.value.description)
			assert.same(task_to_update.tags, result.value.tags)
			assert.is_not_nil(last_adapter_call)
			assert.equals("modify_task", last_adapter_call.name)
		end)

		it("should not call adapter.modify_task if diff is empty", function()
			-- Arrange
			mock_get_by_id_for_update_flow()
			task_to_update = vim.deepcopy(existing_task_mock)
			task_to_update.diff = existing_task_mock.diff
			existing_task_mock.diff = function(_, _)
				return {}
			end
			local modify_called = false
			MockTaskwarriorAdapter.modify_task = function(_, _)
				modify_called = true
				return Result.Ok({})
			end

			-- Act
			local result = TaskRepository.save(task_to_update)

			-- Assert
			assert.is_true(result:is_ok())
			assert.is_false(modify_called, "modify_task should not have been called")
			assert.is_true(result.value._is_mock_task)
			assert.equals(task_to_update.id, result.value.id)
			assert.equals(task_to_update.description, result.value.description)
		end)

		-- NOTE: This test WILL FAIL until the implementation passes ID instead of UUID to adapter
		it("should call adapter.annotate_task for annotation changes", function()
			-- Arrange
			mock_get_by_id_for_update_flow()
			local annotation_text = "This is a new annotation"
			task_to_update = vim.deepcopy(existing_task_mock)
			task_to_update.annotations = { { description = annotation_text, entry = "some_time" } }
			task_to_update.diff = existing_task_mock.diff
			existing_task_mock.diff = function(self, other)
				local diffs = { annotations = { added = {}, removed = {} } }
				local sa = {}
				for _, a in ipairs(self.annotations or {}) do
					sa[a.description] = true
				end
				for _, a in ipairs(other.annotations or {}) do
					if not sa[a.description] then
						table.insert(diffs.annotations.added, a)
					end
				end
				if #diffs.annotations.added == 0 then
					diffs.annotations = nil
				end
				return diffs
			end
			local annotate_called_with = nil
			MockTaskwarriorAdapter.annotate_task = function(id, annotation)
				annotate_called_with = { id = id, annotation = annotation }
				local task_after = vim.deepcopy(task_to_update)
				return Result.Ok({ task = task_after })
			end
			local modify_called = false
			MockTaskwarriorAdapter.modify_task = function(_, _)
				modify_called = true
				return Result.Ok({})
			end

			-- Act
			local result = TaskRepository.save(task_to_update)

			-- Assert
			assert.is_true(result:is_ok(), result.error and result.error.message or "Should be Ok")
			assert.is_false(modify_called, "modify_task should not be called for only annotations")
			if assert.is_not_nil(annotate_called_with) then
				assert.equals(
					tostring(task_to_update.id),
					tostring(annotate_called_with.id),
					"annotate_task should be called with ID"
				)
				assert.equals(annotation_text, annotate_called_with.annotation)
				if result.value and result.value.annotations and #result.value.annotations > 0 then
					assert.equals(annotation_text, result.value.annotations[1].description)
				else
					assert.fail("Result task did not contain expected annotations")
				end
			else
				assert.fail("annotate_called_with should not be nil")
			end
		end)

		it("should return Err if initial get_by_id fails", function()
			local get_id_error = { message = "Cannot find task to update" }
			TaskRepository.get_by_id = function(_)
				return Result.Err(get_id_error)
			end
			local result = TaskRepository.save(task_to_update)
			assert.is_true(result:is_err())
			assert.same(get_id_error, result.error)
			assert.is_nil(last_adapter_call)
		end)

		-- NOTE: This test might also fail if the modify_task assertion fails first due to the ID/UUID issue
		it("should return Err if adapter.modify_task fails", function()
			mock_get_by_id_for_update_flow()
			local modify_error = { message = "TW failed to modify" }
			MockTaskwarriorAdapter.modify_task = function(id, modifications)
				last_adapter_call = { name = "modify_task", args = { id, modifications } }
				return Result.Err(modify_error)
			end
			local result = TaskRepository.save(task_to_update)
			assert.is_true(result:is_err())
			assert.same(modify_error, result.error)
			assert.is_not_nil(last_adapter_call)
			assert.equals("modify_task", last_adapter_call.name)
		end)

		-- NOTE: This test might also fail if the annotate_task assertion fails first due to the ID/UUID issue
		it("should return Err if adapter.annotate_task fails", function()
			mock_get_by_id_for_update_flow()
			local annotation_text = "Another annotation"
			task_to_update = vim.deepcopy(existing_task_mock)
			task_to_update.annotations = { { description = annotation_text } }
			task_to_update.diff = existing_task_mock.diff
			existing_task_mock.diff = function(self, other)
				local diffs = { annotations = { added = {}, removed = {} } }
				local sa = {}
				for _, a in ipairs(self.annotations or {}) do
					sa[a.description] = true
				end
				for _, a in ipairs(other.annotations or {}) do
					if not sa[a.description] then
						table.insert(diffs.annotations.added, a)
					end
				end
				if #diffs.annotations.added == 0 then
					diffs.annotations = nil
				end
				return diffs
			end
			local annotate_error = { message = "TW annotation failed" }
			MockTaskwarriorAdapter.annotate_task = function(id, annotation)
				last_adapter_call = { name = "annotate_task", args = { id, annotation } }
				return Result.Err(annotate_error)
			end
			local result = TaskRepository.save(task_to_update)
			assert.is_true(result:is_err())
			assert.same(annotate_error, result.error)
			assert.is_not_nil(last_adapter_call)
			assert.equals("annotate_task", last_adapter_call.name)
		end)
	end)

	--===========================================================================
	-- delete Tests (Pass)
	--===========================================================================
	describe("delete", function()
		it("should call adapter.delete_task and return Ok(true) on success", function()
			local target_id = 42
			MockTaskwarriorAdapter.delete_task = function(id, options)
				last_adapter_call = { name = "delete_task", args = { id, options } }
				assert.equal(tostring(target_id), tostring(id))
				return Result.Ok(true)
			end
			local result = TaskRepository.delete(target_id)
			assert.is_true(result:is_ok())
			assert.is_true(result.value)
			assert.is_not_nil(last_adapter_call)
			assert.equals("delete_task", last_adapter_call.name)
		end)
		it("should return Err if adapter.delete_task fails", function()
			local target_id = 43
			local delete_error = { message = "Deletion failed in TW" }
			MockTaskwarriorAdapter.delete_task = function(id, options)
				last_adapter_call = { name = "delete_task", args = { id, options } }
				return Result.Err(delete_error)
			end
			local result = TaskRepository.delete(target_id)
			assert.is_true(result:is_err())
			assert.same(delete_error, result.error)
			assert.is_not_nil(last_adapter_call)
		end)
	end)

	--===========================================================================
	-- set_status Tests (Fixing validation test assertion)
	--===========================================================================
	describe("set_status", function()
		local task_id = 77
		local initial_task_mock
		local updated_task_mock

		before_each(function()
			initial_task_mock = {
				id = task_id,
				uuid = "uuid-" .. task_id,
				description = "Task",
				status = "pending",
				_is_mock_task = true,
				clone = MockTask.clone,
			}
			updated_task_mock = vim.deepcopy(initial_task_mock)
		end)

		it("should call adapter execute with 'done' command and return updated task", function()
			local new_status = "done"
			updated_task_mock.status = new_status
			local call_count = 0
			TaskRepository.get_by_id = function(id)
				call_count = call_count + 1
				if tostring(id) == tostring(task_id) then
					if call_count == 1 then
						return Result.Ok(vim.deepcopy(initial_task_mock))
					end
					if call_count == 2 then
						return Result.Ok(vim.deepcopy(updated_task_mock))
					end
				end
				return Result.Err({ message = "Set status(done) test: get_by_id mock unexpected ID/count" })
			end
			local expected_command = { task_id, "done" }
			MockTaskwarriorAdapter.execute_taskwarrior = function(cmd_args, options)
				last_adapter_call = { name = "execute_taskwarrior", args = { cmd_args, options } }
				assert.same(expected_command, cmd_args)
				assert.is_false(options.json)
				return Result.Ok({ message = "Task set", output = "...", exit_code = 0 })
			end
			local result = TaskRepository.set_status(task_id, new_status)
			assert.is_true(result:is_ok(), result.error and result.error.message or "Should be Ok")
			assert.is_true(result.value._is_mock_task)
			assert.equals(task_id, result.value.id)
			assert.equals(new_status, result.value.status)
			assert.is_not_nil(last_adapter_call)
			assert.equals("execute_taskwarrior", last_adapter_call.name)
		end)

		it("should return validation error for 'deleted' status", function()
			local new_status = "deleted"
			local expected_error_msg = "Unsupported status for direct operation: deleted"
			TaskRepository.get_by_id = function(id)
				if tostring(id) == tostring(task_id) then
					return Result.Ok(vim.deepcopy(initial_task_mock))
				end
				return Result.Err({ message = "Set status(deleted-validation) test: get_by_id should have succeeded" })
			end
			local result = TaskRepository.set_status(task_id, new_status)
			assert.is_true(result:is_err(), "Result should be Err for deleted status")
			if result:is_err() then
				assert.match(expected_error_msg, result.error.message)
			end -- Check validation message
			assert.is_nil(last_adapter_call, "Adapter should not be called for invalid status")
		end)

		it("should return Err if initial get_by_id fails", function()
			local get_id_error = { message = "Cannot find task to set status" }
			TaskRepository.get_by_id = function(_)
				return Result.Err(get_id_error)
			end
			local result = TaskRepository.set_status(task_id, "done")
			assert.is_true(result:is_err())
			assert.same(get_id_error, result.error)
			assert.is_nil(last_adapter_call)
		end)

		it("should return Err if adapter command fails", function()
			TaskRepository.get_by_id = function(id)
				if tostring(id) == tostring(task_id) then
					return Result.Ok(vim.deepcopy(initial_task_mock))
				end
				return Result.Err({ message = "Adapter fail test: get_by_id unexpected ID" })
			end
			local adapter_error = { message = "TW command failed" }
			MockTaskwarriorAdapter.execute_taskwarrior = function(cmd_args, options)
				last_adapter_call = { name = "execute_taskwarrior", args = { cmd_args, options } }
				return Result.Err(adapter_error)
			end
			local result = TaskRepository.set_status(task_id, "done")
			assert.is_true(result:is_err())
			assert.same(adapter_error, result.error)
			assert.is_not_nil(last_adapter_call)
		end)

		it("should return Err if final get_by_id fails", function()
			updated_task_mock.status = "done"
			local call_count = 0
			local final_get_error = { message = "Cannot refetch task" }
			TaskRepository.get_by_id = function(id)
				call_count = call_count + 1
				if tostring(id) == tostring(task_id) then
					if call_count == 1 then
						return Result.Ok(vim.deepcopy(initial_task_mock))
					end
					if call_count == 2 then
						return Result.Err(final_get_error)
					end
				end
				return Result.Err({ message = "Final get fail test: get_by_id unexpected ID/count" })
			end
			MockTaskwarriorAdapter.execute_taskwarrior = function(_, _)
				return Result.Ok({ message = "Command OK" })
			end
			local result = TaskRepository.set_status(task_id, "done")
			assert.is_true(result:is_err())
			assert.same(final_get_error, result.error)
		end)

		it("should return validation error for unsupported status", function()
			-- Arrange
			local unsupported_status = "invalid-status"
			local expected_error_msg = "Unsupported status for direct operation: " .. unsupported_status
			TaskRepository.get_by_id = function(id)
				if tostring(id) == tostring(task_id) then
					return Result.Ok(vim.deepcopy(initial_task_mock))
				end
				return Result.Err({ message = "Set status(invalid-validation) test: get_by_id should have succeeded" })
			end

			-- Act
			local result = TaskRepository.set_status(task_id, unsupported_status)

			-- Assert
			assert.is_true(result:is_err())
			if result:is_err() then
				assert.equals(expected_error_msg, result.error.message)
			end
			assert.is_nil(last_adapter_call)
		end)
	end)
end)
