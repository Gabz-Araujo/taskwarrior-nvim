local GetTasks = require("taskwarrior.application.queries.get_tasks")

local M = {}

function M.open()
	-- Create a new buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	-- Set buffer content
	local result = GetTasks.execute("status:pending")
	if result:is_err() then
		vim.notify("Failed to fetch tasks: " .. result.error.message, vim.log.levels.ERROR)
		return
	end

	local lines = { "# Taskwarrior Dashboard", "" }

	-- Add tasks to lines
	for _, task in ipairs(result.value) do
		table.insert(lines, "- " .. task:get_checkbox() .. " " .. task.description)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Open the buffer in a new window
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = 80,
		height = 40,
		row = 10,
		col = 10,
		style = "minimal",
		border = "rounded",
	})

	-- Set keymaps for the dashboard
	-- ... implementation ...
end

return M
