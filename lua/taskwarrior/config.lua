local M = {}

local config = {}

function M.setup(user_config)
	config = user_config

	M.validate()

	return config
end

function M.get()
	return config
end

function M.get_value(key, default)
	local result = config
	for subkey in key:gmatch("[^.]+") do
		if type(result) ~= "table" then
			return default
		end
		result = result[subkey]
		if result == nil then
			return default
		end
	end
	return result
end

function M.validate()
	if vim.fn.executable("task") ~= 1 then
		vim.notify("Taskwarrior executable not found. Please install taskwarrior.", vim.log.levels.ERROR)
	end
end

return M
