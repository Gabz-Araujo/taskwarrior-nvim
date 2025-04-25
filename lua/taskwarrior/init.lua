local M = {}

--- Set up the plugin with optional user config
--- @param opts table|nil User config table
function M.setup(opts)
	-- Load and merge configuration
	local config = require("taskwarrior.application.config")
	local config_result = config.setup(opts)

	-- Set up keymaps
	require("taskwarrior.presentation.keymaps").setup()

	-- Initialize dependencies
	local TaskwarriorAdapter = require("taskwarrior.infrastructure.adapters.taskwarrior_adapter")
	local TaskRepositoryImplementation =
		require("taskwarrior.infrastructure.repositories.task_repository_implementation")
	local TaskService = require("taskwarrior.domain.services.task_service")
	local CreateTaskCommand = require("taskwarrior.application.commands.create_task")

	-- 1. Create the adapter
	local adapter = TaskwarriorAdapter.new()

	-- 2. Create the Task Repository Implementation, injecting the adapter
	local task_repository = TaskRepositoryImplementation.new(adapter)

	-- 3. Create the Task Service, injecting the repository
	local task_service = TaskService.new(task_repository)

	-- 4. Create the CreateTask command, injecting the service
	local create_task_command = CreateTaskCommand.new(task_service)

	-- Set the create task command to the commands module
	local commands = require("taskwarrior.presentation.commands")
	commands.set_create_task_command(create_task_command)
end

--- Create a task with the given properties
--- @param task_data table Task properties
--- @return table|nil task The created task or nil on failure
--- @return string|nil error Error message on failure
function M.create_task(task_data)
	local commands = require("taskwarrior.presentation.commands")
	local result = commands.create_task(task_data)

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
	local commands = require("taskwarrior.presentation.commands")
	local result = commands.create_task_from_description(description, options)

	if result:is_ok() then
		return result.value, nil
	else
		return nil, result.error.message
	end
end

--- Expose commands module for direct access
M.commands = require("taskwarrior.presentation.commands")

return M
