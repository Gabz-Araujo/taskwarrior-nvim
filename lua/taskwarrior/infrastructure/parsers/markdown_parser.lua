local Result = require("taskwarrior.utils.result")
local Task = require("taskwarrior.domain.entities.task")
local DateUtils = require("taskwarrior.utils.date_utils")
local BufferReader = require("taskwarrior.infrastructure.io.buffer_reader")

-- Constants for parsing
local CHECKBOX_PATTERN = "^%s*-%s+%[([x%s!%-cur])%]%s+(.+)$"
local TAG_PATTERN = "#([%w_%-]+)"
local HEADER_PATTERN = "^(#+)%s+(.+)$"
local MAX_DEPENDENCY_DEPTH = 5

-- Add this helper function to detect if a line is a continuation line
---@param line string The line to check
---@return boolean True if the line is a continuation line, false otherwise
local function is_continuation_line(line)
	return line:match("^%s+%S") and not line:match("^%s*-%s+%[")
end

---Add this helper function to find the main task line for a continuation
---@param lines table A table of lines in the buffer
---@param current_line_num number The line number to start searching from
---@return number|nil The line number of the task, or nil if not found
local function find_task_for_continuation(lines, current_line_num)
	-- Go backwards until we find a checkbox line
	local line_num = current_line_num
	while line_num > 0 do
		local line = lines[line_num]
		-- If we hit a checkbox line, that's our task
		if line:match(CHECKBOX_PATTERN) then
			return line_num
		end
		-- If we hit a non-continuation line, we've gone too far
		if not is_continuation_line(line) then
			return nil
		end
		line_num = line_num - 1
	end
	return nil
end

---Extract checkbox and content from a line
---@param line string The line to parse
---@return boolean found Whether a checkbox was found
---@return boolean|nil checked Whether the checkbox is checked
---@return string|nil content The content of the line without the checkbox
---@return string|nil checkbox_type The type of checkbox (x, space, !, -, etc.)
local function extract_checkbox(line)
	local checkbox, content = line:match(CHECKBOX_PATTERN)
	if not checkbox then
		return false, nil, nil, nil
	end

	local checked = checkbox == "x"
	return true, checked, content, checkbox
end

---Extract all tags from a line
---@param line string The line to parse
---@return table tags A table of extracted tags
local function extract_tags(line)
	local tags = {}
	for tag in line:gmatch(TAG_PATTERN) do
		table.insert(tags, tag)
	end
	return tags
end

---Extract project from header
---@param lines table All lines in the buffer
---@param line_num number The line number of the task
---@return string|nil project The extracted project, if any
---@return string|nil area The extracted area, if any
local function extract_project(lines, line_num)
	local current_line = line_num
	local projects = {}
	local area = nil

	-- Go backwards through lines to find headers
	while current_line > 0 do
		local line = lines[current_line]
		local level, title = line:match(HEADER_PATTERN)

		if level and title then
			local indentation = #level
			title = title:gsub("%s*$", "") -- remove trailing whitespace

			if indentation == 1 then
				-- Level 1 heading (#) is treated as Area
				if not area then
					area = title
				end
			else
				-- Level 2+ headings become part of the project path
				if #projects == 0 or indentation < projects[#projects].indentation then
					table.insert(projects, { title = title, indentation = indentation })
				end
			end
		end

		current_line = current_line - 1
	end

	local project_path = nil

	-- Build project path (most specific first, separated by dots)
	if #projects > 0 then
		-- Sort by indentation (most general first)
		table.sort(projects, function(a, b)
			return a.indentation < b.indentation
		end)

		local project_parts = {}
		for _, proj in ipairs(projects) do
			table.insert(project_parts, proj.title)
		end

		project_path = table.concat(project_parts, ".")
	end

	return project_path, area
end

---Extract task metadata from content
---@param content string The content to parse
---@param task Task The task to update
---@return Task task The updated task
local function extract_metadata(content, task)
	-- Extract content inside square brackets for UDAs and other fields
	for key, value in content:gmatch("%[([^:]+):%s*([^%]]+)%]") do
		key = key:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace
		value = value:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace

		-- Handle standard fields
		if key:lower() == "priority" then
			task.priority = value
		elseif key:lower() == "due" then
			task.due = DateUtils.parse_date(value)
		elseif key:lower() == "uuid" then
			task.uuid = value:gsub('"', "") -- Remove any quotes
		else
			-- Store as UDA
			task:set_uda(key, value)
		end
	end

	-- Extract ID from parentheses (ID: 123)
	local id = content:match("%(ID:%s*(%d+)%)")
	if id then
		task.id = tonumber(id)
	end

	-- Remove all metadata from description
	local description = content:gsub("%[([^:]+):%s*[^%]]+%]", ""):gsub("%(ID:%s*%d+%)", "")
	-- Clean up extra spaces
	description = description:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")

	-- Update task description if not empty
	if description ~= "" then
		task.description = description
	end

	return task
end

---Clean content by removing metadata and tags
---@param content string The content to clean
---@return string cleaned The cleaned content
local function clean_content(content)
	-- Remove all metadata
	local cleaned = content:gsub("%[([^:]+):%s*[^%]]+%]", "")
	-- Remove all IDs
	cleaned = cleaned:gsub("%(ID:%s*%d+%)", "")
	-- Remove all tags
	cleaned = cleaned:gsub(TAG_PATTERN, "")
	-- Trim and normalize spaces
	cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")

	return cleaned
end

---Extract continuation lines for a task and process metadata
---@param lines table All lines in the buffer
---@param line_num number The line number of the task
---@param task Task The task to update with metadata
---@return string description The full task description including continuation lines
---@return number continuation_count Number of continuation lines parsed
local function extract_continuation_lines(lines, line_num, task)
	local original_line = lines[line_num]
	local has_checkbox, _, content = extract_checkbox(original_line)

	if not has_checkbox then
		return "", 0
	end

	-- Clean the main task line
	local description = clean_content(content or "")
	local continuation_count = 0
	local current_line = line_num + 1

	-- Process any indented continuation lines
	while current_line <= #lines do
		local line = lines[current_line]

		-- If line starts with whitespace and doesn't have a checkbox, it's a continuation
		if line:match("^%s+%S") and not line:match("^%s*-%s+%[") then
			local continuation_text = line:gsub("^%s+", "")

			-- Extract metadata from continuation line
			task = extract_metadata(continuation_text, task)

			-- Add cleaned continuation text to description
			local cleaned_text = clean_content(continuation_text)
			if cleaned_text ~= "" then
				description = description .. " " .. cleaned_text
			end

			continuation_count = continuation_count + 1
			current_line = current_line + 1
		else
			break
		end
	end

	return description, continuation_count
end

---Build dependency tree based on indentation
---@param lines table All lines in the buffer
---@param tasks table List of detected tasks with their indentation levels
---@return table dependencies List of tasks with their dependencies set
local function build_dependency_tree(lines, tasks)
	-- Respect maximum dependency depth
	local depth = 0

	-- Sort tasks by line number
	table.sort(tasks, function(a, b)
		return a.line_num < b.line_num
	end)

	-- For each task, check if it has a parent (less indented task above it)
	for i = 2, #tasks do
		local current_task = tasks[i]
		local current_level = current_task.level

		-- Look backwards for potential parent tasks
		for j = i - 1, 1, -1 do
			local potential_parent = tasks[j]

			-- If we find a task with less indentation, it's our parent
			if potential_parent.level < current_level then
				-- The less indented task (potential_parent) depends on the more indented one (current_task)
				-- i.e., current_task blocks potential_parent
				if potential_parent.task.depends then
					potential_parent.task.depends = potential_parent.task.depends .. "," .. current_task.task.uuid
				else
					potential_parent.task.depends = current_task.task.uuid
				end

				depth = depth + 1
				if depth >= MAX_DEPENDENCY_DEPTH then
					break
				end

				break
			end
		end

		if depth >= MAX_DEPENDENCY_DEPTH then
			break
		end
	end

	-- Extract just the tasks from the data structure
	local result = {}
	for _, task_info in ipairs(tasks) do
		table.insert(result, task_info.task)
	end

	return result
end

---Get the indentation level of a line
---@param line string The line to check
---@return number level The indentation level
local function get_indentation_level(line)
	local spaces = line:match("^(%s*)")
	return #spaces
end

---Parse markdown buffer into Task objects
---@return Result<Task[]> result The parsed tasks or an error
local function parse_markdown()
	local buffer_id = BufferReader.get_current_buffer()
	local line_count = BufferReader.get_line_count(buffer_id)
	local lines = BufferReader.get_lines(buffer_id, 0, line_count)
	local current_line_num = BufferReader.get_current_line_number()

	-- If buffer is empty, return an empty list
	if #lines == 0 then
		return Result.Ok({})
	end

	-- If only concerned with current line
	if current_line_num then
		local line = lines[current_line_num]

		local task_line_num = current_line_num
		local has_checkbox, checked, content, checkbox_type = extract_checkbox(line)

		-- If current line doesn't have a checkbox, check if it's a continuation line
		if not has_checkbox and is_continuation_line(line) then
			-- Find the corresponding task line
			task_line_num = find_task_for_continuation(lines, current_line_num)

			-- If we found a task line, get its info
			if task_line_num then
				local task_line = lines[task_line_num]
				has_checkbox, checked, content, checkbox_type = extract_checkbox(task_line)
			end
		end

		-- If we don't have a checkbox (not a task line or continuation), return empty
		if not has_checkbox then
			return Result.Ok({})
		end

		-- Now continue with task creation using the found task_line_num
		local checkbox = checkbox_type and "[" .. checkbox_type .. "]" or "[ ]"

		-- Create task - note that Task.new returns a Result
		local task_result = Task.new({
			description = clean_content(content),
			type = "markdown",
			line = task_line_num, -- Use the task's actual line number, not cursor position
			checked = checked,
			status = Task.checkbox_to_status[checkbox] or "pending",
			tags = {},
			annotations = {},
			uda = {},
		})

		-- If task creation failed, return the error
		if task_result:is_err() then
			return task_result
		end

		-- Get the actual task from the result
		local task = task_result.value

		-- Extract tags from the main task line
		local tags = extract_tags(lines[task_line_num])
		for _, tag in ipairs(tags) do
			task:add_tag(tag)
		end

		-- Extract project from headers
		local project, area = extract_project(lines, task_line_num)
		if project then
			task.project = project
		end

		if area then
			task:set_uda("Area", area)
		end

		-- Extract metadata from the main task line
		task = extract_metadata(content, task)

		-- Process all continuation lines, starting from the task line
		-- This is important to ensure we process all continuations even if cursor is on one of them
		local description = clean_content(content)
		local continuation_count = 0

		-- Process all lines after the task line
		for i = task_line_num + 1, #lines do
			local cont_line = lines[i]

			-- If line starts with whitespace and doesn't have a checkbox, it's a continuation
			if is_continuation_line(cont_line) then
				local continuation_text = cont_line:gsub("^%s+", "")

				-- Extract metadata from continuation line
				task = extract_metadata(continuation_text, task)

				-- Add cleaned continuation text to description
				local cleaned_text = clean_content(continuation_text)
				if cleaned_text ~= "" then
					description = description .. " " .. cleaned_text
				end

				continuation_count = continuation_count + 1
			else
				break
			end
		end

		-- Set the full description and continuation count
		task.description = description
		task.continuation_lines = continuation_count

		-- If description is empty after all processing, use a default
		if task.description == "" then
			task.description = "New task"
		end

		-- Return the task
		return Result.Ok(task)
	end
	-- Parse all tasks in the buffer
	local tasks = {}
	local task_infos = {}

	for line_num, line in ipairs(lines) do
		local has_checkbox, checked, content, checkbox_type = extract_checkbox(line)

		if has_checkbox then
			local checkbox = checkbox_type and "[" .. checkbox_type .. "]" or "[ ]"

			-- Create task - note that Task.new returns a Result
			local task_result = Task.new({
				description = clean_content(content),
				type = "markdown",
				line = line_num,
				checked = checked,
				status = Task.checkbox_to_status[checkbox] or "pending",
				tags = {},
				annotations = {},
				uda = {},
			})

			-- Skip this task if creation failed
			if task_result:is_err() then
				goto continue
			end

			-- Get the actual task from the result
			local task = task_result.value

			-- Extract tags
			local tags = extract_tags(line)
			for _, tag in ipairs(tags) do
				task:add_tag(tag)
			end

			-- Extract project from headers
			local project = extract_project(lines, line_num)
			if project then
				task.project = project
			end

			-- Extract metadata and update description
			task = extract_metadata(content, task)

			-- Extract continuation lines
			local full_description, continuation_lines = extract_continuation_lines(lines, line_num, task)
			if full_description ~= "" then
				task.description = full_description
				task.continuation_lines = continuation_lines
			end

			-- If description is empty after all processing, use a default
			if task.description == "" then
				task.description = "New task"
			end

			-- Record indentation level for dependency calculation
			local indent_level = get_indentation_level(line)
			table.insert(task_infos, {
				level = indent_level,
				line_num = line_num,
				task = task,
			})

			table.insert(tasks, task)
		end

		::continue::
	end

	-- If we found indented tasks, process dependencies
	if #task_infos > 0 then
		tasks = build_dependency_tree(lines, task_infos)
	end

	return Result.Ok(tasks)
end

return parse_markdown
