local M = {}
local config = require("taskwarrior.config").get()

function M.from_markdown(line, line_number)
	line = line or vim.api.nvim_get_current_line()
	line_number = line_number or vim.fn.line(".")

	if not line:match("^%s*%- %[[x ]%]") then
		return nil
	end

	local buffer_id = vim.api.nvim_get_current_buf()
	local total_lines = vim.api.nvim_buf_line_count(buffer_id)

	local task_text = line:gsub("^%s*%- %[[x ]%]%s*", ""):gsub("%s*#%w+", "")

	local next_line_num = line_number
	local indent_level = line:match("^(%s*)")
	local continuation_indent = indent_level .. "  " -- Expected indent for continuation

	local continued_text = {}
	local continuation_count = 0

	while next_line_num < total_lines do
		next_line_num = next_line_num + 1
		local next_line = vim.api.nvim_buf_get_lines(buffer_id, next_line_num - 1, next_line_num, false)[1]

		-- Check if it's a continuation line (indented and not a new checkbox)
		if next_line:match("^" .. continuation_indent) and not next_line:match("^%s*%- %[") then
			local line_text = next_line:gsub("^%s+", ""):gsub("%s*#%w+", "")
			table.insert(continued_text, line_text)
			continuation_count = continuation_count + 1
		else
			break
		end
	end

	if #continued_text > 0 then
		task_text = task_text .. " " .. table.concat(continued_text, " ")
	end

	task_text = vim.fn.trim(task_text)

	-- Extract tags from all lines
	local tags = {}
	for tag in line:gmatch("#(%w+)") do
		table.insert(tags, tag)
	end

	for i = 1, continuation_count do
		local cont_line = vim.api.nvim_buf_get_lines(buffer_id, line_number + i - 1, line_number + i, false)[1]
		for tag in cont_line:gmatch("#(%w+)") do
			table.insert(tags, tag)
		end
	end

	local headings = {}
	for i = line_number - 1, 0, -1 do
		local heading_line = vim.api.nvim_buf_get_lines(buffer_id, i, i + 1, false)[1]
		if heading_line:match("^%s*#") then
			local heading_text = heading_line:gsub("^%s*#%s*", "")
			table.insert(headings, 1, heading_text)
		end
	end

	local task_id, priority, due_date, recurrence

	task_id = line:match("%(ID:%s*([%x%-]+)%)")
	priority = line:match("%[Priority:%s*([HML])%]")
	due_date = line:match("%[Due:%s*([%d%-]+)%]")
	recurrence = line:match("%[Recur:%s*([^%]]+)%]")

	for i = 1, continuation_count do
		local cont_line = vim.api.nvim_buf_get_lines(buffer_id, line_number + i - 1, line_number + i, false)[1]

		if not task_id then
			task_id = cont_line:match("%(ID:%s*([%x%-]+)%)")
		end

		if not priority then
			priority = cont_line:match("%[Priority:%s*([HML])%]")
		end

		if not due_date then
			due_date = cont_line:match("%[Due:%s*([%d%-]+)%]")
		end

		if not recurrence then
			recurrence = cont_line:match("%[Recur:%s*([^%]]+)%]")
		end
	end

	return {
		description = task_text,
		tags = tags,
		project = headings,
		task_id = task_id,
		priority = priority,
		due = due_date,
		recur = recurrence,
		type = "markdown",
		line = line_number,
		checked = line:match("^%s*%- %[x%]") ~= nil,
		continuation_lines = continuation_count, -- Track number of continuation lines
	}
end

-- Parse task from a TODO-style comment
function M.from_comment(line, line_number)
	line = line or vim.api.nvim_get_current_line()
	line_number = line_number or vim.fn.line(".")

	local buffer_id = vim.api.nvim_get_current_buf()
	local total_lines = vim.api.nvim_buf_line_count(buffer_id)

	for _, tag in ipairs(config.tags) do
		local start_index, end_index = string.find(line, tag)
		if start_index then
			local task_description = string.sub(line, end_index + 2)
			task_description = string.gsub(task_description, "%((.-%))", "")
			task_description = string.gsub(task_description, "- ", "")
			task_description = vim.fn.trim(task_description)

			local comment_style
			if line:match("^%s*//") then
				comment_style = "//"
			elseif line:match("^%s*#") then
				comment_style = "#"
			elseif line:match("^%s*%-%-") then
				comment_style = "--"
			elseif line:match("^%s*%%") then
				comment_style = "%%"
			elseif line:match("^%s*/%*") then
				comment_style = "/*"
			else
				comment_style = "//"
			end

			local continued_text = {}
			local next_line_num = line_number

			while next_line_num < total_lines do
				next_line_num = next_line_num + 1
				local next_line = vim.api.nvim_buf_get_lines(buffer_id, next_line_num - 1, next_line_num, false)[1]

				local is_comment = next_line:match("^%s*" .. comment_style:gsub("%p", "%%%1"))
				local has_tag = false
				for _, t in ipairs(config.tags) do
					if next_line:match(t) then
						has_tag = true
						break
					end
				end

				if is_comment and not has_tag then
					local line_text = next_line:gsub("^%s*" .. comment_style:gsub("%p", "%%%1") .. "%s*", "")
					table.insert(continued_text, line_text)
				else
					break
				end
			end

			if #continued_text > 0 then
				task_description = task_description .. " " .. table.concat(continued_text, " ")
			end

			return {
				description = task_description,
				tag = string.lower(tag),
				type = "comment",
				line = line_number,
			}
		end
	end
	return nil
end

function M.from_current_line()
	local line = vim.api.nvim_get_current_line()
	local line_number = vim.fn.line(".")

	local task = M.from_markdown(line, line_number)
	if task then
		return task
	end

	return M.from_comment(line)
end

return M
