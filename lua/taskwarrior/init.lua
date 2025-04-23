local M = {}

--- Set up the plugin with optional user config
--- @param opts table|nil User config table
function M.setup(opts)
	-- Load and merge configuration
	local config = require("taskwarrior.application.config")
	local config_result = config.setup(opts)

	-- Load and merge configuration
	local config = require("taskwarrior.application.config")
	config.setup(opts)

	-- Set up keymaps
	require("taskwarrior.presentation.keymaps").setup()
end

--- Create a task with the given properties
--- @param task_data table Task properties
--- @return table|nil task The created task or nil on failure
--- @return string|nil error Error message on failure
function M.create_task(task_data)
	local CreateTask = require("taskwarrior.application.commands.create_task")
	local result = CreateTask.execute(task_data)

	if result:is_ok() then
		return result.value, nil
	else
		return nil, result.error.message
	end
end

--- Create a task from description text
--- @param description string Task description
--- @param options table|nil Additional options (tags, priority, etc.)
--- @return table|nil task The created task or nil on failure
--- @return string|nil error Error message on failure
function M.create_task_from_description(description, options)
	local CreateTask = require("taskwarrior.application.commands.create_task")
	local result = CreateTask.execute_with_description(description, options)

	if result:is_ok() then
		return result.value, nil
	else
		return nil, result.error.message
	end
end

--- Expose commands module for direct access
M.commands = require("taskwarrior.presentation.commands")

return M
