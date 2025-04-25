--- @module taskwarrior.application.commands.create_task

local Task = require("taskwarrior.domain.entities.task")
local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")
local Logger = require("taskwarrior.utils.logger")
local Constants = require("taskwarrior.domain.constants")

--- @class CreateTaskCommand
---@field task_service TaskService
local M = {}

--- Constructor
---@param task_service TaskService
---@return CreateTaskCommand
function M.new(task_service)
	local self = {
		task_service = task_service,
	}
	setmetatable(self, { __index = M })
	return self
end

--- Execute the create task command with provided task data
--- @param task_data table Task properties (description, status, priority, etc.)
--- @return Result<Task, Error> Result containing the created task or an error
function M:execute(task_data)
	if not task_data.description or task_data.description == "" then
		return Result.Err(Error.validation_error("Task description is required"))
	end

	task_data.status = task_data.status or Constants.TASK_STATUS.PENDING

	local task_result = Task.new(task_data)

	if not task_result:is_ok() then
		return Result.Err(Error.validation_error(task_result.error or "Failed to create task entity"))
	end

	local task = task_result.value
	local result = self.task_service:create_task(task)

	return result
end

--- Create a task from a plain text description
--- @param description string Task description text
--- @param options? table Additional options (tags, priority, project, due)
--- @return Result<Task, Error> Result containing the created task or an error
function M:execute_with_description(description, options)
	options = options or {}

	local task_data = {
		description = description,
		epriority = options.priority,
		tags = options.tags,
		project = options.project,
		due = options.due,
		status = options.status,
	}

	return self:execute(task_data)
end

--- Create a task from a markdown checklist item
--- @param markdown_line string Markdown line with checkbox
--- @param options? table Additional options (line_number, buffer_id)
--- @return Result<Task, Error> Result containing the created task or an error
function M:execute_from_markdown(markdown_line, options)
	options = options or {}
	local line_num = options.line_number

	local parse_markdown_task = require("taskwarrior.infrastructure.parsers.markdown_parser")

	local result = parse_markdown_task()

	local task_result

	if result:is_err() then
		local internal_error_msg = "Internal parser error: " .. tostring(result.error)
		Logger.error(internal_error_msg)
		return Result.Err(Error.parser_error(internal_error_msg, markdown_line, line_num))
	else
		task_result = result
	end

	local task_data = task_result.value

	if task_data == nil then
		return Result.Err(Error.parser_error("Line is not a valid markdown task", markdown_line, line_num))
	end

	if type(task_data) ~= "table" then
		return Result.Err(Error.parser_error("Parsed task data is not a table", markdown_line, line_num))
	end

	task_data.type = task_data.type or "markdown"
	task_data.line = task_data.line or line_num

	Logger.error(vim.inspect(task_data))

	return self:execute(task_data)
end

--- Create a task from the current line in the buffer
--- @return Result<Task, Error> Result containing the created task or an error
function M:execute_from_current_line()
	local BufferReader = require("taskwarrior.infrastructure.io.buffer_reader")

	local current_line = BufferReader.get_current_line()
	local line_number = BufferReader.get_current_line_number()
	local buffer_id = BufferReader.get_current_buffer()

	if current_line:match("^%s*%-%s*%[") then
		return self:execute_from_markdown(current_line, {
			line_number = line_number,
			buffer_id = buffer_id,
		})
	else
		return self:execute_with_description(current_line:gsub("^%s*%-%s*", ""))
	end
end

--- Create a task from visual selection
--- @return Result<Task, Error> Result containing the created task or an error
function M:execute_from_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line = start_pos[2]
	local end_line = end_pos[2]
	local buffer_id = vim.api.nvim_get_current_buf()

	if start_line == end_line then
		return self:execute_from_current_line()
	end

	local lines = vim.api.nvim_buf_get_lines(buffer_id, start_line - 1, end_line, false)
	local text = table.concat(lines, " ")

	if lines[1]:match("^%s*%-%s*%[") then
		local parse_markdown_task = require("taskwarrior.infrastructure.parsers.markdown_parser")
		local task_result = parse_markdown_task()

		if task_result and (not task_result.is_ok or (task_result.is_ok and task_result.value)) then
			local task_data
			if task_result.is_ok and task_result.value then
				task_data = task_result.value
			elseif not task_result.is_ok then
				return self:execute_with_description(text:gsub("^%s*%-%s*%[.%]%s*", ""))
			else
				return self:execute_with_description(text:gsub("^%s*%-%s*%[.%]%s*", ""))
			end

			if type(task_data) ~= "table" then
				return self:execute_with_description(text:gsub("^%s*%-%s*%[.%]%s*", ""))
			end

			task_data.description = (task_data.description or "") .. " " .. table.concat(lines, " ", 2)

			return self:execute(task_data)
		end

		if not task_result then
			return Result.Err("No task result")
		end

		if task_result:is_ok() then
			local task_data = task_result.value
			task_data.description = task_data.description .. " " .. table.concat(lines, " ", 2)

			return self:execute(task_data)
		end
	end

	return self:execute_with_description(text:gsub("^%s*%-%s*%[.%]%s*", ""))
end

return M
