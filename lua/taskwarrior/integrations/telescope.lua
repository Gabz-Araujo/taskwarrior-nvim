local M = {}
local api = require("taskwarrior.api")

function M.browse()
	local has_telescope, telescope = pcall(require, "telescope")
	if not has_telescope then
		api.notify("Telescope not found - please install nvim-telescope/telescope.nvim", vim.log.levels.ERROR)
		return
	end

	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values

	local tasks = api.get_tasks("status:pending")

	table.sort(tasks, function(a, b)
		return (a.urgency or 0) > (b.urgency or 0)
	end)

	local formatted_tasks = {}
	for _, task in ipairs(tasks) do
		local display = string.format("[%d] %s", task.id, task.description)
		if task.priority then
			display = display .. " (" .. task.priority .. ")"
		end
		if task.due then
			display = display .. " [Due: " .. task.due:sub(1, 10) .. "]"
		end
		if task.project then
			display = display .. " [" .. task.project .. "]"
		end

		table.insert(formatted_tasks, {
			display = display,
			task = task,
		})
	end

	pickers
		.new({}, {
			prompt_title = "Taskwarrior Tasks",
			finder = finders.new_table({
				results = formatted_tasks,
				entry_maker = function(entry)
					return {
						value = entry.task.id,
						display = entry.display,
						ordinal = entry.display,
						task = entry.task,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				-- Complete task
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						api.complete_task(selection.value)
					end
				end)

				map("i", "<C-p>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						require("taskwarrior").set_task_priority(selection.value)
					end
				end)

				map("i", "<C-d>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						require("taskwarrior").set_task_due_date(selection.value)
					end
				end)

				map("i", "<C-e>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						require("taskwarrior").edit_task(selection.value)
					end
				end)

				map("i", "<C-a>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						vim.ui.input({ prompt = "Add annotation: " }, function(input)
							if input and input ~= "" then
								api.add_annotation(selection.value, input)
							end
						end)
					end
				end)

				map("i", "<C-t>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						require("taskwarrior").start_pomodoro(selection.value)
					end
				end)

				map("i", "<C-h>", function()
					api.notify(
						"Controls:\n"
							.. "ENTER: Complete task\n"
							.. "C-p: Set priority\n"
							.. "C-d: Set due date\n"
							.. "C-a: Add annotation\n"
							.. "C-e: Edit task\n"
							.. "C-t: Start pomodoro\n"
					)
				end)
				return true
			end,
		})
		:find()
end

function M.register_extension()
	local has_telescope, telescope = pcall(require, "telescope")
	if not has_telescope then
		return
	end

	return telescope.register_extension({
		exports = {
			tasks = M.browse,
		},
	})
end

return M
