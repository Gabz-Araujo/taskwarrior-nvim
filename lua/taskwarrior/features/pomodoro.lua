local M = {}
local api = require("taskwarrior.api")
local parser = require("taskwarrior.parser")

local function get_task_from_current_line()
	local task = parser.from_markdown()
	if task and task.task_id then
		return task
	end
	return nil
end

function M.start(task_id)
	if not task_id then
		local task = get_task_from_current_line()
		if task then
			task_id = task.task_id
		else
			api.notify("No task ID found", vim.log.levels.ERROR)
			return
		end
	end

	local task_data = api.get_task(task_id)
	if not task_data then
		api.notify("Failed to get task data", vim.log.levels.ERROR)
		return
	end

	local description = task_data.description

	local work_minutes = 25
	local break_minutes = 5

	vim.ui.input({ prompt = "Work duration (minutes): ", default = tostring(work_minutes) }, function(input)
		if input and input ~= "" then
			work_minutes = tonumber(input) or work_minutes
		end

		vim.ui.input({ prompt = "Break duration (minutes): ", default = tostring(break_minutes) }, function(input)
			if input and input ~= "" then
				break_minutes = tonumber(input) or break_minutes
			end

			M._run_pomodoro(task_id, description, work_minutes, break_minutes)
		end)
	end)
end

function M._run_pomodoro(task_id, description, work_minutes, break_minutes)
	local work_seconds = work_minutes * 60
	local break_seconds = break_minutes * 60

	local buf = vim.api.nvim_create_buf(false, true)

	local width = 60
	local height = 5
	local col = math.floor((vim.o.columns - width) / 2)
	local row = 1

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, false, opts)

	-- Set buffer content
	local function update_timer(remaining, is_work)
		local mins = math.floor(remaining / 60)
		local secs = remaining % 60
		local time_str = string.format("%02d:%02d", mins, secs)

		local status = is_work and "Work" or "Break"
		local lines = {
			"Task: " .. description,
			string.format("Status: %s - %s remaining", status, time_str),
			"",
			"Press 'q' to quit, 'p' to pause/resume",
		}

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end

	local timer = vim.loop.new_timer()
	local is_work = true
	local remaining = work_seconds
	local is_running = true

	local kopts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "q", function()
		timer:close()
		vim.api.nvim_win_close(win, true)
	end, kopts)

	vim.keymap.set("n", "p", function()
		is_running = not is_running
		local status = is_running and "resumed" or "paused"
		api.notify("Pomodoro " .. status)
	end, kopts)

	update_timer(remaining, is_work)

	timer:start(
		0,
		1000,
		vim.schedule_wrap(function()
			if is_running then
				remaining = remaining - 1

				if remaining <= 0 then
					if is_work then
						is_work = false
						remaining = break_seconds
						api.notify("Work session complete! Time for a break.", vim.log.levels.INFO)

						local annotate_cmd = string.format(
							'task %s annotate "Completed %d minute pomodoro session"',
							task_id,
							work_minutes
						)
						api.execute(annotate_cmd, true)
					else
						is_work = true
						remaining = work_seconds
						api.notify("Break complete! Back to work.", vim.log.levels.INFO)
					end
				end

				update_timer(remaining, is_work)
			end
		end)
	)
end

return M
