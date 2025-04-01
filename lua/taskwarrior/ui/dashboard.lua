local M = {}
local api = require("taskwarrior.api")
local utils = require("taskwarrior.utils")

function M.open()
	local buf = vim.api.nvim_create_buf(false, true)

	local width = math.floor(vim.o.columns * 0.9)
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

	local pending = vim.fn.trim(vim.fn.system("task status:pending count"))
	local urgent = vim.fn.trim(vim.fn.system("task +PRIORITY.above:M +PENDING count"))
	local overdue = vim.fn.trim(vim.fn.system("task +OVERDUE count"))

	local recent_tasks = api.get_tasks("limit:5 status:pending")

	local content = {
		"# Task Dashboard",
		"",
		"## Summary",
		"- Pending tasks: " .. pending,
		"- Urgent tasks: " .. urgent,
		"- Overdue tasks: " .. overdue,
		"",
		"## Recent Tasks",
	}

	for _, task in ipairs(recent_tasks) do
		local task_line = string.format("[%d] %s", task.id, task.description)
		if task.priority then
			task_line = task_line .. " (" .. task.priority .. ")"
		end
		if task.due then
			task_line = task_line .. " [Due: " .. task.due:sub(1, 10) .. "]"
		end
		table.insert(content, "- " .. task_line)
	end

	table.insert(content, "")
	table.insert(content, "## Actions")
	table.insert(content, "- [n] New task")
	table.insert(content, "- [b] Browse tasks")
	table.insert(content, "- [p] Set priority")
	table.insert(content, "- [d] Set due date")
	table.insert(content, "- [s] Sync document")
	table.insert(content, "- [c] Calendar view")
	table.insert(content, "- [q] Close dashboard")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	local kopts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "n", function()
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
		require("taskwarrior").create_task_from_comment()
	end, kopts)
	vim.keymap.set("n", "b", function()
		require("taskwarrior").browse_tasks()
	end, kopts)
	vim.keymap.set("n", "p", function()
		require("taskwarrior").set_task_priority()
	end, kopts)
	vim.keymap.set("n", "d", function()
		require("taskwarrior").set_task_due_date()
	end, kopts)
	vim.keymap.set("n", "s", function()
		require("taskwarrior").sync_document()
	end, kopts)
	vim.keymap.set("n", "c", function()
		require("taskwarrior").show_calendar()
	end, kopts)
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, kopts)

	return buf, win
end

return M
