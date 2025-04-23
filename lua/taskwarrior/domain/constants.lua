local Constants = {}

-- Task status constants
Constants.STATUS = {
	DONE = "done",
	UNDONE = "undone",
	PENDING = "pending",
	ON_HOLD = "on-hold",
	CANCELED = "canceled",
	RECURRING = "recurring",
	IMPORTANT = "important",
}

-- Task priority constants
Constants.PRIORITY = {
	HIGH = "H",
	MEDIUM = "M",
	LOW = "L",
}

-- Checkbox to status mapping
Constants.CHECKBOX_TO_STATUS = {
	["[x]"] = Constants.STATUS.DONE,
	["[u]"] = Constants.STATUS.UNDONE,
	["[ ]"] = Constants.STATUS.PENDING,
	["[-]"] = Constants.STATUS.ON_HOLD,
	["[c]"] = Constants.STATUS.CANCELED,
	["[r]"] = Constants.STATUS.RECURRING,
	["[!]"] = Constants.STATUS.IMPORTANT,
}

-- Status to checkbox mapping
Constants.STATUS_TO_CHECKBOX = {}
for checkbox, status in pairs(Constants.CHECKBOX_TO_STATUS) do
	Constants.STATUS_TO_CHECKBOX[status] = checkbox
end

-- Date format patterns
Constants.DATE_PATTERNS = {
	ISO_DATE = "^%d%d%d%d%-%d%d%-%d%d$",
	ISO_DATETIME = "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d[Z%+%-].*$",
}

return Constants
