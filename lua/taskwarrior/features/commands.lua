local M = {}
local api = require("taskwarrior.api")
local parser = require("taskwarrior.parser")
local utils = require("taskwarrior.utils")
local config

function M.setup(user_config)
	config = user_config
end

local function get_task_from_current_line()
	local task = parser.from_markdown()
	if task and task.task_id then
		return task
	end
	return nil
end

function M.create_task_from_comment()
	local current_line = vim.api.nvim_get_current_line()
	local task = parser.from_comment(current_line)

	if not task then
		api.notify("No valid task marker found in the current line", vim.log.levels.ERROR)
		return
	end

	local async = require("plenary.async")
	async.run(function()
		local additional_tags = {}
		local project

		local project_ready = async.control.Condvar.new()
		vim.ui.select(api.get_projects(), {
			prompt = "Select the project",
		}, function(choice)
			project = choice
			project_ready:notify_all()
		end)
		project_ready:wait()

		local tags_ready = async.control.Condvar.new()
		vim.ui.input({
			prompt = "Enter any additional tags separated by spaces: ",
		}, function(input)
			if input and input ~= "" then
				for tag in input:gmatch("%S+") do
					table.insert(additional_tags, tag)
				end
			end
			tags_ready:notify_all()
		end)
		tags_ready:wait()

		local line_number = vim.fn.line(".")
		local file_path = vim.fn.expand("%:p")
		local git_branch = utils.get_git_branch()

		local annotations = {
			string.format("nvimline:%s:%s", line_number, file_path),
			string.format("branch:%s", git_branch),
		}

		local options = {
			project = project,
			annotations = annotations,
		}

		task.tags = additional_tags
		local task_id = api.create_task(task, options)

		if task_id then
			api.notify("Task created: " .. task_id)
		end
	end)
end

function M.create_task_from_markdown()
	local task = parser.from_markdown()

	if not task then
		api.notify("No valid task found under cursor. Ensure the line is a markdown checkbox.", vim.log.levels.ERROR)
		return
	end

	if task.task_id then
		api.notify("Task already has ID: " .. task.task_id)
		return
	end

	local task_id = api.create_task(task, {
		project = table.concat(task.project, "."),
	})

	if task_id then
		utils.add_task_id_to_markdown(task.line, task_id)
		api.notify("Task created: " .. task_id)
	else
		api.notify("Failed to create task", vim.log.levels.ERROR)
	end
end

function M.mark_task_as_done()
	local current_line = vim.api.nvim_get_current_line()
	local task

	task = parser.from_markdown()

	if task and task.task_id then
		local success = api.complete_task(task.task_id)
		if success then
			local buffer_id = vim.api.nvim_get_current_buf()
			local row = task.line - 1
			local line = vim.api.nvim_buf_get_lines(buffer_id, row, row + 1, false)[1]
			local updated_line = line:gsub("^(%s*%- )%[%s*%]", "%1[x]")
			vim.api.nvim_buf_set_lines(buffer_id, row, row + 1, false, { updated_line })

			local today = os.date("%Y-%m-%d")
			utils.update_task_metadata_in_markdown(task.line, "Completed", today)

			api.notify("Task marked as done: " .. task.task_id)
		else
			api.notify("Failed to mark task as done", vim.log.levels.ERROR)
		end
		return
	end

	task = parser.from_comment(current_line)

	if task then
		vim.cmd("normal! gcc") -- Comment the line
		local success = api.complete_task(task.description)
		if success then
			vim.cmd("normal! dd") -- Delete the line
			api.notify("Task marked as done")
		else
			vim.cmd("normal! u")
			api.notify("Failed to mark task as done", vim.log.levels.ERROR)
		end
	else
		api.notify("No valid task found in the current line", vim.log.levels.ERROR)
	end
end

function M.set_task_priority(task_id)
	if not task_id then
		local task = get_task_from_current_line()
		if task then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	vim.ui.select({ "H", "M", "L", "None" }, { prompt = "Select task priority: " }, function(choice)
		if not choice then
			return
		end

		local success = api.set_priority(task_id, choice)

		local task = get_task_from_current_line()
		if task and tostring(task.task_id) == tostring(task_id) then
			if choice == "None" then
				utils.update_task_metadata_in_markdown(task.line, "Priority", nil)
			else
				utils.update_task_metadata_in_markdown(task.line, "Priority", choice)
			end
		end
	end)
end

function M.set_task_due_date(task_id)
	if not task_id then
		local task = get_task_from_current_line()
		if task then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	local date_options = {
		"today",
		"tomorrow",
		"next week",
		"next month",
		"custom date",
		"remove due date",
	}

	vim.ui.select(date_options, { prompt = "Select due date: " }, function(choice)
		if not choice then
			return
		end

		if choice == "custom date" then
			vim.ui.input({ prompt = "Enter due date (YYYY-MM-DD): " }, function(input)
				if not input or input == "" then
					return
				end

				local success = api.set_due_date(task_id, input)

				local task = get_task_from_current_line()
				if task and tostring(task.task_id) == tostring(task_id) then
					utils.update_task_metadata_in_markdown(task.line, "Due", input)
				end
			end)
			return
		elseif choice == "remove due date" then
			local success = api.set_due_date(task_id, nil)

			local task = get_task_from_current_line()
			if task and tostring(task.task_id) == tostring(task_id) then
				utils.update_task_metadata_in_markdown(task.line, "Due", nil)
			end
		else
			local success = api.set_due_date(task_id, choice)

			local task_data = api.get_task(task_id)

			local task = get_task_from_current_line()
			if task and tostring(task.task_id) == tostring(task_id) and task_data and task_data.due then
				utils.update_task_metadata_in_markdown(task.line, "Due", task_data.due:sub(1, 10))
			end
		end
	end)
end

function M.set_task_recurrence(task_id)
	if not task_id then
		local task = get_task_from_current_line()
		if task then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	local recurrence_options = {
		"daily",
		"weekly",
		"monthly",
		"yearly",
		"custom",
		"remove recurrence",
	}

	vim.ui.select(recurrence_options, { prompt = "Select recurrence pattern: " }, function(choice)
		if not choice then
			return
		end

		if choice == "custom" then
			vim.ui.input({ prompt = "Enter recurrence pattern (e.g., 2weeks, 3days): " }, function(input)
				if not input or input == "" then
					return
				end

				local success = api.set_recurring(task_id, input)

				local task = get_task_from_current_line()
				if task and tostring(task.task_id) == tostring(task_id) then
					utils.update_task_metadata_in_markdown(task.line, "Recur", input)
				end
			end)
			return
		elseif choice == "remove recurrence" then
			local success = api.set_recurring(task_id, nil)

			if not success then
				api.notify("Error setting recurrence on task", vim.log.levels.ERROR)
			end

			local task = get_task_from_current_line()
			if task and tostring(task.task_id) == tostring(task_id) then
				utils.update_task_metadata_in_markdown(task.line, "Recur", nil)
			end
		else
			local success = api.set_recurring(task_id, choice)

			if not success then
				api.notify("Error setting recurrence on task" .. task_id, vim.log.levels.ERROR)
			end

			local task = get_task_from_current_line()
			if task and tostring(task.task_id) == tostring(task_id) then
				utils.update_task_metadata_in_markdown(task.line, "Recur", choice)
			end
		end
	end)
end

function M.add_annotation(task_id)
	if not task_id then
		local task = get_task_from_current_line()
		if task then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	local annotation = vim.fn.input("Add a annotation: ")

	local success = api.add_annotation(task_id, annotation)

	if not success then
		api.notify("Error setting recurrence on task", vim.log.levels.ERROR)
	end
end

-- Replace go_to_task_tui function
function M.go_to_task_tui()
	local current_line = vim.api.nvim_get_current_line()
	local original_line = current_line
	local task_id

	-- Check if the line contains a task ID directly
	task_id = current_line:match("%(ID:%s*(%d+)%)")

	if task_id then
		require("taskwarrior.ui.task_view").show_task(task_id)
		return
	end

	-- Try to parse as a comment
	local task = parser.from_comment(current_line)

	if task then
		-- Try to find the task by description
		require("taskwarrior.ui.task_view").show_task(nil, task.description)
		return
	end

	-- Try to parse as markdown
	task = parser.from_markdown()

	if task and task.task_id then
		require("taskwarrior.ui.task_view").show_task(task.task_id)
		return
	elseif task then
		require("taskwarrior.ui.task_view").show_task(nil, task.description)
		return
	end

	api.notify("No valid task found in the current line", vim.log.levels.ERROR)
	return nil
end

return M
