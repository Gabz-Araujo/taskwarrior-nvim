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

--- Parse a date string into ISO format
--- @param date_str string Date string in various formats
--- @return string ISO formatted date (YYYY-MM-DD)
function M.parse_date(date_str)
	-- Handle empty or nil input
	if not date_str or date_str == "" then
		return nil
	end

	-- Handle common relative dates
	local lower_date = date_str:lower()

	if lower_date == "today" then
		return os.date("%Y-%m-%d")
	elseif lower_date == "tomorrow" then
		return os.date("%Y-%m-%d", os.time() + 86400) -- 86400 seconds = 1 day
	elseif lower_date == "yesterday" then
		return os.date("%Y-%m-%d", os.time() - 86400)
	elseif lower_date:match("^%d+d$") then
		-- Handle "Nd" format (N days from now)
		local days = tonumber(lower_date:match("^(%d+)d$"))
		return os.date("%Y-%m-%d", os.time() + (days * 86400))
	elseif lower_date:match("^%d+w$") then
		-- Handle "Nw" format (N weeks from now)
		local weeks = tonumber(lower_date:match("^(%d+)w$"))
		return os.date("%Y-%m-%d", os.time() + (weeks * 7 * 86400))
	elseif lower_date:match("^%d+m$") then
		-- Handle "Nm" format (N months from now)
		local months = tonumber(lower_date:match("^(%d+)m$"))
		local current_time = os.time()
		local current_date = os.date("*t", current_time)
		current_date.month = current_date.month + months
		-- Handle month overflow
		while current_date.month > 12 do
			current_date.month = current_date.month - 12
			current_date.year = current_date.year + 1
		end
		return os.date("%Y-%m-%d", os.time(current_date))
	elseif lower_date:match("^%d+y$") then
		-- Handle "Ny" format (N years from now)
		local years = tonumber(lower_date:match("^(%d+)y$"))
		local current_time = os.time()
		local current_date = os.date("*t", current_time)
		current_date.year = current_date.year + years
		return os.date("%Y-%m-%d", os.time(current_date))
	end

	-- Check if already in ISO format (YYYY-MM-DD)
	if date_str:match("^%d%d%d%d%-%d%d%-%d%d$") then
		-- Validate the ISO date
		if M.is_valid_calendar_date(date_str) then
			return date_str
		else
			return nil
		end
	end

	-- Handle MM/DD/YYYY format
	local month, day, year = date_str:match("^(%d+)/(%d+)/(%d+)$")
	if month and day and year then
		-- Ensure 4-digit year
		if #year == 2 then
			year = "20" .. year
		end

		-- Zero-pad month and day if needed
		month = (#month == 1) and "0" .. month or month
		day = (#day == 1) and "0" .. day or day

		local iso_date = string.format("%s-%s-%s", year, month, day)
		if M.is_valid_calendar_date(iso_date) then
			return iso_date
		end
	end

	-- Handle DD-MM-YYYY format
	local day, month, year = date_str:match("^(%d+)%-(%d+)%-(%d+)$")
	if day and month and year and #year == 4 then
		-- Zero-pad month and day if needed
		month = (#month == 1) and "0" .. month or month
		day = (#day == 1) and "0" .. day or day

		local iso_date = string.format("%s-%s-%s", year, month, day)
		if M.is_valid_calendar_date(iso_date) then
			return iso_date
		end
	end

	-- If we couldn't parse it, return as is (let Taskwarrior handle special formats)
	return date_str
end

return M
