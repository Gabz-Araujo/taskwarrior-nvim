local M = {}
local api = require("taskwarrior.api")
local parser = require("taskwarrior.parser")

local function get_task_from_current_line()
	local task = parser.from_markdown()
	if task and task.task_id then
		return task
	end
	return nil
end

function M.set_recurring(task_id)
	if not task_id then
		local task = get_task_from_current_line()
		if task then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	local recurrence_patterns = {
		"daily",
		"weekdays",
		"weekly",
		"biweekly",
		"monthly",
		"quarterly",
		"yearly",
		"custom",
	}

	vim.ui.select(recurrence_patterns, { prompt = "Select recurrence pattern: " }, function(choice)
		if not choice then
			return
		end

		if choice == "custom" then
			vim.ui.input({ prompt = "Enter custom recurrence (e.g., 3days, 2weeks): " }, function(input)
				if not input or input == "" then
					return
				end

				local cmd = string.format("task %s modify recur:%s", task_id, input)
				local output = api.execute(cmd)

				local task = get_task_from_current_line()
				if task and tostring(task.task_id) == tostring(task_id) then
					require("taskwarrior.utils").update_task_metadata_in_markdown(task.line, "Recur", input)
				end
			end)
			return
		end

		local cmd = string.format("task %s modify recur:%s", task_id, choice)
		local output = api.execute(cmd)

		local task = get_task_from_current_line()
		if task and tostring(task.task_id) == tostring(task_id) then
			require("taskwarrior.utils").update_task_metadata_in_markdown(task.line, "Recur", choice)
		end
	end)
end

function M.remove_recurring(task_id)
	if not task_id then
		local task = get_task_from_current_line()
		if task then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	local cmd = string.format("task %s modify recur:", task_id)
	local output = api.execute(cmd)

	local task = get_task_from_current_line()
	if task and tostring(task.task_id) == tostring(task_id) then
		require("taskwarrior.utils").update_task_metadata_in_markdown(task.line, "Recur", nil)
	end
end

return M
