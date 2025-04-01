local M = {}
local config = {}

function M.setup(user_config)
	config = user_config
end

function M.execute(cmd, silent)
	local result = vim.fn.system(cmd)
	if not silent and result ~= "" then
		M.notify(result)
	end
	return result
end

function M.notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Taskwarrior" })
end

function M.get_tasks(filter)
	filter = filter or "status:pending"
	local cmd = string.format("task %s export", filter)
	local result = M.execute(cmd, true)
	local success, tasks = pcall(vim.fn.json_decode, result)

	if not success then
		M.notify("Failed to parse tasks: " .. result, vim.log.levels.ERROR)
		return {}
	end

	return tasks
end

function M.get_projects()
	local projects_raw = M.execute("task _projects", true)
	local projects = {}
	for project in projects_raw:gmatch("[^\r\n]+") do
		table.insert(projects, project)
	end
	return projects
end

function M.create_task(task, options)
	options = options or {}

	local cmd = string.format('task add "%s"', task.description)

	if task.type == "comment" and task.tag then
		cmd = cmd .. " +" .. task.tag
	end

	if task.tags and #task.tags > 0 then
		for _, tag in ipairs(task.tags) do
			cmd = cmd .. " +" .. tag
		end
	end

	if options.project and #options.project > 0 then
		cmd = cmd .. ' project:"' .. options.project .. '"'
	end

	if task.priority then
		cmd = cmd .. " priority:" .. task.priority
	end

	if task.due then
		cmd = cmd .. " due:" .. task.due
	end

	local output = M.execute(cmd)

	local task_id = output:match("Created task (%d+)%.")
	if not task_id then
		return nil, "API: Failed to create task"
	end

	local task_data = M.get_task(task_id)
	local uuid = task_data and task_data.uuid

	if options.annotations then
		for _, annotation in ipairs(options.annotations) do
			local annotation_cmd = string.format('task uuid:%s annotate "%s"', uuid, annotation)
			M.execute(annotation_cmd, true)
		end
	end

	return uuid, task_id
end

function M.complete_task(task_identifier)
	if not task_identifier then
		return false, "No task identifier provided"
	end

	local output
	output = M.execute("task " .. task_identifier .. " done")

	return output:match("Completed"), output
end

function M.add_annotation(task_identifier, annotation)
	if not task_identifier or not annotation or annotation == "" then
		return false, "Invalid task identifier or annotation"
	end

	local cmd

	if task_identifier:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then
		cmd = string.format('task uuid:%s annotate "%s"', task_identifier, annotation)
	else
		cmd = string.format('task %s annotate "%s"', task_identifier, annotation)
	end

	local output = M.execute(cmd)

	return output:match("Annotated"), output
end

function M.set_priority(task_identifier, priority)
	if not task_identifier then
		return false, "No task identifier provided"
	end

	local cmd

	if not priority or priority == "None" then
		cmd = string.format("task %s modify priority:", task_identifier)
	else
		cmd = string.format("task %s modify priority:%s", task_identifier, priority)
	end

	local output = M.execute(cmd)
	return output:match("Modified"), output
end

function M.set_due_date(task_identifier, due_date)
	if not task_identifier then
		return false, "No task identifier provided"
	end

	local cmd
	if not due_date or due_date == "" then
		cmd = string.format("task %s modify due:", task_identifier)
	else
		cmd = string.format("task %s modify due:%s", task_identifier, due_date)
	end

	local output = M.execute(cmd)
	return output:match("Modified"), output
end

function M.get_task(task_identifier)
	if not task_identifier then
		return nil, "No task identifier provided"
	end

	local cmd
	if task_identifier:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then
		cmd = string.format("task uuid:%s export", task_identifier)
	elseif task_identifier:match("^%d+$") then
		cmd = string.format("task %s export", task_identifier)
	else
		cmd = string.format("task description:'%s' export", task_identifier)
	end

	local output = M.execute(cmd, true)

	local success, task_data = pcall(vim.fn.json_decode, output)
	if not success or not task_data[1] then
		return nil, "Failed to get task data"
	end

	return task_data[1]
end

function M.set_recurring(task_identifier, recurrence)
	if not task_identifier then
		return false, "No task ID provided"
	end

	local cmd
	if not recurrence or recurrence == "" then
		cmd = string.format("task %s modify recur:", task_identifier)
	else
		cmd = string.format("task %s modify recur:%s", task_identifier, recurrence)
	end

	local output = M.execute(cmd)
	return output:match("Modified"), output
end

-- Update multiple task fields at once
function M.update_task(task_identifier, fields)
	if not task_identifier then
		return false, "No task ID provided"
	end

	local cmd = string.format("task %s modify", task_identifier)

	-- Add each field to the command
	for field, value in pairs(fields) do
		if field == "description" then
			cmd = cmd .. string.format(' description:"%s"', value)
		elseif field == "project" then
			if value and value ~= "" then
				cmd = cmd .. string.format(' project:"%s"', value)
			else
				cmd = cmd .. " project:"
			end
		elseif field == "tags" then
		-- Tags are handled separately with add/remove
		-- Skip here
		else
			if value and value ~= "" then
				cmd = cmd .. string.format(" %s:%s", field, value)
			else
				cmd = cmd .. string.format(" %s:", field)
			end
		end
	end

	local output = M.execute(cmd)
	return output:match("Modified"), output
end

return M
