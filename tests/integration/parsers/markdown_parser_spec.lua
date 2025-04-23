---@diagnostic disable: undefined-global
local mock = require("tests.helpers.mock")
local mock_modules = require("tests.helpers.mock_modules")

-- Mock modules before requiring the parser
mock_modules.mock_result()
mock_modules.mock_error()

local parse_markdown = require("taskwarrior.infrastructure.parsers.markdown_parser")

describe("Markdown parser", function()
	after_each(function()
		mock.restore_all()
		mock_modules.reset_all()
	end)

	it("returns nil for non-checkbox lines", function()
		local test_lines = {
			"# Regular heading",
			"Normal paragraph text",
			"- Regular list item",
		}

		for i, line in ipairs(test_lines) do
			mock.current_line(line, i)
			assert.is_nil(parse_markdown())
		end
	end)

	it("parses a basic unchecked task", function()
		mock.current_line("- [ ] Basic task", 1)
		mock.buf_lines({ "- [ ] Basic task" })

		local task = parse_markdown()

		if task == nil then
			return false
		end

		assert.equal("Basic task", task.description)
		assert.equal("pending", task.status)
		assert.equal(false, task.checked)
	end)

	it("parses a completed task", function()
		mock.current_line("- [x] Completed task", 1)
		mock.buf_lines({ "- [x] Completed task" })

		local task = parse_markdown()

		if task == nil then
			return false
		end

		assert.is_not_nil(task)
		assert.equal("Completed task", task.description)
		assert.equal("done", task.status)
		assert.equal(true, task.checked)
	end)

	it("parses tasks with all statuses", function()
		local statuses = {
			{ checkbox = "[x]", status = "done", description = "Completed task" },
			{ checkbox = "[u]", status = "undone", description = "Undone task" },
			{ checkbox = "[ ]", status = "pending", description = "Pending task" },
			{ checkbox = "[-]", status = "on-hold", description = "On-hold task" },
			{ checkbox = "[c]", status = "canceled", description = "Canceled task" },
			{ checkbox = "[r]", status = "recurring", description = "Recurring task" },
			{ checkbox = "[!]", status = "important", description = "Important task" },
		}

		for _, test_case in ipairs(statuses) do
			mock.current_line("- " .. test_case.checkbox .. " " .. test_case.description, 1)
			mock.buf_lines({ "- " .. test_case.checkbox .. " " .. test_case.description })

			local task = parse_markdown()

			if task == nil then
				return false
			end

			assert.is_not_nil(task)
			assert.equal(test_case.description, task.description)
			assert.equal(test_case.status, task.status)
			assert.equal(test_case.status == "done", task.checked)
		end
	end)

	it("extracts task metadata", function()
		mock.current_line("- [ ] Task with metadata [Priority: H] [Due: 2023-12-31] (ID: 123)", 1)
		mock.buf_lines({ "- [ ] Task with metadata [Priority: H] [Due: 2023-12-31] (ID: 123)" })

		local task = parse_markdown()

		if task == nil then
			return false
		end

		assert.equal("Task with metadata", task.description)
		assert.equal("H", task.priority)
		assert.equal("2023-12-31", task.due)
		assert.equal(123, task.id)
	end)

	it("processes continuation lines", function()
		mock.current_line("- [ ] First line", 1)
		mock.buf_lines({
			"- [ ] First line",
			"   Second line [Due: 2023-12-31] (ID: 123)",
			"   Third line [Priority: H]",
			"- [ ] Next task", -- Should not include this
		})

		local task = parse_markdown()

		if task == nil then
			return false
		end

		assert.equal("First line Second line Third line", task.description)
		assert.equal(2, task.continuation_lines)
		assert.equal("2023-12-31", task.due)
		assert.equal("H", task.priority)
		assert.equal(123, task.id)
	end)

	it("parses the task when not on the first line on task", function()
		mock.current_line("   Second line [Due: 2023-12-31] (ID: 123)", 2)
		mock.buf_lines({
			"- [ ] First line",
			"   Second line [Due: 2023-12-31] (ID: 123)",
			"   Third line [Priority: H]",
			"- [ ] Next task", -- Should not include this
		})

		local task = parse_markdown()

		if task == nil then
			return false
		end

		assert.equal("First line Second line Third line", task.description)
		assert.equal(2, task.continuation_lines)
		assert.equal("2023-12-31", task.due)
		assert.equal("H", task.priority)
		assert.equal(123, task.id)
	end)

	it("extracts project from headings", function()
		mock.current_line("- [ ] Task in project", 4)
		mock.buf_lines({
			"# Main Project",
			"## Subproject",
			"Some text",
			"- [ ] Task in project",
		})

		local task = parse_markdown()

		if task == nil then
			return false
		end

		assert.equal("Subproject", task.project)
		assert.equal("Main Project", task.uda["Area"])
	end)
end)
