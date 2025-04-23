--- Taskwarrior markdown parser
--- @module taskwarrior.infrastructure.parsers.markdown_parser

local Task = require("taskwarrior.domain.entities.task")
local BufferReader = require("taskwarrior.infrastructure.io.buffer_reader")
local Result = require("taskwarrior.utils.result")
local Logger = require("taskwarrior.utils.logger")
local Error = require("taskwarrior.utils.error")

--- Parse a markdown task line
--- @param line string? Optional line text (defaults to current line)
--- @param line_number integer? Optional line number (defaults to current line)
--- @param buffer_id integer? Optional buffer ID (defaults to current buffer)
--- @return Task|nil Parsed task or nil if not a task
local function parse_markdown_task(line, line_number, buffer_id)
	line = line or BufferReader.get_current_line()
	line_number = line_number or BufferReader.get_current_line_number()
	buffer_id = buffer_id or BufferReader.get_current_buffer()

	local total_lines = BufferReader.get_line_count(buffer_id)

	-- Traverse backward to find the first line of the task
	while line_number > 1 do
		local prev_line = BufferReader.get_line(buffer_id, line_number - 1)
		if not prev_line then
			break
		end
		if not prev_line:match("^%s*%- (%[[ xuc!r%-]%])") then
			break
		end
		line_number = line_number - 1
		line = prev_line
	end

	-- Check if the line is a markdown checkbox
	local checkbox = line:match("^%s*%- (%[[ xuc!r%-]%])")
	if not checkbox then
		return Result.Ok(nil) -- Not a task line, which is OK
	end

	-- Determine the task status from the checkbox
	local status = Task.checkbox_to_status[checkbox] or "pending"

	local function get_task_description(task_line)
		return task_line
			:gsub("^%s*%- %[[xuc!r%-]%]%s*", "") -- Remove task marker
			:gsub("%s*#%w+", "") -- Remove hashtags
			:gsub("^%s*[%(%{%[].-[%)%}%]]%s*", "") -- Remove metadata if it starts with (, {, or [
			:gsub("[%(%{%[].-[%)%}%]]", "") -- Remove any remaining metadata enclosed in (), {}, or []
			:gsub("#%w+", "") -- Remove any remaining tags starting with #
			:gsub("^%s+", "") -- Trim leading whitespace
			:gsub("%s+$", "") -- Trim trailing whitespace
	end

	-- Extract the task description
	local task_text = get_task_description(line)

	-- Check for continuation lines
	local next_line_num = line_number
	local continued_text = {}
	local continuation_count = 0

	-- Process any continuation lines
	while next_line_num < total_lines do
		next_line_num = next_line_num + 1
		local next_line = BufferReader.get_line(buffer_id, next_line_num)

		-- Skip new tasks
		if next_line:match("^%s*%- (%[[ xuc!r%-]%])") then
			break
		end

		-- Treat as a continuation line
		local line_text = get_task_description(next_line)
		table.insert(continued_text, line_text)
		continuation_count = continuation_count + 1
	end

	-- Combine task text with continuation lines
	if #continued_text > 0 then
		task_text = task_text .. " " .. table.concat(continued_text, " ")
	end

	task_text = task_text:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace

	-- Create a new task
	local task, err = Task.new({
		description = task_text,
		type = "markdown",
		line = line_number,
		checked = status == "done",
		continuation_lines = continuation_count,
		status = status,
		tags = {},
	})

	if not task then
		return Result.Err(Error.parser_error("Failed to create task: " .. (err or "unknown error"), line, line_number))
	end

	-- Extract tags from all lines
	for tag in line:gmatch("#(%w+)") do
		task:add_tag(tag)
	end

	for i = 1, continuation_count do
		local cont_line = BufferReader.get_line(buffer_id, line_number + i)
		for tag in cont_line:gmatch("#(%w+)") do
			task:add_tag(tag)
		end
	end

	-- Extract project and area from headings
	local headings = {}
	local area = nil
	for i = line_number - 1, 0, -1 do
		local heading_line = BufferReader.get_line(buffer_id, i + 1) -- +1 because BufferReader is 1-indexed
		if not heading_line then
			break
		end
		if heading_line:match("^%s*#") then
			local heading_text = heading_line:gsub("^%s*#+%s*", "")
			local heading_level = #heading_line:match("^%s*(#+)")

			if heading_level == 1 then
				-- Level 1 heading is the Area
				area = heading_text
			else
				-- Level 2+ headings are part of the Project
				table.insert(headings, 1, heading_text)
			end
		end
	end

	if area then
		task:set_uda("Area", area)
	end

	if #headings > 0 then
		task.project = table.concat(headings, ".")
	end

	return Result.Ok(task)
end

return parse_markdown_task
