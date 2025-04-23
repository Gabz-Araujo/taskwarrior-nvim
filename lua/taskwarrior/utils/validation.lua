local Constants = require("taskwarrior.domain.constants")
local DateUtils = require("taskwarrior.utils.date_utils")
local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")

local Validation = {}

-- Create a safe wrapper to create Result objects
local function createResult(isOk, value)
	if type(Result) ~= "table" or not Result.Ok or not Result.Err then
		-- Fallback to a basic implementation if Result module isn't available
		if isOk then
			return {
				value = value,
				is_ok = function()
					return true
				end,
				is_err = function()
					return false
				end,
			}
		else
			return {
				error = value,
				is_ok = function()
					return false
				end,
				is_err = function()
					return true
				end,
			}
		end
	else
		return isOk and Result.Ok(value) or Result.Err(value)
	end
end

--- Validate a date string
--- @param date string The date string to validate
--- @param format? string Optional format to validate against
--- @return Result Result object with validation result
function Validation.validate_date(date, format)
	if not date then
		return createResult(true, true) -- nil dates are valid (not set)
	end

	-- Check if date matches ISO date pattern and is valid calendar date
	if format == "date" or not format then
		if not DateUtils.is_iso_date_pattern(date) then
			return createResult(
				false,
				Error.validation_error("Invalid date format. Expected YYYY-MM-DD.", "date", date)
			)
		end

		if not DateUtils.is_valid_calendar_date(date) then
			return createResult(false, Error.validation_error("Invalid calendar date.", "date", date))
		end

		return createResult(true, true)
	end

	-- Check if date matches ISO datetime pattern
	if format == "datetime" then
		if not DateUtils.is_iso_datetime_pattern(date) then
			return createResult(
				false,
				Error.validation_error("Invalid datetime format. Expected ISO 8601 format.", "date", date)
			)
		end

		return createResult(true, true)
	end

	return createResult(
		false,
		Error.validation_error("Unsupported date format: " .. (format or "unknown"), "format", format)
	)
end

--- Check if a date is valid (backward compatibility)
--- @param date string The date string to validate
--- @param format? string Optional format to validate against
--- @return boolean Whether the date is valid
function Validation.is_valid_date(date, format)
	local result = Validation.validate_date(date, format)
	return type(result) == "table" and result.is_ok and result:is_ok()
end

--- Validate a priority value
--- @param priority string The priority to validate
--- @return Result Result object with validation result
function Validation.validate_priority(priority)
	if not priority then
		return createResult(true, true) -- nil priority is valid (not set)
	end

	if
		priority ~= Constants.PRIORITY.HIGH
		and priority ~= Constants.PRIORITY.MEDIUM
		and priority ~= Constants.PRIORITY.LOW
	then
		return createResult(
			false,
			Error.validation_error("Invalid priority. Expected H, M, or L.", "priority", priority)
		)
	end

	return createResult(true, true)
end

--- Check if a priority is valid (backward compatibility)
--- @param priority string The priority to validate
--- @return boolean Whether the priority is valid
function Validation.is_valid_priority(priority)
	local result = Validation.validate_priority(priority)
	return type(result) == "table" and result.is_ok and result:is_ok()
end

--- Validate a status value
--- @param status string The status to validate
--- @return Result Result object with validation result
function Validation.validate_status(status)
	if not status then
		return createResult(true, true) -- nil status is valid (will default)
	end

	for _, valid_status in pairs(Constants.STATUS) do
		if status == valid_status then
			return createResult(true, true)
		end
	end

	return createResult(false, Error.validation_error("Invalid status: " .. tostring(status), "status", status))
end

--- Check if a status is valid (backward compatibility)
--- @param status string The status to validate
--- @return boolean Whether the status is valid
function Validation.is_valid_status(status)
	local result = Validation.validate_status(status)
	return type(result) == "table" and result.is_ok and result:is_ok()
end

return Validation
