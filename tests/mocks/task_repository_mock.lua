local TaskRepository = {}

TaskRepository.get_by_id = function(id)
	-- Default mock implementation
	return Result.Err({ message = "Mock TaskRepository: get_by_id not implemented for " .. tostring(id) })
end

TaskRepository.get_all = function()
	-- Default mock implementation
	return Result.Err({ message = "Mock TaskRepository: get_all not implemented" })
end

TaskRepository.save = function(task)
	-- Default mock implementation
	return Result.Err({ message = "Mock TaskRepository: save not implemented for " .. task.description })
end

TaskRepository.delete = function(id)
	-- Default mock implementation
	return Result.Err({ message = "Mock TaskRepository: delete not implemented for id " .. tostring(id) })
end

TaskRepository.set_status = function(id, status)
	return Result.Err({
		message = "Mock TaskRepository: set_status not implemented for id " .. tostring(id) .. " status " .. status,
	})
end

return TaskRepository
