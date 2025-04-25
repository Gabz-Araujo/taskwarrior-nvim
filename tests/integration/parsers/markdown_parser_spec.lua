---@diagnostic disable: undefined-global, need-check-nil
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
			mock.buffer_reader({ current_line = line, current_line_number = i, lines = test_lines })
			local result = parse_markdown()
			assert.is_true(result:is_ok())
			assert.is_nil(result.value[1])
		end
	end)

	it("parses a basic unchecked task", function()
		local line = "- [ ] Basic task"
		mock.buffer_reader({ current_line = line, current_line_number = 1, lines = { line } })
		local result = parse_markdown()

		assert.is_true(result:is_ok())

		local task = result.value
		assert.equal("Basic task", task.description)
		assert.equal("pending", task.status)
		assert.equal(false, task.checked)
	end)

	it("parses a completed task", function()
		local line = "- [x] Completed task"
		mock.buffer_reader({ current_line = line, current_line_number = 1, lines = { line } })
		local result = parse_markdown()

		assert.is_true(result:is_ok())

		local task = result.value

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
			local line = "- " .. test_case.checkbox .. " " .. test_case.description
			mock.buffer_reader({ current_line = line, current_line_number = 1, lines = { line } })

			local result = parse_markdown()
			assert.is_true(result:is_ok())
			local task = result.value

			assert.is_not_nil(task)
			assert.equal(test_case.description, task.description)
			assert.equal(test_case.status, task.status)
			assert.equal(test_case.status == "done", task.checked)
		end
	end)

	it("extracts task metadata", function()
		local line = "- [ ] Task with metadata [Priority: H] [Due: 2023-12-31] (ID: 123)"
		mock.buffer_reader({ current_line = line, current_line_number = 1, lines = { line } })

		local result = parse_markdown()

		assert.is_true(result:is_ok())

		local task = result.value

		assert.equal("Task with metadata", task.description)
		assert.equal("H", task.priority)
		assert.equal("2023-12-31", task.due)
		assert.equal(123, task.id)
	end)

	it("processes continuation lines", function()
		local lines = {
			"- [ ] First line",
			"   Second line [Due: 2023-12-31] (ID: 123)",
			"   Third line [Priority: H]",
			"- [ ] Next task", -- Should not include this
		}

		mock.buffer_reader({ current_line = lines[4], current_line_number = 1, lines = lines })
		local result = parse_markdown()
		assert.is_true(result:is_ok())

		local task = result.value

		assert.equal("First line Second line Third line", task.description)
		assert.equal(2, task.continuation_lines)
		assert.equal("2023-12-31", task.due) -- You'll need to handle date parsing correctly for this test.
		assert.equal("H", task.priority) -- You'll need to handle priority parsing correctly for this test.
		assert.equal(123, task.id) -- You'll need to handle id parsing correctly for this test.
	end)

	it("parses the task when not on the first line on task", function()
		local lines = {
			"- [ ] First line",
			"   Second line [Due: 2023-12-31] (ID: 123)",
			"   Third line [Priority: H]",
			"- [ ] Next task", -- Should not include this
		}
		local mock_reader =
			mock.buffer_reader({ current_line = lines[2], current_line_number = 2, lines = lines, line_count = #lines })
		local result = parse_markdown(mock_reader)
		assert.is_true(result:is_ok())
		local task = result.value

		assert.equal("First line Second line Third line", task.description)
		assert.equal(2, task.continuation_lines)
		-- assert.equal("2023-12-31", task.due)
		-- assert.equal("H", task.priority)
		-- assert.equal(123, task.id)
	end)

	it("extracts project from headings", function()
		local lines = {
			"# Main Project",
			"## Subproject",
			"Some text",
			"- [ ] Task in project",
		}

		mock.buffer_reader({ current_line = lines[4], current_line_number = 4, lines = lines, line_count = #lines })

		local result = parse_markdown()
		assert.is_true(result:is_ok())
		local task = result.value

		assert.equal("Subproject", task.project)
		assert.equal("Main Project", task.uda["Area"])
	end)
end)
