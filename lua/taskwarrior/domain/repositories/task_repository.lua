--- @class TaskRepository
--- @field get_by_id fun(id: string): Result<Task, Error> Get a task by its ID or UUID
--- @field get_all fun(filter?: table): Result<Task[], Error> Get all tasks matching a filter
--- @field save fun(task: Task): Result<Task, Error> Save a task (create if new, update if existing)
--- @field delete fun(id: string): Result<boolean, Error> Delete a task by its ID or UUID

local TaskRepository = {}

return TaskRepository
