local M = {}
local api = require("taskwarrior.api")

function M.open()
	local buf = vim.api.nvim_create_buf(false, true)

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	local projects = api.get_projects()

	local content = {
		"# Project Summary",
		"",
	}

	for _, project in ipairs(projects) do
		if project ~= "" then
			local project_tasks = api.get_tasks('project:"' .. project .. '"')

			if #project_tasks > 0 then
				local pending = 0
				local completed = 0

				for _, task in ipairs(project_tasks) do
					if task.status == "pending" then
						pending = pending + 1
					elseif task.status == "completed" then
						completed = completed + 1
					end
				end

				local total = pending + completed
				local progress = total > 0 and math.floor((completed / total) * 100) or 0

				table.insert(content, "## " .. project)
				table.insert(
					content,
					string.format("Progress: %d%% (%d/%d tasks completed)", progress, completed, total)
				)
				table.insert(content, "")

				table.insert(content, "### Pending Tasks")
				local count = 0
				for _, task in ipairs(project_tasks) do
					if task.status == "pending" and count < 5 then
						local priority = task.priority and " (" .. task.priority .. ")" or ""
						table.insert(content, string.format("- [%d] %s%s", task.id, task.description, priority))
						count = count + 1
					end
				end
				table.insert(content, "")
			end
		end
	end

	table.insert(content, "## Controls")
	table.insert(content, "- Press 'q' to close")
	table.insert(content, "- Press 'd' on a task line to mark as done")
	table.insert(content, "- Press 'n' to create a new task")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	local kopts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, kopts)
	vim.keymap.set("n", "d", function()
		local line = vim.api.nvim_get_current_line()
		local task_id = line:match("%[(%d+)%]")
		if task_id then
			api.complete_task(task_id)
			M.open() -- Refresh
		end
	end, kopts)
	vim.keymap.set("n", "n", function()
		local current_line = vim.fn.line(".")
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local project

		for i = current_line, 1, -1 do
			if lines[i]:match("^## ") then
				project = lines[i]:gsub("^## ", "")
				break
			end
		end

		vim.api.nvim_win_close(win, true)

		vim.ui.input({ prompt = "Task description: " }, function(input)
			if input and input ~= "" then
				local task = {
					description = input,
					type = "project",
				}

				local options = {}
				if project then
					options.project = project
				end

				api.create_task(task, options)
				M.open() -- Reopen with new task
			end
		end)
	end, kopts)

	return buf, win
end

return M
