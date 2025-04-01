local M = {}

function M.check()
	local health = vim.health or require("health")

	health.report_start("Taskwarrior.nvim")

	local task_exists = vim.fn.executable("task") == 1
	if task_exists then
		health.report_ok("Taskwarrior is installed")

		local version_output = vim.fn.system("task --version")
		local version = version_output:match("(%d+%.%d+%.%d+)")
		if version then
			health.report_ok("Taskwarrior version: " .. version)
		else
			health.report_warn("Could not determine Taskwarrior version")
		end
	else
		health.report_error("Taskwarrior not found. Please install taskwarrior")
	end

	local has_plenary, _ = pcall(require, "plenary")
	if has_plenary then
		health.report_ok("Plenary.nvim is installed")
	else
		health.report_warn("Plenary.nvim not found. Some features may not work properly.")
	end

	local has_telescope, _ = pcall(require, "telescope")
	if has_telescope then
		health.report_ok("Telescope.nvim is installed")
	else
		health.report_warn("Telescope.nvim not found. Task browsing will be limited.")
	end

	local has_config = pcall(require, "taskwarrior.config")
	if has_config then
		health.report_ok("Configuration loaded successfully")
	else
		health.report_error("Could not load configuration")
	end

	health.report_info("Tips:")
	health.report_info("- Use :TaskDashboard to open the dashboard")
	health.report_info("- Use :TaskBrowse to browse tasks")
	health.report_info("- Use :TaskSync to sync markdown documents with Taskwarrior")
end

return M
