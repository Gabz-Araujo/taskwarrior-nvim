local M = {}
local api = require("taskwarrior.api")

function M.open()
	local buf = vim.api.nvim_create_buf(false, true)

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	local due_tasks = api.get_tasks("status:pending due.any:")

	local current_date = os.date("*t")
	local first_day = os.time({ year = current_date.year, month = current_date.month, day = 1 })
	local first_wday = os.date("*t", first_day).wday
	local days_in_month =
		os.date("*t", os.time({ year = current_date.year, month = current_date.month + 1, day = 0 })).day

	local tasks_by_date = {}
	for _, task in ipairs(due_tasks) do
		if task.due then
			local due_date = task.due:sub(1, 10)
			if not tasks_by_date[due_date] then
				tasks_by_date[due_date] = {}
			end
			table.insert(tasks_by_date[due_date], task)
		end
	end

	-- Build calendar header
	local content = {
		"# Tasks Calendar - " .. os.date("%B %Y"),
		"",
		"Sun   Mon   Tue   Wed   Thu   Fri   Sat",
		"---   ---   ---   ---   ---   ---   ---",
	}

	-- Build calendar grid
	local calendar_row = "    "
	for i = 1, first_wday - 1 do
		calendar_row = calendar_row .. "      "
	end

	for day = 1, days_in_month do
		local date_str = string.format("%04d-%02d-%02d", current_date.year, current_date.month, day)
		local highlight = day == current_date.day and "*" or " "

		local day_str
		if tasks_by_date[date_str] then
			day_str = string.format("%s%2d%s ", highlight, day, highlight)
		else
			day_str = string.format(" %2d  ", day)
		end

		calendar_row = calendar_row .. day_str

		if (day + first_wday - 1) % 7 == 0 or day == days_in_month then
			table.insert(content, calendar_row)
			calendar_row = "    "
		end
	end

	table.insert(content, "")
	table.insert(content, "## Tasks with Due Dates")

	local dates = {}
	for date in pairs(tasks_by_date) do
		table.insert(dates, date)
	end
	table.sort(dates)

	for _, date in ipairs(dates) do
		table.insert(content, "")
		table.insert(content, "### " .. date)
		for _, task in ipairs(tasks_by_date[date]) do
			local priority = task.priority and " (" .. task.priority .. ")" or ""
			table.insert(content, string.format("- [%d] %s%s", task.id, task.description, priority))
		end
	end

	table.insert(content, "")
	table.insert(content, "## Controls")
	table.insert(content, "- Press 'q' to close")
	table.insert(content, "- Press 'd' on a task line to mark as done")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	local kopts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, kopts)
	vim.keymap.set("n", "d", function()
		local line = vim.api.nvim_get_current_line()
		local task_id = line:match("%[(%d+)%]")
		if task_id then
			api.complete_task(task_id)
			M.open() -- Refresh the calendar
		end
	end, kopts)

	return buf, win
end

return M
