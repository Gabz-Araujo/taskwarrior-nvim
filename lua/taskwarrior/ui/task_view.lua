local M = {}
local api = require("taskwarrior.api")
local editor = require("taskwarrior.features.editor")

-- Namespace for extmarks
local ns = vim.api.nvim_create_namespace("taskwarrior_task_view")

-- Format a task for display
local function format_task_details(task)
	local lines = {
		"# Task " .. task.id .. ": " .. task.description,
		"",
		"Status: " .. (task.status or "pending"),
	}

	if task.project then
		table.insert(lines, "Project: " .. task.project)
	end

	if task.priority then
		table.insert(lines, "Priority: " .. task.priority)
	end

	if task.due then
		table.insert(lines, "Due Date: " .. task.due:sub(1, 10))
	end

	if task.recur then
		table.insert(lines, "Recurrence: " .. task.recur)
	end

	if task.tags and #task.tags > 0 then
		table.insert(lines, "Tags: " .. table.concat(task.tags, ", "))
	end

	if task.urgency then
		table.insert(lines, string.format("Urgency: %.2f", task.urgency))
	end

	-- Add annotations
	if task.annotations and #task.annotations > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Annotations")
		for _, annotation in ipairs(task.annotations) do
			table.insert(lines, "- " .. annotation.description)
		end
	end

	-- Add dependent tasks
	if task.depends then
		table.insert(lines, "")
		table.insert(lines, "## Dependencies")

		-- Get dependent tasks
		local depends_ids = {}
		for id in task.depends:gmatch("(%d+),?") do
			table.insert(depends_ids, id)
		end

		-- Fetch and display each dependency
		for _, id in ipairs(depends_ids) do
			local dep_task = api.get_task(id)
			if dep_task then
				local status = dep_task.status or "pending"
				local status_marker = status == "completed" and "[x]" or "[ ]"
				table.insert(lines, string.format("- %s Task #%s: %s", status_marker, id, dep_task.description))
			else
				table.insert(lines, string.format("- Task #%s (not found)", id))
			end
		end
	end

	-- Add related tasks (blocked by this task)
	local related = api.get_tasks("depends:" .. task.id)
	if #related > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Blocked Tasks")
		for _, rel_task in ipairs(related) do
			local status = rel_task.status or "pending"
			local status_marker = status == "completed" and "[x]" or "[ ]"
			table.insert(lines, string.format("- %s Task #%s: %s", status_marker, rel_task.id, rel_task.description))
		end
	end

	return lines
end

-- Open task view
function M.show_task(task_id, description)
	local task

	-- Try to find the task
	if task_id and tonumber(task_id) then
		task = api.get_task(task_id)
	elseif description then
		-- Try to find by description
		local tasks = api.get_tasks()
		for _, t in ipairs(tasks) do
			if t.description:find(description, 1, true) then
				task = t
				break
			end
		end
	end

	if not task then
		api.notify("Task not found", vim.log.levels.ERROR)
		return
	end

	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)

	-- Create window
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

	-- Format and display task
	local lines = format_task_details(task)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	-- Set up keymaps
	local kopts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, kopts)
	vim.keymap.set("n", "e", function()
		vim.api.nvim_win_close(win, true)
		editor.edit_task(task.id)
	end, kopts)
	vim.keymap.set("n", "d", function()
		api.complete_task(task.id)
		vim.api.nvim_win_close(win, true)
		api.notify("Task marked as done")
	end, kopts)

	-- Add help text at the bottom
	local help_line = vim.api.nvim_buf_line_count(buf)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, help_line, help_line, false, {
		"",
		"Press: e to edit, d to mark done, q to close, click on task IDs to view",
	})
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	return buf, win
end

return M
