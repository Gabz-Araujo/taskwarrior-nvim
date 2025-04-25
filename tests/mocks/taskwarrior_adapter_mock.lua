local Result = require("taskwarrior.utils.result")
local MockTask_Def = require("tests.mocks.task_mock")

local M = {}

M.get_task = function(id)
	return Result.Ok({ id = id, description = "Mock Task" })
end

M.get_tasks = function(filter, options)
	local tasks = {
		{ id = 1, description = "Task 1", status = "pending" },
		{ id = 2, description = "Task 2", status = "completed" },
	}
	return Result.Ok({ tasks = tasks, count = #tasks })
end

M.add_task = function(task_data)
	local mock_task = MockTask_Def.new(task_data)
	mock_task.id = math.random(1000, 9999)
	mock_task.uuid = "mock-uuid-" .. mock_task.id
	return Result.Ok({ task = mock_task })
end

M.modify_task = function(id, modifications)
	local mock_task = MockTask_Def.new({ id = id, description = "Default Modified Mock" })
	return Result.Ok({ task = mock_task })
end

M.delete_task = function()
	return Result.Ok(true)
end

M.annotate_task = function(id, annotations)
	local mock_task = MockTask_Def.new({ id = id, annotations = annotations })
	return Result.Ok({ task = mock_task })
end

M.new = function()
	return M
end

return M
