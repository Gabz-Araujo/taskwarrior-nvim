-- tests/helpers/fixtures.lua
---@class TestFixtures
local fixtures = {}

-- Task JSON sample (Taskwarrior export format)
fixtures.task_json = {
	id = 42,
	uuid = "123e4567-e89b-12d3-a456-426614174000",
	description = "Implement TDD for taskwarrior.nvim",
	status = "pending",
	priority = "H",
	tags = { "test", "neovim" },
	project = "taskwarrior.nvim",
	annotations = {
		{ description = "First annotation", entry = "20231001T120000Z" },
	},
}

-- Markdown task samples
fixtures.markdown_lines = {
	"# Project",
	"## Subproject",
	"- [ ] Basic task",
	"- [x] Completed task #done",
	"- [ ] Complex task with metadata [Priority: H] [Due: 2023-12-31]",
	"  Continuation line (ID: 42)",
}

-- Comment task samples
fixtures.comment_lines = {
	"// Regular comment",
	"// TODO: Implement test framework",
	"//   This is a continuation line",
	"// HACK: Fix this later",
}

return fixtures
