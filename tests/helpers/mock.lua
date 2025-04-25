---@diagnostic disable: undefined-global
local mock = {}

local originals = {}
local BufferReader = require("taskwarrior.infrastructure.io.buffer_reader")

-- Mock our buffer reader abstraction
function mock.buffer_reader(options)
	options = options or {}

	local mock_impl = {
		get_current_line = function()
			return options.current_line or ""
		end,

		get_current_line_number = function()
			return options.current_line_number or 1
		end,

		get_current_buffer = function()
			return options.current_buffer or 0
		end,

		get_line_count = function()
			return options.line_count or #(options.lines or {})
		end,

		get_lines = function(buffer_id, start_line, end_line)
			local result = {}
			for i = start_line + 1, end_line do
				table.insert(result, (options.lines or {})[i] or "")
			end
			return result
		end,
	}

	-- Save original implementation
	if not originals.buffer_reader then
		originals.buffer_reader = true
	end

	-- Set our mock implementation
	BufferReader.set_implementation(mock_impl)
end

function mock.restore_all()
	for k, v in pairs(originals) do
		if k == "buffer_reader" then
			BufferReader.reset_implementation()
		end
	end
	originals = {}
end

return mock
