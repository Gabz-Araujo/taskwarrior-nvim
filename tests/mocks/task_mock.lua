-- tests/mocks/task_mock.lua
local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")

local M = {}
local mt = { __index = M }

M.from_taskwarrior_json = function(data)
	data = vim.deepcopy(data)
	data._is_mock_task = true
	return setmetatable(data, mt)
end

M._validate = function(task_data)
	if task_data then
		return Result.Ok(true)
	end
	return Result.Err(Error.taskwarrior_error("No task provided"))
end

M.new = function(task_data)
	task_data = vim.deepcopy(task_data)
	task_data._is_mock_task = true
	return setmetatable(task_data, mt)
end

function M:clone()
	local new_task = vim.deepcopy(self)
	return setmetatable(new_task, mt)
end

function M:diff(other)
	return {}
end

return M
