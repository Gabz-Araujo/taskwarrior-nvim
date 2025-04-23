---@diagnostic disable: undefined-global
local fixtures = require("tests.helpers.fixtures")
local mock_modules = require("tests.helpers.mock_modules")

-- Mock the Result and Error modules before loading Task
mock_modules.mock_result()
mock_modules.mock_error()

local Task = require("taskwarrior.domain.entities.task") -- Helper function to mock the Error module before Task is loaded
local function setup_error_mock()
	package.loaded["taskwarrior.utils.error"] = {
		handle_error = function() end,
		validation_error = function()
			return {}
		end,
		create_error = function()
			return {}
		end,
	}
end

-- Reset the Error module after tests
local function reset_error_mock()
	package.loaded["taskwarrior.utils.error"] = nil
end

describe("Task entity", function()
	before_each(function()
		setup_error_mock()
	end)

	after_each(function()
		reset_error_mock()
		mock_modules.reset_all()
	end)

	it("creates a new task with defaults", function()
		local task, err = Task.new({ description = "Test task" })

		assert.is_nil(err)
		assert.equal("Test task", task.description)
		assert.same({}, task.tags)
		assert.same({}, task.annotations)
		assert.same({}, task.uda)
		assert.is_nil(task.priority)
	end)

	it("creates a task from taskwarrior JSON", function()
		local task = Task.from_taskwarrior_json(fixtures.task_json)

		assert.equal(42, task.id)
		assert.equal("123e4567-e89b-12d3-a456-426614174000", task.uuid)
		assert.equal("Implement TDD for taskwarrior.nvim", task.description)
		assert.equal("H", task.priority)
		assert.same({ "test", "neovim" }, task.tags)
	end)

	it("converts to command arguments", function()
		local task, err = Task.new({
			description = "Task with arguments",
			priority = "H",
			project = "test.project",
			tags = { "tag1", "tag2" },
		})

		assert.is_nil(err)
		local args = task:to_command_args()

		-- Check for required arguments
		assert.truthy(vim.tbl_contains(args, 'description:"Task with arguments"'))
		assert.truthy(vim.tbl_contains(args, "priority:H"))
		assert.truthy(vim.tbl_contains(args, 'project:"test.project"'))
		assert.truthy(vim.tbl_contains(args, "+tag1"))
		assert.truthy(vim.tbl_contains(args, "+tag2"))
	end)

	it("converts to markdown format", function()
		local task, err = Task.new({
			description = "Markdown task",
			priority = "H",
			due = "2023-12-31",
			status = "pending",
			id = 42,
			tags = { "tag1", "tag2" },
		})

		local markdown = task:to_markdown(true)

		assert.is_nil(err)
		assert.matches("^%- %[ %] Markdown task", markdown)
		assert.matches("%[Priority: H%]", markdown)
		assert.matches("%[Due: 2023%-12%-31%]", markdown)
		assert.matches("#tag1", markdown)
		assert.matches("#tag2", markdown)
		assert.matches("%[ID%]%(ID: 42%)", markdown)
	end)

	it("checks status correctly", function()
		local task1, err1 = Task.new({ status = "pending" })
		local task2, err2 = Task.new({ status = "done" })

		assert.is_nil(err1)
		assert.is_nil(err2)
		assert.is_false(task1:is_completed())
		assert.is_true(task2:is_completed())
	end)

	it("manages tags correctly", function()
		local task, err = Task.new({ tags = { "initial" } })

		assert.is_nil(err)
		assert.is_true(task:has_tag("initial"))
		assert.is_false(task:has_tag("nonexistent"))

		-- Add tag
		assert.is_true(task:add_tag("new_tag"))
		assert.is_true(task:has_tag("new_tag"))

		-- Adding the same tag again should return false
		assert.is_false(task:add_tag("new_tag"))

		-- Remove tag
		assert.is_true(task:remove_tag("initial"))
		assert.is_false(task:has_tag("initial"))
	end)

	it("manages UDAs correctly", function()
		local task, err = Task.new()

		assert.is_nil(err)
		assert.is_nil(task:get_uda("custom"))

		task:set_uda("custom", "value")
		assert.equal("value", task:get_uda("custom"))

		task:set_uda("custom", nil) -- Remove UDA
		assert.is_nil(task:get_uda("custom"))
	end)

	it("detects differences between tasks", function()
		local task1, err1 = Task.new({
			description = "Original",
			priority = "M",
			tags = { "tag1", "tag2" },
		})

		assert.is_nil(err1)

		local task2, err2 = Task.new({
			description = "Modified",
			priority = "H",
			tags = { "tag2", "tag3" },
		})

		assert.is_nil(err2)

		diff = task1:diff(task2)

		assert.equal("Original", diff.description.old)
		assert.equal("Modified", diff.description.new)
		assert.equal("M", diff.priority.old)
		assert.equal("H", diff.priority.new)
		assert.same({ "tag3" }, diff.tags.added)
		assert.same({ "tag1" }, diff.tags.removed)
	end)
end)
