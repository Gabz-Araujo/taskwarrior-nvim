local TaskService = require("taskwarrior.domain.services.task_service")
local Result = require("taskwarrior.utils.result")

local M = {}

function M.execute(filter)
	return TaskService.get_tasks(filter)
end

return M
