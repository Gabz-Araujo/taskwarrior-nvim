--- @module taskwarrior.domain.task

local Constants = require("taskwarrior.domain.constants")
local Validation = require("taskwarrior.utils.validation")
local Result = require("taskwarrior.utils.result")

--- @alias TaskStatus
--- | "done" # Task is completed
--- | "undone" # Task was undone
--- | "pending" # Task is pending
--- | "on-hold" # Task is on hold
--- | "canceled" # Task is canceled
--- | "recurring" # Task is recurring
--- | "important" # Task is marked as important

--- @alias TaskPriority
--- | "H" # High priority
--- | "M" # Medium priority
--- | "L" # Low priority
--- | nil # No priority

--- @class Task
--- @field id string|integer|nil Task ID number
--- @field uuid string|nil Task UUID
--- @field description string Task description
--- @field status TaskStatus|nil Task status
--- @field priority TaskPriority|nil Task priority
--- @field due string|nil Due date (ISO format YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
--- @field wait string|nil Wait date (ISO format)
--- @field scheduled string|nil Scheduled date (ISO format)
--- @field until string|nil Until date (ISO format)
--- @field tags string[]|nil List of tags
--- @field project string|nil Project name
--- @field recur string|nil Recurrence pattern
--- @field annotations table<integer, {description: string, entry: string}>|nil List of annotations
--- @field depends string|nil Comma-separated list of dependent task UUIDs
--- @field urgency number|nil Urgency score
--- @field entry string|nil Entry timestamp (creation date)
--- @field modified string|nil Last modified timestamp
--- @field end string|nil Completion timestamp
--- @field type string|nil Type of source (markdown or comment)
--- @field line integer|nil Line number in source file
--- @field checked boolean|nil Whether task is checked (markdown)
--- @field continuation_lines integer|nil Number of continuation lines
--- @field uda table<string, any>|nil User Defined Attributes

local Task = {}
local Task_mt = { __index = Task }

-- Use constants from the constants module
Task.status_to_checkbox = Constants.STATUS_TO_CHECKBOX
Task.checkbox_to_status = Constants.CHECKBOX_TO_STATUS

--- Validate task data
--- @param task Task Task to validate
--- @return Result Result object with validation result or error
--- @private
function Task._validate(task)
	if not task.description then
		return Result.Err({ "Task description is empty" })
	end

	if task.status then
		local status_result = Validation.validate_status(task.status)
		if status_result:is_err() then
			return status_result
		end
	end

	-- Validate priority
	if task.priority then
		local priority_result = Validation.validate_priority(task.priority)
		if priority_result:is_err() then
			return priority_result
		end
	end

	-- Validate date fields
	local date_fields = { "due", "wait", "scheduled", "until", "entry", "modified", "end" }
	for _, field in ipairs(date_fields) do
		if task[field] then
			local date_result = Validation.validate_date(task[field])
			if date_result:is_err() then
				return Result.Err(
					date_result.error.message .. " Field: " .. field,
					date_result.error.type,
					{ field = field, value = task[field] }
				)
			end
		end
	end

	return Result.Ok(true)
end

--- Create a new Task instance
--- @param data table|nil Initial task data
--- @return Result<Task, Error> New task object or error if validation fails
function Task.new(data)
	data = data or {}
	local self = {
		id = data.id,
		uuid = data.uuid,
		description = data.description,
		status = data.status or Constants.STATUS.PENDING,
		priority = data.priority,
		due = data.due,
		wait = data.wait,
		scheduled = data.scheduled,
		until_ = data.until_,
		tags = data.tags or {},
		project = data.project,
		recur = data.recur,
		annotations = data.annotations or {},
		depends = data.depends,
		urgency = data.urgency,
		entry = data.entry,
		modified = data.modified,
		end_ = data.end_,
		type = data.type,
		line = data.line,
		checked = data.checked,
		continuation_lines = data.continuation_lines,
		uda = data.uda or {},
	}

	local validation_result = Task._validate(self)

	if validation_result:is_err() then
		return Result.Err(validation_result.error)
	end

	return Result.Ok(setmetatable(self, Task_mt))
end

--- Set task status
--- @param status TaskStatus New status
--- @return boolean Success
--- @return string|nil Error message
function Task:set_status(status)
	local Error = require("taskwarrior.utils.error")

	local status_result = Validation.validate_status(status)
	if status_result:is_err() then
		Error.handle_error(status_result.error)
		return false, status_result.error.message
	end

	self.status = status

	self.checked = (status == Constants.STATUS.DONE)

	return true
end

--- Get the checkbox representation of the task's status
--- @return string Checkbox representation
function Task:get_checkbox()
	return Task.status_to_checkbox[self.status] or "[ ]"
end

--- Create a Task from Taskwarrior JSON export data
--- @param json_data table Taskwarrior task data from JSON export
--- @return Task|nil Task object or nil if validation fails
--- @return string|nil Error message if validation fails
function Task.from_taskwarrior_json(json_data)
	local base_task = {
		tags = {},
		annotations = {},
		uda = {},
	}

	-- Copy standard fields
	for k, v in pairs(json_data) do
		if
			k == "id"
			or k == "uuid"
			or k == "description"
			or k == "status"
			or k == "priority"
			or k == "due"
			or k == "wait"
			or k == "scheduled"
			or k == "until"
			or k == "project"
			or k == "recur"
			or k == "depends"
			or k == "urgency"
			or k == "entry"
			or k == "modified"
			or k == "end"
		then
			base_task[k] = v
		elseif k == "tags" then
			base_task.tags = v
		elseif k == "annotations" then
			base_task.annotations = v
		else
			base_task.uda[k] = v
		end
	end

	local new_task = Task.new(base_task)

	return new_task
end

--- Create a deep copy of the task
--- @return Task New task object with same values
function Task:clone()
	local new_task = {}

	-- Copy standard fields
	for k, v in pairs(self) do
		if k ~= "tags" and k ~= "annotations" and k ~= "uda" then
			new_task[k] = v
		end
	end

	-- Deep copy tags
	new_task.tags = {}
	for i, tag in ipairs(self.tags or {}) do
		new_task.tags[i] = tag
	end

	-- Deep copy annotations
	new_task.annotations = {}
	for i, anno in ipairs(self.annotations or {}) do
		new_task.annotations[i] = {
			description = anno.description,
			entry = anno.entry,
		}
	end

	-- Deep copy UDAs
	new_task.uda = {}
	for k, v in pairs(self.uda or {}) do
		new_task.uda[k] = v
	end

	return setmetatable(new_task, Task_mt)
end

--- Convert task to taskwarrior command arguments
--- @return string[] List of command arguments
function Task:to_command_args()
	local args = {}

	if self.description then
		table.insert(args, string.format('description:"%s"', self.description))
	end

	if self.priority then
		table.insert(args, string.format("priority:%s", self.priority))
	end

	if self.project then
		table.insert(args, string.format('project:"%s"', self.project))
	end

	if self.due then
		table.insert(args, string.format("due:%s", self.due))
	end

	if self.wait then
		table.insert(args, string.format("wait:%s", self.wait))
	end

	if self.scheduled then
		table.insert(args, string.format("scheduled:%s", self.scheduled))
	end

	if self.until_ then -- 'until' is a reserved word in Lua
		table.insert(args, string.format("until:%s", self.until_))
	end

	if self.recur then
		table.insert(args, string.format("recur:%s", self.recur))
	end

	if self.depends then
		table.insert(args, string.format("depends:%s", self.depends))
	end

	-- Add tags
	for _, tag in ipairs(self.tags or {}) do
		table.insert(args, string.format("+%s", tag))
	end

	-- Add UDAs
	for name, value in pairs(self.uda or {}) do
		if type(value) == "string" then
			table.insert(args, string.format('%s:"%s"', name, value))
		else
			table.insert(args, string.format("%s:%s", name, tostring(value)))
		end
	end

	return args
end

--- Convert task to markdown format
--- @param include_metadata boolean? Include task metadata (default: true)
--- @return string Markdown representation
function Task:to_markdown(include_metadata)
	local parts = {}
	local checkbox = self:get_checkbox()

	-- Add base task with checkbox
	table.insert(parts, string.format("- %s %s", checkbox, self.description))

	if include_metadata then
		if self.priority then
			table.insert(parts, string.format(" [Priority: %s]", self.priority))
		end

		if self.due then
			local due_date = self.due:sub(1, 10) -- Get just the date part
			table.insert(parts, string.format(" [Due: %s]", due_date))
		end

		if self.recur then
			table.insert(parts, string.format(" [Recur: %s]", self.recur))
		end
	end

	-- Add tags as hashtags
	for _, tag in ipairs(self.tags or {}) do
		table.insert(parts, string.format(" #%s", tag))
	end

	-- Add task ID reference
	if self.uuid then
		table.insert(parts, string.format(" [ID](ID: %s)", self.uuid))
	elseif self.id then
		table.insert(parts, string.format(" [ID](ID: %s)", self.id))
	end

	return table.concat(parts, "")
end

--- Check if the task is completed
--- @return boolean True if task is completed
function Task:is_completed()
	return self.status == Constants.STATUS.DONE
end

--- Check if the task is overdue
--- @return boolean True if task is overdue
function Task:is_overdue()
	if not self.due then
		return false
	end

	local due_time = os.time({
		year = tonumber(self.due:sub(1, 4)),
		month = tonumber(self.due:sub(6, 7)),
		day = tonumber(self.due:sub(9, 10)),
		hour = 23,
		min = 59,
		sec = 59,
	})

	return os.time() > due_time
end

--- Set task priority
--- @param priority TaskPriority New priority
--- @return boolean Success
--- @return string|nil Error message
function Task:set_priority(priority)
	local Error = require("taskwarrior.utils.error")

	if priority then
		local priority_result = Validation.validate_priority(priority)
		if priority_result:is_err() then
			Error.handle_error(priority_result.error)
			return false, priority_result.error.message
		end
	end

	self.priority = priority
	return true
end

--- Set due date
--- @param due string|nil Due date in YYYY-MM-DD format or nil to clear
--- @return boolean Success
--- @return string|nil Error message
function Task:set_due(due)
	local Error = require("taskwarrior.utils.error")

	if due then
		local due_result = Validation.validate_date(due)
		if due_result:is_err() then
			Error.handle_error(due_result.error)
			return false, due_result.error.message
		end
	end

	self.due = due
	return true
end

--- Set recurrence pattern
--- @param recur string|nil Recurrence pattern or nil to clear
function Task:set_recurrence(recur)
	self.recur = recur
end

--- Check if task has a specific tag
--- @param tag string Tag to check
--- @return boolean True if task has the tag
function Task:has_tag(tag)
	for _, t in ipairs(self.tags or {}) do
		if t == tag then
			return true
		end
	end
	return false
end

--- Add a tag to the task
--- @param tag string Tag to add
--- @return boolean True if tag was added, false if already present
function Task:add_tag(tag)
	if self:has_tag(tag) then
		return false
	end

	self.tags = self.tags or {}
	table.insert(self.tags, tag)
	return true
end

--- Remove a tag from the task
--- @param tag string Tag to remove
--- @return boolean True if tag was removed, false if not found
function Task:remove_tag(tag)
	if not self.tags then
		return false
	end

	for i, t in ipairs(self.tags) do
		if t == tag then
			table.remove(self.tags, i)
			return true
		end
	end

	return false
end

--- Add an annotation to the task
--- @param text string Annotation text
function Task:add_annotation(text)
	self.annotations = self.annotations or {}

	local now = os.date("!%Y%m%dT%H%M%SZ")
	table.insert(self.annotations, {
		description = text,
		entry = now,
	})
end

--- Get a User Defined Attribute
--- @param name string UDA name
--- @return any UDA value or nil if not set
function Task:get_uda(name)
	return self.uda and self.uda[name]
end

--- Set a User Defined Attribute
--- @param name string UDA name
--- @param value any UDA value (nil to remove)
function Task:set_uda(name, value)
	self.uda = self.uda or {}
	self.uda[name] = value
end

--- Compare this task with another and return differences
--- @param other Task Other task to compare with
--- @return table<string, {old:any, new:any}> Table of differences
function Task:diff(other)
	local differences = {}

	-- Compare standard fields
	local fields = {
		"description",
		"status",
		"priority",
		"due",
		"wait",
		"scheduled",
		"until",
		"project",
		"recur",
		"depends",
	}

	for _, field in ipairs(fields) do
		if self[field] ~= other[field] then
			differences[field] = { old = self[field], new = other[field] }
		end
	end

	-- Optimize tag comparison using lookup tables
	local self_tags = {}
	local other_tags = {}

	for _, tag in ipairs(self.tags or {}) do
		self_tags[tag] = true
	end

	for _, tag in ipairs(other.tags or {}) do
		other_tags[tag] = true
	end

	local tags_diff = { added = {}, removed = {} }
	local tags_changed = false

	-- Find added tags
	for tag in pairs(other_tags) do
		if not self_tags[tag] then
			table.insert(tags_diff.added, tag)
			tags_changed = true
		end
	end

	-- Find removed tags
	for tag in pairs(self_tags) do
		if not other_tags[tag] then
			table.insert(tags_diff.removed, tag)
			tags_changed = true
		end
	end

	if tags_changed then
		differences.tags = tags_diff
	end

	-- Compare UDAs
	for name, value in pairs(self.uda or {}) do
		if other.uda[name] ~= value then
			differences[name] = { old = value, new = other.uda[name] }
		end
	end

	for name, value in pairs(other.uda or {}) do
		if not self.uda[name] then
			differences[name] = { old = nil, new = value }
		end
	end

	-- Compare annotations by content
	local changed_annotations = false
	local annotation_diff = {
		added = {},
		removed = {},
	}

	-- Create lookup tables for annotations
	local self_annotations = {}
	local other_annotations = {}

	for _, anno in ipairs(self.annotations or {}) do
		self_annotations[anno.description] = anno
	end

	for _, anno in ipairs(other.annotations or {}) do
		other_annotations[anno.description] = anno

		-- Check for added annotations
		if not self_annotations[anno.description] then
			table.insert(annotation_diff.added, anno)
			changed_annotations = true
		end
	end

	-- Check for removed annotations
	for _, anno in ipairs(self.annotations or {}) do
		if not other_annotations[anno.description] then
			table.insert(annotation_diff.removed, anno)
			changed_annotations = true
		end
	end

	if changed_annotations then
		differences.annotations = annotation_diff
	end

	return differences
end

return Task
