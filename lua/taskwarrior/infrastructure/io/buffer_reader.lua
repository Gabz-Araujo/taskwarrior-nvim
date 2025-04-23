--- Buffer reader abstraction for Taskwarrior.nvim
--- @module taskwarrior.infrastructure.io.buffer_reader

local M = {}

-- Default implementation using Neovim API
local default_impl = {
	--- Get current line in buffer
	--- @return string Line text
	get_current_line = function()
		return vim.api.nvim_get_current_line()
	end,

	--- Get current line number
	--- @return integer Line number
	get_current_line_number = function()
		return vim.fn.line(".")
	end,

	--- Get current buffer ID
	--- @return integer Buffer ID
	get_current_buffer = function()
		return vim.api.nvim_get_current_buf()
	end,

	--- Get total lines in buffer
	--- @param buffer_id integer Buffer ID
	--- @return integer Total line count
	get_line_count = function(buffer_id)
		buffer_id = buffer_id or vim.api.nvim_get_current_buf()
		return vim.api.nvim_buf_line_count(buffer_id)
	end,

	--- Get lines from buffer
	--- @param buffer_id integer Buffer ID
	--- @param start_line integer Start line (0-based)
	--- @param end_line integer End line (0-based, exclusive)
	--- @return string[] Array of lines
	get_lines = function(buffer_id, start_line, end_line)
		buffer_id = buffer_id or vim.api.nvim_get_current_buf()
		return vim.api.nvim_buf_get_lines(buffer_id, start_line, end_line, false)
	end,
}

-- Current implementation (can be overridden for testing)
local impl = default_impl

--- Set custom implementation (for testing)
--- @param custom_impl table Custom implementation
function M.set_implementation(custom_impl)
	impl = custom_impl
end

--- Reset to default implementation
function M.reset_implementation()
	impl = default_impl
end

--- Get current line in buffer
--- @return string Line text
function M.get_current_line()
	return impl.get_current_line()
end

--- Get current line number
--- @return integer Line number
function M.get_current_line_number()
	return impl.get_current_line_number()
end

--- Get current buffer ID
--- @return integer Buffer ID
function M.get_current_buffer()
	return impl.get_current_buffer()
end

--- Get total lines in buffer
--- @param buffer_id? integer Optional buffer ID (defaults to current)
--- @return integer Total line count
function M.get_line_count(buffer_id)
	return impl.get_line_count(buffer_id)
end

--- Get lines from buffer
--- @param buffer_id integer Buffer ID
--- @param start_line integer Start line (0-based)
--- @param end_line integer End line (0-based, exclusive)
--- @return string[] Array of lines
function M.get_lines(buffer_id, start_line, end_line)
	return impl.get_lines(buffer_id, start_line, end_line)
end

--- Get a specific line from buffer (1-indexed)
--- @param buffer_id integer Buffer ID
--- @param line_number integer Line number (1-indexed)
--- @return string Line text
function M.get_line(buffer_id, line_number)
	local lines = impl.get_lines(buffer_id, line_number - 1, line_number)
	return lines[1]
end

return M
