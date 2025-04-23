if vim.g.loaded_taskwarrior then
	return
end
vim.g.loaded_taskwarrior = true

-- Set up user commands
vim.api.nvim_create_user_command("TaskCreate", function()
	require("taskwarrior.presentation.commands").create_task_with_prompt()
end, {})

vim.api.nvim_create_user_command("TaskCreateFromLine", function()
	require("taskwarrior.presentation.commands").create_task_from_current_line()
end, {})

vim.api.nvim_create_user_command("TaskCreateFromSelection", function()
	require("taskwarrior.presentation.commands").create_task_from_selection()
end, { range = true })
