local M = {}
local api = require("taskwarrior.api")
local parser = require("taskwarrior.parser")

vim.api.nvim_create_namespace("taskwarrior_editor")

-- Store editor state
local editor_state = {
	task_id = nil,
	original_task = nil,
	buffer = nil,
	window = nil,
}

-- Format a task into editable text
local function format_task_for_editing(task)
	local lines = {
		"# Task Editor - ID: " .. task.id,
		"# Save: <leader>s or :w  |  Cancel: q or :q!",
		"# Fields with '*' are required",
		"",
		"## Description *",
		task.description or "",
		"",
		"## Project",
		task.project or "",
		"",
		"## Priority",
		task.priority or "",
		"",
		"## Due Date (YYYY-MM-DD)",
		task.due and task.due:sub(1, 10) or "",
		"",
		"## Tags (space separated)",
		task.tags and table.concat(task.tags, " ") or "",
		"",
		"## Recurrence",
		task.recur or "",
		"",
		"## Depends (comma separated IDs)",
		task.depends or "",
		"",
		"## Annotations (one per line)",
	}

	-- Add annotations (one per line)
	if task.annotations then
		for _, annotation in ipairs(task.annotations) do
			table.insert(lines, annotation.description)
		end
	else
		table.insert(lines, "")
	end

	return lines
end

-- Parse edited text back into task structure
local function parse_edited_task(lines)
	local task = {}
	local current_section = nil
	local section_content = {}

	-- Helper to process a completed section
	local function process_section()
		if not current_section then
			return
		end

		local content = table.concat(section_content, "\n")
		content = vim.fn.trim(content)

		if current_section == "Description" then
			task.description = content
		elseif current_section == "Project" then
			task.project = content ~= "" and content or nil
		elseif current_section == "Priority" then
			if content == "H" or content == "M" or content == "L" or content == "" then
				task.priority = content ~= "" and content or nil
			end
		elseif current_section == "Due Date" then
			if content:match("^%d%d%d%d%-%d%d%-%d%d$") or content == "" then
				task.due = content ~= "" and content or nil
			end
		elseif current_section == "Tags" then
			if content ~= "" then
				task.tags = {}
				for tag in content:gmatch("%S+") do
					table.insert(task.tags, tag)
				end
			else
				task.tags = nil
			end
		elseif current_section == "Recurrence" then
			task.recur = content ~= "" and content or nil
		elseif current_section == "Depends" then
			task.depends = content ~= "" and content or nil
		elseif current_section == "Annotations" then
			if content ~= "" then
				task.annotations = {}
				for line in content:gmatch("[^\r\n]+") do
					if line ~= "" then
						table.insert(task.annotations, { description = line })
					end
				end
			else
				task.annotations = nil
			end
		end

		current_section = nil
		section_content = {}
	end

	for _, line in ipairs(lines) do
		-- Check if this is a section header
		local section = line:match("^##%s+([^%*]+)")
		if section then
			process_section()
			current_section = vim.fn.trim(section)
			section_content = {}
		elseif current_section and not line:match("^#") then
			table.insert(section_content, line)
		end
	end

	process_section()

	return task
end

-- Save changes to Taskwarrior
local function save_task_changes()
	if not editor_state.task_id or not editor_state.buffer then
		api.notify("No task being edited", vim.log.levels.ERROR)
		return false
	end

	-- Get all lines from the buffer
	local lines = vim.api.nvim_buf_get_lines(editor_state.buffer, 0, -1, false)

	-- Parse the edited content
	local edited_task = parse_edited_task(lines)

	-- Validate required fields
	if not edited_task.description or edited_task.description == "" then
		api.notify("Description is required", vim.log.levels.ERROR)
		return false
	end

	-- Build modification command
	local cmd = string.format('task %s modify description:"%s"', editor_state.task_id, edited_task.description)

	-- Add other fields
	if edited_task.project then
		cmd = cmd .. string.format(' project:"%s"', edited_task.project)
	else
		cmd = cmd .. " project:"
	end

	if edited_task.priority then
		cmd = cmd .. string.format(" priority:%s", edited_task.priority)
	else
		cmd = cmd .. " priority:"
	end

	if edited_task.due then
		cmd = cmd .. string.format(" due:%s", edited_task.due)
	else
		cmd = cmd .. " due:"
	end

	if edited_task.recur then
		cmd = cmd .. string.format(" recur:%s", edited_task.recur)
	else
		cmd = cmd .. " recur:"
	end

	if edited_task.depends then
		cmd = cmd .. string.format(" depends:%s", edited_task.depends)
	else
		cmd = cmd .. " depends:"
	end

	-- Execute the modification
	local output = api.execute(cmd)

	-- Process tags separately (add/remove as needed)
	local original_tags = editor_state.original_task.tags or {}
	local edited_tags = edited_task.tags or {}

	-- Remove tags that are no longer present
	for _, tag in ipairs(original_tags) do
		local found = false
		for _, edited_tag in ipairs(edited_tags) do
			if tag == edited_tag then
				found = true
				break
			end
		end

		if not found then
			api.execute(string.format("task %s denotate +%s", editor_state.task_id, tag))
		end
	end

	-- Add new tags
	for _, tag in ipairs(edited_tags) do
		local found = false
		for _, original_tag in ipairs(original_tags) do
			if tag == original_tag then
				found = true
				break
			end
		end

		if not found then
			api.execute(string.format("task %s modify +%s", editor_state.task_id, tag))
		end
	end

	-- Handle annotations
	-- First, get current annotations to avoid duplicates
	local current_task = api.get_task(editor_state.task_id)
	local current_annotations = current_task.annotations or {}

	-- Add new annotations
	if edited_task.annotations then
		for _, annotation in ipairs(edited_task.annotations) do
			local is_new = true

			-- Check if this annotation already exists
			for _, existing in ipairs(current_annotations) do
				if existing.description == annotation.description then
					is_new = false
					break
				end
			end

			-- Add if it's new
			if is_new then
				api.add_annotation(editor_state.task_id, annotation.description)
			end
		end
	end

	api.notify("Task updated successfully")
	return true
end

-- Close the editor
local function close_editor()
	if editor_state.window and vim.api.nvim_win_is_valid(editor_state.window) then
		vim.api.nvim_win_close(editor_state.window, true)
	end

	if editor_state.buffer and vim.api.nvim_buf_is_valid(editor_state.buffer) then
		vim.api.nvim_buf_delete(editor_state.buffer, { force = true })
	end

	editor_state.task_id = nil
	editor_state.original_task = nil
	editor_state.buffer = nil
	editor_state.window = nil
end

-- Open the task editor
function M.edit_task(task_id)
	-- Check if editor is already open
	if editor_state.buffer then
		api.notify("Task editor is already open", vim.log.levels.WARN)
		return
	end

	-- If no task_id provided, try to get from current line
	if not task_id then
		local task = parser.from_current_line()
		if task and task.task_id then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	-- Get task data
	local task = api.get_task(task_id)
	if not task then
		api.notify("Failed to get task data for ID: " .. task_id, vim.log.levels.ERROR)
		return
	end

	-- Store the original task
	editor_state.task_id = task_id
	editor_state.original_task = task

	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	editor_state.buffer = buf

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_name(buf, "taskwarrior://" .. task_id)

	-- Format task data for editing
	local lines = format_task_for_editing(task)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Find editable line numbers (content lines after section headers)
	local editable_lines = {}
	for i, line in ipairs(lines) do
		if line:match("^##%s+") then
			-- The next line after a header is the editable content
			table.insert(editable_lines, i)
		end
	end

	-- Function to navigate between editable fields
	local function navigate_to_next_field(direction)
		local win = vim.api.nvim_get_current_win()
		local current_pos = vim.api.nvim_win_get_cursor(win)
		local current_line = current_pos[1]
		local next_line = nil

		if direction > 0 then
			-- Find the next editable line after current position
			for _, line_num in ipairs(editable_lines) do
				if line_num > current_line then
					next_line = line_num + 1
					break
				end
			end
			-- If no next line found, cycle to the first one
			if not next_line and #editable_lines > 0 then
				next_line = editable_lines[1] + 1
			end
		else
			-- Find the previous editable line before current position
			for i = #editable_lines, 1, -1 do
				if editable_lines[i] < current_line then
					next_line = editable_lines[i]
					break
				end
			end
			-- If no previous line found, cycle to the last one
			if not next_line and #editable_lines > 0 then
				next_line = editable_lines[#editable_lines]
			end
		end

		-- Move cursor to the next field if found
		if next_line then
			local content_line = lines[next_line]
			vim.api.nvim_win_set_cursor(win, { next_line, 0 })
			-- Place cursor at end of content if there is content
			if content_line and content_line ~= "" then
				vim.api.nvim_win_set_cursor(win, { next_line, #content_line })
			end
		end
	end

	-- Format task data for editing
	local lines = format_task_for_editing(task)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Create window with appropriate size
	local width = math.floor(vim.o.columns * 0.98)
	local height = math.floor(vim.o.lines * 0.95)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)
	editor_state.window = win

	-- Set up keymaps
	local kopts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "<leader>s", function()
		if save_task_changes() then
			close_editor()
		end
	end, kopts)

	vim.keymap.set("n", "q", function()
		close_editor()
	end, kopts)

	vim.keymap.set("n", "<Tab>", function()
		navigate_to_next_field(1)
	end, kopts)
	vim.keymap.set("i", "<Tab>", function()
		vim.cmd("stopinsert") -- Exit insert mode
		navigate_to_next_field(1)
		vim.cmd("startinsert") -- Enter insert mode at the new position
		vim.cmd("startinsert!") -- Move cursor to the end of line
	end, kopts)

	-- Add shift-tab for reverse navigation
	vim.keymap.set("n", "<S-Tab>", function()
		navigate_to_next_field(-1)
	end, kopts)
	vim.keymap.set("i", "<S-Tab>", function()
		vim.cmd("stopinsert") -- Exit insert mode
		navigate_to_next_field(-1)
		vim.cmd("startinsert") -- Enter insert mode at the new position
		vim.cmd("startinsert!") -- Move cursor to the end of line
	end, kopts)

	-- Set up autocmds for saving and closing
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			if save_task_changes() then
				vim.api.nvim_buf_set_option(buf, "modified", false)
				close_editor()
			end
		end,
	})

	vim.api.nvim_create_autocmd("QuitPre", {
		buffer = buf,
		callback = function()
			close_editor()
		end,
	})

	-- Set initial cursor position at the description
	vim.api.nvim_win_set_cursor(win, { 6, 0 })

	return buf, win
end

return M
