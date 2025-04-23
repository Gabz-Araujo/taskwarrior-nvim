---@diagnostic disable: undefined-global
local mock = {}

local originals = {}
local BufferReader = require("taskwarrior.infrastructure.io.buffer_reader")

function mock.current_line(line, line_number)
	-- Keep original mocking for backward compatibility
	originals.get_current_line = vim.api.nvim_get_current_line
	originals.line = vim.fn.line
	vim.api.nvim_get_current_line = function()
		return line
	end
	vim.fn.line = function()
		return line_number or 1
	end

	-- Also mock our buffer reader abstraction
	mock.buffer_reader({
		current_line = line,
		current_line_number = line_number or 1,
	})
end

function mock.buf_lines(lines, buf_id)
	buf_id = buf_id or 0
	originals.get_current_buf = vim.api.nvim_get_current_buf
	originals.get_buf_lines = vim.api.nvim_buf_get_lines
	originals.buf_line_count = vim.api.nvim_buf_line_count

	vim.api.nvim_get_current_buf = function()
		return buf_id
	end

	vim.api.nvim_buf_get_lines = function(buffer, start_idx, end_idx)
		if not lines[start_idx + 1] then
			return {}
		end
		local result = {}
		for i = start_idx + 1, end_idx do
			table.insert(result, lines[i] or "")
		end
		return result
	end

	vim.api.nvim_buf_line_count = function()
		return #lines
	end

	-- Also mock our buffer reader
	mock.buffer_reader({
		lines = lines,
		current_buffer = buf_id,
		line_count = #lines,
	})
end

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
		if k == "get_current_line" then
			vim.api.nvim_get_current_line = v
		elseif k == "line" then
			vim.fn.line = v
		elseif k == "get_current_buf" then
			vim.api.nvim_get_current_buf = v
		elseif k == "get_buf_lines" then
			vim.api.nvim_buf_get_lines = v
		elseif k == "buf_line_count" then
			vim.api.nvim_buf_line_count = v
		elseif k == "buffer_reader" then
			BufferReader.reset_implementation()
		end
	end
	originals = {}
end

return mock
