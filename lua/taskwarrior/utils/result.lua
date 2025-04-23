--- Result type for error handling in Taskwarrior.nvim
--- @module taskwarrior.utils.result
--- Implementation of Result pattern: a container that represents either success (with a value) or failure (with an error)

local Error = require("taskwarrior.utils.error")

local Result = {}
local Result_mt = {
	__index = Result,
	__tostring = function(self)
		if self:is_ok() then
			return string.format("Result.Ok(%s)", tostring(self.value))
		else
			return string.format("Result.Err(%s)", tostring(self.error.message))
		end
	end,
}

--- Create a new successful Result
--- @param value any The success value
--- @return table Result containing the value
function Result.Ok(value)
	return setmetatable({
		value = value,
		error = nil,
	}, Result_mt)
end

--- Create a new failure Result
--- @param error table|string The error object or message
--- @param error_type string? The error type if message is a string
--- @param context table? Additional error context
--- @return table Result containing the error
function Result.Err(error, error_type, context)
	-- Convert string messages to error objects
	if type(error) == "string" then
		error = Error.create_error(error, error_type, nil, context)
	end

	return setmetatable({
		value = nil,
		error = error,
	}, Result_mt)
end

--- Check if the Result represents success
--- @return boolean True if Result is successful
function Result:is_ok()
	return self.error == nil
end

--- Check if the Result represents failure
--- @return boolean True if Result is a failure
function Result:is_err()
	return self.error ~= nil
end

--- Unwrap the Result value or raise an error if it's a failure
--- @param msg string? Optional custom error message
--- @return any The success value
function Result:unwrap(msg)
	if self:is_err() then
		local error_msg = msg or "Attempted to unwrap an Err value"
		error(string.format("%s: %s", error_msg, self.error.message))
	end
	return self.value
end

--- Unwrap the Result value or return a default value if it's a failure
--- @param default any The default value to return if Result is a failure
--- @return any The success value or default
function Result:unwrap_or(default)
	if self:is_err() then
		return default
	end
	return self.value
end

--- Unwrap the Result value or call a function to get a default value if it's a failure
--- @param fn function Function that returns a default value
--- @return any The success value or computed default
function Result:unwrap_or_else(fn)
	if self:is_err() then
		return fn(self.error)
	end
	return self.value
end

--- Map a function over the Result value
--- @param fn function Function to apply to the value
--- @return table New Result with mapped value
function Result:map(fn)
	if self:is_err() then
		return self
	end
	return Result.Ok(fn(self.value))
end

--- Map a function over the Result error
--- @param fn function Function to apply to the error
--- @return table New Result with mapped error
function Result:map_err(fn)
	if self:is_ok() then
		return self
	end
	return Result.Err(fn(self.error))
end

--- Chain computations that return Results
--- @param fn function Function that takes the value and returns a new Result
--- @return table New Result
function Result:and_then(fn)
	if self:is_err() then
		return self
	end
	return fn(self.value)
end

--- Return the first success Result
--- @param fn function Function that returns a new Result
--- @return table New Result
function Result:or_else(fn)
	if self:is_ok() then
		return self
	end
	return fn(self.error)
end

--- Handle both success and failure cases
--- @param ok_fn function Function to call on success
--- @param err_fn function Function to call on failure
--- @return any Result of calling either function
function Result:match(ok_fn, err_fn)
	if self:is_ok() then
		return ok_fn(self.value)
	else
		return err_fn(self.error)
	end
end

return Result
