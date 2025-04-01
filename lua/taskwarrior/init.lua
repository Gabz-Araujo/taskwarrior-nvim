local M = {}

-- Default configuration
local defaults = {
	tags = { "TODO", "HACK", "NOTE", "PERF", "TEST", "WARN" },
	keymaps = {
		dashboard = "<leader>tkb",
		browse = "<leader>tkt",
		create_from_comment = "<leader>tkk",
		create_from_markdown = "<leader>tki",
		mark_done = "<leader>tkd",
		goto_task = "<leader>tkg",
		priority = "<leader>tkp",
		due_date = "<leader>tku",
		sync = "<leader>tks",
		pomodoro = "<leader>tkm",
		calendar = "<leader>tkc",
		project = "<leader>tkj",
		recurring = "<leader>tkr",
		edit_task = "<leader>tke",
	},
	auto_sync = false,
	default_priority = "M",
	default_tags = {},
	statusline = {
		enabled = true,
		format = "Tasks: %count% (%urgent% urgent)",
	},
	integrations = {
		telescope = true,
		markdown = true,
	},
	max_line_length = 28,
}

-- Global configuration
M.config = {}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", defaults, opts or {})

	local api = require("taskwarrior.api")
	api.setup(M.config)

	require("taskwarrior.features.commands").setup(M.config)

	if not M.config.disable_keymaps then
		require("taskwarrior.utils").setup_keymaps(M.config)
	end

	if M.config.auto_sync then
		vim.api.nvim_create_autocmd({ "BufWritePre" }, {
			pattern = { "*.md" },
			callback = function()
				require("taskwarrior.features.sync").sync_document()
			end,
		})
	end

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function()
			vim.opt_local.conceallevel = 2
			vim.opt_local.concealcursor = "nc"

			vim.cmd([[
                    syntax match markdownUuidConceal "\](ID:[^)]*)" contains=markdownUuidConcealed
                    syntax match markdownUuidConcealed contained "\](ID:[^)]*)" conceal
                ]])
		end,
		group = vim.api.nvim_create_augroup("TaskConceal", { clear = true }),
	})

	return M
end

-- Public API exports
M.create_task_from_comment = function()
	return require("taskwarrior.features.commands").create_task_from_comment()
end

M.create_task_from_markdown = function()
	return require("taskwarrior.features.commands").create_task_from_markdown()
end

M.complete_task = function()
	return require("taskwarrior.features.commands").mark_task_as_done()
end

M.go_to_task_tui = function()
	return require("taskwarrior.features.commands").go_to_task_tui()
end

-- Feature functions
M.open_dashboard = function()
	return require("taskwarrior.ui.dashboard").open()
end

M.browse_tasks = function()
	return require("taskwarrior.integrations.telescope").browse()
end

M.set_task_priority = function(task_id)
	return require("taskwarrior.features.commands").set_task_priority(task_id)
end

M.set_task_due_date = function(task_id)
	return require("taskwarrior.features.commands").set_task_due_date(task_id)
end

M.sync_document = function()
	return require("taskwarrior.features.sync").sync_document()
end

M.start_pomodoro = function(task_id)
	return require("taskwarrior.features.pomodoro").start(task_id)
end

M.show_calendar = function()
	return require("taskwarrior.ui.calendar").open()
end

M.show_project_summary = function()
	return require("taskwarrior.ui.project").open()
end

M.set_task_recurrence = function(task_id)
	return require("taskwarrior.features.commands").set_task_recurrence(task_id)
end

M.edit_task = function(task_id)
	return require("taskwarrior.features.editor").edit_task(task_id)
end

M.show_task = function(task_id)
	return require("taskwarrior.ui.task_view").show_task(task_id)
end

return M
