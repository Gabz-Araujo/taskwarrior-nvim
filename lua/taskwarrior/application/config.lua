--- Configuration module for Taskwarrior.nvim
--- @module taskwarrior.config

local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")
local Logger = require("taskwarrior.utils.logger")

local M = {}

-- Default configuration
local default_config = {
	keymaps = {
		enabled = true, -- Or false to disable keymaps

		create_task = "<leader>tc", -- Keybinding for creating a task from the current line
		create_task_visual = "<leader>tv", -- Keybinding for creating a task from a visual selection
		create_task_prompt = "<leader>tp", -- Keybinding for creating a task with a prompt
	},

	-- Taskwarrior settings
	taskwarrior = {
		executable = "task", -- Path to taskwarrior executable
		data_location = nil, -- Taskwarrior data location (nil = use default)
		config_location = nil, -- Taskwarrior config location (nil = use default)
	},

	-- Markdown settings
	markdown = {
		checkbox_mapping = {
			["[ ]"] = "pending",
			["[x]"] = "done",
			["[c]"] = "canceled",
			["[-]"] = "on-hold",
			["[u]"] = "undone",
			["[r]"] = "recurring",
			["[!]"] = "important",
		},
		file_pattern = "*.md", -- Files to treat as task files
		auto_sync = true, -- Auto-sync when saving files
	},

	-- UI settings
	ui = {
		highlight_overdue = true, -- Highlight overdue tasks
		highlight_priority = true, -- Highlight task priority
		highlight_tags = true, -- Highlight task tags
	},

	-- Sync settings
	sync = {
		on_save = true, -- Sync on file save
		auto_sync_interval = nil, -- Auto-sync interval in minutes (nil = disabled)
		conflict_resolution = "ask", -- Conflict resolution strategy: ask, prefer_taskwarrior, prefer_markdown
	},

	-- Logging
	logging = {
		level = "warn", -- debug, info, warn, error
		file = nil, -- nil to disable file logging
		use_console = false, -- Whether to log to console
	},
}

-- Current configuration (initialized with defaults)
local config = vim.deepcopy(default_config)

--- Validate configuration
--- @param cfg table Configuration table
--- @return Result Result with validated config or error
local function validate_config(cfg)
	if cfg.taskwarrior and cfg.taskwarrior.executable then
		local executable = cfg.taskwarrior.executable
		local cmd = string.format("which %s", executable)
		local handle = io.popen(cmd)

		if handle then
			local result = handle:read("*a")
			handle:close()

			if result == "" then
				return Result.Err(
					Error.config_error(
						"Taskwarrior executable not found: " .. executable,
						"taskwarrior.executable",
						executable
					)
				)
			end
		end
	end

	-- Validate sync settings
	if cfg.sync and cfg.sync.conflict_resolution then
		local valid_strategies = { "ask", "prefer_taskwarrior", "prefer_markdown" }
		local strategy = cfg.sync.conflict_resolution
		local valid = false

		for _, valid_strategy in ipairs(valid_strategies) do
			if strategy == valid_strategy then
				valid = true
				break
			end
		end

		if not valid then
			return Result.Err(
				Error.config_error(
					"Invalid conflict resolution strategy: " .. strategy,
					"sync.conflict_resolution",
					strategy
				)
			)
		end
	end

	return Result.Ok(cfg)
end

--- Setup the plugin configuration
--- @param opts table? User configuration
--- @return Result Result object with the config or error
function M.setup(opts)
	-- Merge defaults with user config
	local cfg = vim.deepcopy(default_config)
	if opts then
		cfg = vim.tbl_deep_extend("force", cfg, opts)
	end

	-- Validate the configuration
	local validation_result = validate_config(cfg)
	if validation_result:is_err() then
		Error.handle_error(validation_result.error)
		return validation_result
	end

	-- Set the global config
	config = cfg

	-- Configure logger
	Logger.setup(config.logging)

	Error.setup({
		log_level = config.logging.level == "debug" and Error.ERROR_LEVEL.DEBUG
			or config.logging.level == "info" and Error.ERROR_LEVEL.INFO
			or config.logging.level == "warn" and Error.ERROR_LEVEL.WARN
			or Error.ERROR_LEVEL.ERROR,
		log_to_file = config.logging.file ~= nil,
		log_path = config.logging.file,
		silent = not config.logging.use_console,
	})

	return Result.Ok(config)
end

--- Get the current configuration
--- @param key string? Optional key to get a specific config value
--- @return any Configuration value
function M.get(key)
	if not key then
		return vim.deepcopy(config)
	end

	local parts = vim.split(key, ".", { plain = true })
	local current = config

	for _, part in ipairs(parts) do
		if current[part] == nil then
			return nil
		end
		current = current[part]
	end

	-- Return a copy to prevent accidental modification
	if type(current) == "table" then
		return vim.deepcopy(current)
	end

	return current
end

return M
