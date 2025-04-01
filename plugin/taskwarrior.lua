if vim.g.loaded_taskwarrior then
	return
end
vim.g.loaded_taskwarrior = true

-- Define user commands
vim.api.nvim_create_user_command("TaskDashboard", function()
	require("taskwarrior").open_dashboard()
end, {})

vim.api.nvim_create_user_command("TaskBrowse", function()
	require("taskwarrior").browse_tasks()
end, {})

vim.api.nvim_create_user_command("TaskCreate", function()
	require("taskwarrior").create_task_from_markdown()
end, {})

vim.api.nvim_create_user_command("TaskCreateFromComment", function()
	require("taskwarrior").create_task_from_comment()
end, {})

vim.api.nvim_create_user_command("TaskComplete", function()
	require("taskwarrior").complete_task()
end, {})

vim.api.nvim_create_user_command("TaskSync", function()
	require("taskwarrior").sync_document()
end, {})

vim.api.nvim_create_user_command("TaskCalendar", function()
	require("taskwarrior").show_calendar()
end, {})

vim.api.nvim_create_user_command("TaskProject", function()
	require("taskwarrior").show_project_summary()
end, {})

vim.api.nvim_create_user_command("TaskPomodoro", function()
	require("taskwarrior").start_pomodoro()
end, {})

vim.api.nvim_create_user_command("TaskImport", function(opts)
	require("taskwarrior.features.sync").import_tasks(opts.args)
end, {
	nargs = "?",
	desc = "Import tasks from Taskwarrior into the current buffer",
})

vim.api.nvim_create_user_command("TaskBulkCreate", function()
	require("taskwarrior.features.sync").bulk_create_tasks()
end, {
	nargs = "?",
	desc = "Create tasks for all the checkboxes on the doc",
})

vim.api.nvim_create_user_command("TaskSetPriority", function()
	require("taskwarrior").set_task_priority()
end, {})

vim.api.nvim_create_user_command("TaskSetDue", function()
	require("taskwarrior").set_task_due_date()
end, {})

vim.api.nvim_create_user_command("TaskRecurring", function()
	require("taskwarrior.features.commands").set_task_recurrence()
end, {})

vim.api.nvim_create_user_command("TaskAnnotate", function()
	require("taskwarrior.features.commands").add_annotation()
end, {})

vim.api.nvim_create_user_command("TaskEdit", function()
	require("taskwarrior.features.editor").edit_task()
end, {})

-- Add command to directly view a task by ID
vim.api.nvim_create_user_command("TaskView", function(opts)
	local task_id = opts.args
	if task_id and task_id ~= "" then
		require("taskwarrior.ui.task_view").show_task(task_id)
	else
		vim.notify("Please provide a task ID", vim.log.levels.ERROR)
	end
end, {
	nargs = 1,
	desc = "View task details by ID",
	complete = function(arg_lead, cmdline, cursor_pos)
		-- Optionally add completion for task IDs
		local tasks = require("taskwarrior.api").get_tasks("status:pending")
		local ids = {}
		for _, task in ipairs(tasks) do
			table.insert(ids, tostring(task.id))
		end

		-- Filter based on what the user has typed
		local filtered = {}
		for _, id in ipairs(ids) do
			if id:find(arg_lead, 1, true) == 1 then
				table.insert(filtered, id)
			end
		end

		return filtered
	end,
})
