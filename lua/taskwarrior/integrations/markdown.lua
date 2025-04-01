local M = {}
local api = require("taskwarrior.api")
local parser = require("taskwarrior.parser")
local utils = require("taskwarrior.utils")

function M.create_checkbox()
	local buffer_id = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_lines(buffer_id, row - 1, row, false)[1]

	local indent = line:match("^%s*") or ""

	local new_line = indent .. "- [ ] "

	vim.api.nvim_buf_set_lines(buffer_id, row, row, false, { new_line })

	vim.api.nvim_win_set_cursor(0, { row + 1, #new_line })

	vim.cmd("startinsert!")
end

function M.toggle_checkbox()
	local buffer_id = vim.api.nvim_get_current_buf()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_lines(buffer_id, row - 1, row, false)[1]

	if not line:match("^%s*%- %[[x ]%]") then
		return
	end

	local task = parser.from_markdown(line, row)

	if task then
		local updated_line

		if task.checked then
			updated_line = line:gsub("^(%s*%- )%[x%]", "%1[ ]")
			vim.api.nvim_buf_set_lines(buffer_id, row - 1, row, false, { updated_line })

			if task.task_id then
				api.execute("task " .. task.task_id .. " start", true)

				utils.update_task_metadata_in_markdown(row, "Completed", nil)
			end
		else
			updated_line = line:gsub("^(%s*%- )%[ %]", "%1[x]")
			vim.api.nvim_buf_set_lines(buffer_id, row - 1, row, false, { updated_line })

			if task.task_id then
				api.complete_task(task.task_id)

				local today = os.date("%Y-%m-%d")
				utils.update_task_metadata_in_markdown(row, "Completed", today)
			end
		end
	end
end

function M.setup()
	vim.api.nvim_create_augroup("TaskwarriorMarkdown", { clear = true })

	vim.api.nvim_create_autocmd("FileType", {
		group = "TaskwarriorMarkdown",
		pattern = "markdown",
		callback = function()
			vim.keymap.set("n", "<leader>tc", function()
				require("taskwarrior.integrations.markdown").create_checkbox()
			end, { buffer = true, desc = "Create checkbox" })

			vim.keymap.set("n", "<leader>tx", function()
				require("taskwarrior.integrations.markdown").toggle_checkbox()
			end, { buffer = true, desc = "Toggle checkbox" })
		end,
	})

	M.setup_md_autocmds()
end

-- Set up task ID extmarks for markdown files
function M.setup_task_links(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Clear existing marks
	local ns = vim.api.nvim_create_namespace("taskwarrior_md_links")
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	-- Get buffer lines
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Look for task IDs
	for i, line in ipairs(lines) do
		-- Look for "(ID: NNN)" pattern
		local start_idx, task_id = line:match("()%(ID:%s*(%d+)%)")

		if start_idx and task_id then
			-- Create extmark for clickable link
			vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, start_idx - 1, {
				end_row = i - 1,
				end_col = start_idx + 5 + #task_id, -- Adjust for "(ID: " length
				hl_group = "SpecialComment",
				hl_mode = "combine",
				virt_text = { { " 🔗", "Comment" } },
				virt_text_pos = "inline",
				on_click = function()
					require("taskwarrior.ui.task_view").show_task(task_id)
				end,
			})
		end
	end
end

-- Add an autocmd to set up links when opening markdown files
function M.setup_md_autocmds()
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		pattern = "*.md",
		callback = function(ev)
			M.setup_task_links(ev.buf)
		end,
	})
end

return M
