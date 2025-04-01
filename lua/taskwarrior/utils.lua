local M = {}

-- Split string into a list
function M.lines_to_list(str)
	local list = {}
	for line in str:gmatch("[^\r\n]+") do
		table.insert(list, line)
	end
	return list
end

-- Get git branch
function M.get_git_branch()
	local string_branch = vim.fn.system("git branch")
	local treated_branch = string.gsub(string_branch, "^%* ", "")
	return vim.fn.trim(treated_branch)
end

-- Set up keymaps
function M.setup_keymaps(config)
	local keymaps = config.keymaps

	vim.keymap.set("n", keymaps.dashboard, function()
		require("taskwarrior").open_dashboard()
	end, { noremap = true, silent = true, desc = "Open task dashboard" })

	vim.keymap.set("n", keymaps.browse, function()
		require("taskwarrior").browse_tasks()
	end, { noremap = true, silent = true, desc = "Browse tasks" })

	vim.keymap.set("n", keymaps.create_from_comment, function()
		require("taskwarrior").create_task_from_comment()
	end, { noremap = true, silent = true, desc = "Create task from comment" })

	vim.keymap.set("n", keymaps.create_from_markdown, function()
		require("taskwarrior").create_task_from_markdown()
	end, { noremap = true, silent = true, desc = "Create task from markdown" })

	vim.keymap.set("n", keymaps.mark_done, function()
		require("taskwarrior").complete_task()
	end, { noremap = true, silent = true, desc = "Mark task as done" })

	vim.keymap.set("n", keymaps.goto_task, function()
		require("taskwarrior").go_to_task_tui()
	end, { noremap = true, silent = true, desc = "Go to task in TUI" })

	vim.keymap.set("n", keymaps.priority, function()
		require("taskwarrior").set_task_priority()
	end, { noremap = true, silent = true, desc = "Set task priority" })

	vim.keymap.set("n", keymaps.due_date, function()
		require("taskwarrior").set_task_due_date()
	end, { noremap = true, silent = true, desc = "Set task due date" })

	vim.keymap.set("n", keymaps.sync, function()
		require("taskwarrior").sync_document()
	end, { noremap = true, silent = true, desc = "Sync task document" })

	vim.keymap.set("n", keymaps.pomodoro, function()
		require("taskwarrior").start_pomodoro()
	end, { noremap = true, silent = true, desc = "Start pomodoro for task" })

	vim.keymap.set("n", keymaps.calendar, function()
		require("taskwarrior").show_calendar()
	end, { noremap = true, silent = true, desc = "Show task calendar" })

	vim.keymap.set("n", keymaps.project, function()
		require("taskwarrior").show_project_summary()
	end, { noremap = true, silent = true, desc = "Show project summary" })

	vim.keymap.set("n", keymaps.recurring, function()
		require("taskwarrior").set_task_recurrence()
	end, { noremap = true, silent = true, desc = "Set task recurrence" })

	vim.keymap.set("n", keymaps.edit_task, function()
		require("taskwarrior").edit_task()
	end, { noremap = true, silent = true, desc = "Edit task in Neovim" })
end

-- Update task metadata in markdown
function M.update_task_metadata_in_markdown(line_number, key, value, opts)
	-- Default options
	opts = opts or {}
	local max_line_length = opts.max_line_length or (require("taskwarrior.config").get().max_line_length or 80)

	local buffer_id = vim.api.nvim_get_current_buf()
	local row = line_number - 1
	local total_lines = vim.api.nvim_buf_line_count(buffer_id)

	-- Get the current line
	local line = vim.api.nvim_buf_get_lines(buffer_id, row, row + 1, false)[1]

	-- Determine indentation
	local indent_level = line:match("^(%s*)")
	local continuation_indent = indent_level .. "  " -- Expected indent for continuation

	-- Find all lines belonging to this task
	local task_lines = { line }
	local end_row = row

	-- Check for continuation lines
	while end_row + 1 < total_lines do
		local next_line = vim.api.nvim_buf_get_lines(buffer_id, end_row + 1, end_row + 2, false)[1]

		-- Check if it's a continuation line (indented and not a new checkbox)
		if next_line:match("^" .. continuation_indent) and not next_line:match("^%s*%- %[") then
			table.insert(task_lines, next_line)
			end_row = end_row + 1
		else
			-- Not a continuation, stop here
			break
		end
	end

	-- Check if the metadata already exists in any of the task lines
	local pattern = "%[" .. key .. ":%s*[^%]]*%]"
	local metadata_line_index = nil

	for i, task_line in ipairs(task_lines) do
		if task_line:match(pattern) then
			metadata_line_index = i
			break
		end
	end

	-- Update or add the metadata
	if value == nil then
		-- Remove metadata
		if metadata_line_index then
			task_lines[metadata_line_index] = task_lines[metadata_line_index]:gsub("%s*" .. pattern, "")
		end
	else
		if metadata_line_index then
			-- Update existing metadata
			task_lines[metadata_line_index] =
				task_lines[metadata_line_index]:gsub(pattern, "[" .. key .. ": " .. value .. "]")
		else
			-- Add new metadata
			local metadata_string = " [" .. key .. ": " .. value .. "]"

			-- Check if adding to the last line would make it too long
			local last_line = task_lines[#task_lines]
			if #last_line + #metadata_string > max_line_length then
				-- Add a new line with the metadata
				local new_line = continuation_indent .. metadata_string:gsub("^%s+", "")
				table.insert(task_lines, new_line)
			else
				-- Add metadata to existing last line
				task_lines[#task_lines] = last_line .. metadata_string
			end
		end
	end

	-- Write back all the task lines
	vim.api.nvim_buf_set_lines(buffer_id, row, end_row + 1, false, task_lines)
end

function M.add_task_id_to_markdown(line_number, task_id, opts)
	opts = opts or {}
	local max_line_length = opts.max_line_length or (require("taskwarrior.config").get().max_line_length or 28)

	local buffer_id = vim.api.nvim_get_current_buf()
	local row = line_number - 1
	local total_lines = vim.api.nvim_buf_line_count(buffer_id)

	-- Get the current line
	local line = vim.api.nvim_buf_get_lines(buffer_id, row, row + 1, false)[1]

	-- Determine indentation
	local indent_level = line:match("^(%s*)")
	local continuation_indent = indent_level .. "  " -- Expected indent for continuation

	-- Find all lines belonging to this task
	local task_lines = { line }
	local end_row = row

	-- Check for continuation lines
	while end_row + 1 < total_lines do
		local next_line = vim.api.nvim_buf_get_lines(buffer_id, end_row + 1, end_row + 2, false)[1]

		-- Check if it's a continuation line (indented and not a new checkbox)
		if next_line:match("^" .. continuation_indent) and not next_line:match("^%s*%- %[") then
			table.insert(task_lines, next_line)
			end_row = end_row + 1
		else
			-- Not a continuation, stop here
			break
		end
	end

	-- Check if any line already has a task ID
	for i, task_line in ipairs(task_lines) do
		if task_line:match("%(ID:%s*%d+%)") then
			-- Already has a task ID, update it
			task_lines[i] = task_line:gsub("%(ID:%s*%d+%)", "(ID: " .. task_id .. ")")
			vim.api.nvim_buf_set_lines(buffer_id, row, end_row + 1, false, task_lines)
			return
		end
	end

	-- No existing task ID, add to the last line or a new line
	local last_line = task_lines[#task_lines]
	local task_id_string = " [ID](ID: " .. task_id .. ")"

	-- Check if adding the task ID would make the line too long
	if #last_line + #task_id_string > max_line_length then
		-- Add a new line with the task ID
		local new_line = continuation_indent .. task_id_string:gsub("^%s+", "")
		table.insert(task_lines, new_line)
	else
		-- Add task ID to existing last line
		task_lines[#task_lines] = last_line .. task_id_string
	end

	-- Write back all the task lines
	vim.api.nvim_buf_set_lines(buffer_id, row, end_row + 1, false, task_lines)
end

return M
