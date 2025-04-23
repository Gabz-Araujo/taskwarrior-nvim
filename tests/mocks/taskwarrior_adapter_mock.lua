local Result = require("taskwarrior.utils.result")
local MockTask_Def = require("tests.mocks.task_mock")

local M = {}

M.get_tasks = function()
	return Result.Ok({ tasks = {}, count = 0 })
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

return M
