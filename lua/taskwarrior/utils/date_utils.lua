--- Date utility functions for Taskwarrior.nvim
--- @module taskwarrior.utils.date_utils

local Constants = require("taskwarrior.domain.constants")
local M = {}

--- Check if a string follows ISO date pattern
--- @param date string The date string to check
--- @return boolean Whether the string matches an ISO date pattern
function M.is_iso_date_pattern(date)
	return date:match(Constants.DATE_PATTERNS.ISO_DATE) ~= nil
end

--- Check if a string follows ISO datetime pattern
--- @param date string The date string to check
--- @return boolean Whether the string matches an ISO datetime pattern
function M.is_iso_datetime_pattern(date)
	return date:match(Constants.DATE_PATTERNS.ISO_DATETIME) ~= nil
end

--- Verify that a date string represents a valid calendar date
--- @param date string ISO date string (YYYY-MM-DD)
--- @return boolean Whether date is a valid calendar date
function M.is_valid_calendar_date(date)
	-- Check basic pattern first
	if not M.is_iso_date_pattern(date) then
		return false
	end

	-- Extract year, month, day
	local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	year, month, day = tonumber(year), tonumber(month), tonumber(day)

	-- Basic validation
	if month < 1 or month > 12 or day < 1 or day > 31 then
		return false
	end

	-- Handle specific month length rules
	local days_in_month = {
		31, -- January
		28, -- February (adjusted below for leap years)
		31, -- March
		30, -- April
		31, -- May
		30, -- June
		31, -- July
		31, -- August
		30, -- September
		31, -- October
		30, -- November
		31, -- December
	}

	-- Adjust February for leap years
	if month == 2 then
		if (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0 then
			days_in_month[2] = 29
		end
	end

	return day <= days_in_month[month]
end

--- Format an ISO date string for display
--- @param date string ISO date string
--- @param format? string Optional format string
--- @return string Formatted date string
function M.format_date(date, format)
	-- Default to ISO format if no format specified
	format = format or "%Y-%m-%d"

	-- Extract date components
	local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
	if not year then
		return date -- Return original if no match
	end

	-- Convert to time table (at noon to avoid timezone issues)
	local time = os.time({
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
		hour = 12,
		min = 0,
		sec = 0,
	})

	-- Format according to specified format
	return os.date(format, time)
end

return M
