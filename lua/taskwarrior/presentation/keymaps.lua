local Commands = require("taskwarrior.presentation.commands")
local Config = require("taskwarrior.application.config")

local M = {}

function M.setup()
	local config = Config.get()

	if not config.keymaps or not config.keymaps.enabled then
		vim.notify("Taskwarrior: Keymaps are disabled in config.", vim.log.levels.INFO, { title = "Taskwarrior" })
		return
	end

	local options = { noremap = true, silent = true }

	-- Helper function to set keymaps safely
	local function set_keymap(mode, binding, command)
		if binding and type(binding) == "string" and #binding > 0 then
			vim.keymap.set(mode, binding, command, options)
		end
	end

	-- Create task from current line
	set_keymap("n", config.keymaps.create_task, function()
		Commands.create_task_from_current_line()
	end)

	-- Create task from visual selection
	set_keymap("v", config.keymaps.create_task_visual, function()
		Commands.create_task_from_selection()
	end)

	-- Create task with prompt
	set_keymap("n", config.keymaps.create_task_prompt, function()
		Commands.create_task_with_prompt()
	end)
end

return M
