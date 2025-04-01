local M = {}
local api = require("taskwarrior.api")
local parser = require("taskwarrior.parser")
local utils = require("taskwarrior.utils")

function M.sync_document()
	local buffer_id = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)

	local tasks_updated = 0

	for i, line in ipairs(lines) do
		local is_checkbox = line:match("^%s*%- %[[x ]%]")
		if is_checkbox then
			local task_id = line:match("%(ID:%s*(%d+)%)")
			local is_checked = line:match("^%s*%- %[x%]")

			if task_id then
				local task_data = api.get_task(task_id)
				if task_data then
					local status = task_data.status

					if (status == "completed" and not is_checked) or (status == "pending" and is_checked) then
						if status == "completed" and not is_checked then
							local updated_line = line:gsub("^(%s*%- )%[%s*%]", "%1[x]")
							vim.api.nvim_buf_set_lines(buffer_id, i - 1, i, false, { updated_line })
							if not line:match("%[Completed:") then
								local completed_date = task_data["end"] and task_data["end"]:sub(1, 10)
									or os.date("%Y-%m-%d")
								utils.update_task_metadata_in_markdown(i, "Completed", completed_date)
							end
							tasks_updated = tasks_updated + 1
						end
					end
					if task_data.priority then
						local priority_in_markdown = line:match("%[Priority:%s*([HML])%]")
						if not priority_in_markdown or priority_in_markdown ~= task_data.priority then
							utils.update_task_metadata_in_markdown(i, "Priority", task_data.priority)
						end
					end

					if task_data.due then
						local due_date = task_data.due:sub(1, 10)
						local due_in_markdown = line:match("%[Due:%s*([%d%-]+)%]")
						if not due_in_markdown or due_in_markdown ~= due_date then
							utils.update_task_metadata_in_markdown(i, "Due", due_date)
						end
					end
				end
			end
		end
	end

	if tasks_updated > 0 then
		api.notify(string.format("Synced %d tasks", tasks_updated))
	end

	return tasks_updated
end

function M.bulk_create_tasks()
	local buffer_id = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)

	local tasks_created = 0
	local i = 1

	while i <= #lines do
		local line = lines[i]
		local is_checkbox = line:match("^%s*%- %[[x ]%]")

		if is_checkbox and not line:match("%(ID:%s*%d+%)") then
			local task = parser.from_markdown(line, i)

			if task then
				local task_id = api.create_task(task, {
					project = table.concat(task.project, "."),
				})

				if task_id then
					utils.add_task_id_to_markdown(i, task_id)
					tasks_created = tasks_created + 1

					if task.continuation_lines and task.continuation_lines > 0 then
						i = i + task.continuation_lines
					end
				end
			end
		end

		i = i + 1
	end

	if tasks_created > 0 then
		api.notify(string.format("Created %d tasks", tasks_created))
	end

	return tasks_created
end

function M.import_tasks(filter)
	filter = filter or "status:pending"

	local buffer_id = vim.api.nvim_get_current_buf()
	local tasks = api.get_tasks(filter)

	local new_lines = {}
	table.insert(new_lines, "")
	table.insert(new_lines, "## Imported Tasks")
	table.insert(new_lines, "")

	for _, task in ipairs(tasks) do
		local checkbox = "- [ ]"
		if task.status == "completed" then
			checkbox = "- [x]"
		end

		local metadata = ""
		if task.priority then
			metadata = metadata .. " [Priority: " .. task.priority .. "]"
		end
		if task.due then
			metadata = metadata .. " [Due: " .. task.due:sub(1, 10) .. "]"
		end

		local task_line = string.format("%s %s%s (ID: %d)", checkbox, task.description, metadata, task.id)
		table.insert(new_lines, task_line)
	end

	local line_count = vim.api.nvim_buf_line_count(buffer_id)
	vim.api.nvim_buf_set_lines(buffer_id, line_count, line_count, false, new_lines)

	api.notify(string.format("Imported %d tasks", #tasks))

	return #tasks
end

return M
