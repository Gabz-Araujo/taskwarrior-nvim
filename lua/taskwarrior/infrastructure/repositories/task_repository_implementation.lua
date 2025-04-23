local TaskwarriorAdapter = require("taskwarrior.infrastructure.adapters.taskwarrior_adapter")
local Task = require("taskwarrior.domain.entities.task")
local Result = require("taskwarrior.utils.result")
local Error = require("taskwarrior.utils.error")
local Logger = require("taskwarrior.utils.logger")

--- @class TaskRepositoryImplementation
--- @implements TaskRepository
local M = {}

--- Get a task by its ID or UUID
--- @param id string|number Task ID or UUID
--- @return Result<Task, Error> Result containing the task or an error
function M.get_by_id(id)
	local result = TaskwarriorAdapter.get_tasks(tostring(id))

	if result:is_err() then
		return result
	end

	if #result.value.tasks == 0 then
		return Result.Err(Error.not_found_error("Task not found with ID: " .. tostring(id)))
	end

	local task = Task.from_taskwarrior_json(result.value.tasks[1])
	if not task then
		return Result.Err(Error.validation_error("Failed to create Task entity from raw data"))
	end

	return Result.Ok(task)
end

--- Get all tasks matching a filter
--- @param filter? table|string Optional filter specification
--- @return Result<Task[], Error> Result containing an array of tasks or an error
function M.get_all(filter)
	filter = filter or {}

	local result = TaskwarriorAdapter.get_tasks(filter)

	if result:is_err() then
		return result
	end

	local tasks = {}
	for _, task_data in ipairs(result.value.tasks) do
		local task = Task.from_taskwarrior_json(task_data)
		if task then
			table.insert(tasks, task)
		end
	end

	return Result.Ok(tasks)
end

--- Save a task (create if new, update if existing)
--- @param task Task Task entity to save
--- @return Result<Task, Error> Result containing the saved task or an error
function M.save(task)
	local validation_result = Task._validate(task)
	if validation_result:is_err() then
		return validation_result
	end

	local result

	-- If the task has an ID or UUID, it's an update
	if task.id or task.uuid then
		-- Fetch existing task using either ID or UUID provided
		local fetch_id = task.uuid or task.id
		local existing_result = M.get_by_id(fetch_id)
		if existing_result:is_err() then
			-- If fetching by UUID failed, maybe it was deleted and recreated with same UUID? Try ID just in case.
			-- This is an edge case, normally the UUID fetch should work if the task exists.
			if task.id and fetch_id ~= task.id then
				existing_result = M.get_by_id(task.id)
			end
			-- If still not found, return the original error
			if existing_result:is_err() then
				return existing_result
			end
		end

		local existing_task = existing_result.value
		local differences = existing_task:diff(task)

		-- Use the definite numeric ID from the fetched task for modifications
		local numeric_id = existing_task.id -- *** IMPORTANT: Use the ID from the fetched task ***

		-- Prepare modifications
		local modifications = {}
		local annotation_results = {} -- Store annotation results

		for field, diff in pairs(differences) do
			if field == "tags" then
				modifications.tags = modifications.tags or {}
				for _, tag in ipairs(diff.added or {}) do
					table.insert(modifications.tags, "+" .. tag)
				end
				for _, tag in ipairs(diff.removed or {}) do
					table.insert(modifications.tags, "-" .. tag)
				end
			elseif field == "annotations" then
				-- Handle annotation additions separately as they use a different adapter call
				for _, anno in ipairs(diff.added or {}) do
					-- FIX: Pass the numeric ID to annotate_task
					local anno_result = TaskwarriorAdapter.annotate_task(numeric_id, anno.description)
					table.insert(annotation_results, anno_result) -- Store result
				end
				-- Denotation (removal) isn't handled here
			else
				if diff.new ~= nil then
					modifications[field] = diff.new
				end
			end
		end

		-- Check if any annotation call failed
		for _, anno_res in ipairs(annotation_results) do
			if anno_res:is_err() then
				return anno_res -- Return the first annotation error found
			end
		end

		-- Apply modifications if there are any non-annotation changes
		if next(modifications) then
			-- FIX: Pass the numeric ID to modify_task
			result = TaskwarriorAdapter.modify_task(numeric_id, modifications)
		else
			-- If only annotations were added, we need to handle the result flow
			-- If there were successful annotation additions, the overall operation succeeded so far
			if #annotation_results > 0 then
				-- We need a successful Result object to proceed, but no main task modification happened
				-- Let's assume the last successful annotation result is good enough for flow control
				result = annotation_results[#annotation_results]
			else
				-- No changes at all (neither mods nor annotations)
				return Result.Ok(task:clone())
			end
		end
	else
		-- This is a new task, call add_task
		result = TaskwarriorAdapter.add_task(task)
	end

	-- Process the result of add_task or modify_task
	if result:is_err() then
		return result
	end

	-- If the adapter call returned a full task object (common for modify/add)
	if result.value and result.value.task then
		local updated_task = Task.from_taskwarrior_json(result.value.task)
		if updated_task then
			return Result.Ok(updated_task)
		end
		-- Fallback if parsing fails (shouldn't ideally happen)
		return Result.Err(Error.validation_error("Failed to parse updated task from adapter result"))
	end

	-- If the adapter only returned an ID (common for add_task) or message, refetch the task
	local final_id = result.value and result.value.id or task.id -- Use ID from result if available, else original task ID
	if final_id then
		return M.get_by_id(final_id) -- Refetch using ID
	end

	-- Should not be reachable if add/modify succeeded, but as a fallback:
	if task.id or task.uuid then
		return M.get_by_id(task.uuid or task.id) -- Try refetching with original identifier
	end

	-- Absolute fallback - this indicates an issue
	return Result.Err(Error.unknown_error("Could not determine task ID after save operation"))
end

--- Delete a task by its ID or UUID
--- @param id string|number Task ID or UUID
--- @return Result<boolean, Error> Result indicating success or an error
function M.delete(id)
	local result = TaskwarriorAdapter.delete_task(id)

	if result:is_err() then
		return result
	end

	return Result.Ok(true)
end

--- Set a task status (e.g., complete, cancel)
--- @param id string|number Task ID or UUID
--- @param status string New status
--- @return Result<Task, Error> Result containing the updated task or an error
function M.set_status(id, status)
	-- Validate status first
	local command
	if status == "done" then
		command = "done"
	-- Taskwarrior uses 'delete' command for cancelling/deleting via status change usually
	-- Using 'delete' might be too aggressive if 'canceled' is meant as a distinct status
	-- Let's assume 'delete' maps to removal for now. Adjust if 'canceled' is a real TW status you use.
	-- elseif status == "canceled" then
	--  command = "delete"
	elseif status == "pending" then
		command = "start" -- 'start' often uncompletes/starts a task
	else
		-- If not one of the direct commands, maybe it's a modifiable status like 'waiting'
		-- However, the validation check prevents arbitrary statuses currently.
		return Result.Err(Error.validation_error("Unsupported status for direct operation: " .. status))
	end

	-- Fetch task *after* validation
	local task_result = M.get_by_id(id)
	if task_result:is_err() then
		return task_result -- Return "Task not found" if get_by_id failed
	end

	-- Use the numeric ID from the fetched task for the command
	local numeric_id = task_result.value.id

	local result = TaskwarriorAdapter.execute_taskwarrior({ numeric_id, command }, { json = false })
	if result:is_err() then
		return result
	end

	-- Refetch the task by its ID to get the updated state
	return M.get_by_id(numeric_id)
end

--- Get tasks due in a date range
--- @param start_date string Start date (ISO format)
--- @param end_date string End date (ISO format)
--- @return Result<Task[], Error> Result containing tasks or an error
function M.get_due_in_range(start_date, end_date)
	local filter = {
		"due.after:" .. start_date,
		"due.before:" .. end_date,
	}
	return M.get_all(filter)
end

--- Get tasks with a specific tag
--- @param tag string Tag to filter by
--- @return Result<Task[], Error> Result containing tasks or an error
function M.get_by_tag(tag)
	return M.get_all("+" .. tag)
end

--- Get tasks for a specific project
--- @param project string Project name
--- @return Result<Task[], Error> Result containing tasks or an error
function M.get_by_project(project)
	return M.get_all("project:" .. project)
end

return M
