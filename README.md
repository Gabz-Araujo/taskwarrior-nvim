# Taskwarrior.nvim

A Neovim plugin for seamless Taskwarrior integration.

## Features

- Create tasks from markdown checkboxes or TODO-style comments
- View and manage tasks with an interactive dashboard
- Browse tasks with fuzzy search via Telescope
- Track time with a Pomodoro timer
- Sync tasks between markdown documents and Taskwarrior
- Get an overview of project progress
- View tasks in a calendar

![Dashboard Screenshot](screenshots/dashboard.png)

## Requirements

- Neovim >= 0.7.0
- [Taskwarrior](https://taskwarrior.org)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for async operations)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for task browsing)

## Installation

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'yourusername/taskwarrior.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim', -- optional
  },
  config = function()
    require('taskwarrior').setup({
      -- Your configuration options here
    })
  end
}
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'yourusername/taskwarrior.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim', -- optional
  },
  config = function()
    require('taskwarrior').setup({
      -- Your configuration options here
    })
  end
}
```

## Configuration

Default configuration:

```lua
require('taskwarrior').setup({
  tags = { "TODO", "HACK", "NOTE", "PERF", "TEST", "WARN" },
  keymaps = {
    dashboard = "<leader>tkb",
    browse = "<leader>tkt",
    create_from_comment = "<leader>tkk",
    create_from_markdown = "<leader>tki",
    mark_done = "<leader>tkd",
    goto_task = "<leader>tkg",
    priority = "<leader>tkp",
    due_date = "<leader>tku",
    sync = "<leader>tks",
    pomodoro = "<leader>tkm",
    calendar = "<leader>tkc",
    project = "<leader>tkj"
  },
  auto_sync = false,
  default_priority = "M",
  default_tags = {},
  statusline = {
    enabled = true,
    format = "Tasks: %count% (%urgent% urgent)"
  },
  integrations = {
    telescope = true,
    markdown = true
  }
})
```

## Usage

### Creating Tasks

- From markdown checkbox: Place cursor on a checkbox line (`- [ ] Task`) and press `<leader>tki` or use `:TaskCreate`
- From TODO comment: Place cursor on a line with a TODO marker and press `<leader>tkk` or use `:TaskCreateFromComment`

### Managing Tasks

- Open the dashboard: Press `<leader>tkb` or use `:TaskDashboard`
- Browse tasks: Press `<leader>tkt` or use `:TaskBrowse`
- Mark task as done: Press `<leader>tkd` or use `:TaskComplete`
- Set task priority: Press `<leader>tkp` or use `:TaskSetPriority`
- Set due date: Press `<leader>tku` or use `:TaskSetDue`
- Start Pomodoro timer: Press `<leader>tkm` or use `:TaskPomodoro`

### Sync and Import

- Sync markdown with Taskwarrior: Press `<leader>tks` or use `:TaskSync`
- Import tasks from Taskwarrior: Use `:TaskImport [filter]`

## Markdown Integration

Taskwarrior.nvim can synchronize tasks between markdown files and Taskwarrior.

Markdown task format:

```
- [ ] Task description [Priority: H] [Due: 2023-07-15] (ID: 123)
```

When a task is created or synced:

- Checkbox status reflects task status in Taskwarrior
- Metadata (Priority, Due date, etc.) is kept in sync
- Task ID links the markdown item to Taskwarrior

Auto-sync can be enabled in configuration.

## Commands

| Command                  | Description                             |
| ------------------------ | --------------------------------------- |
| `:TaskDashboard`         | Open the task dashboard                 |
| `:TaskBrowse`            | Browse tasks with telescope             |
| `:TaskCreate`            | Create task from markdown checkbox      |
| `:TaskCreateFromComment` | Create task from TODO comment           |
| `:TaskComplete`          | Mark the current task as done           |
| `:TaskSync`              | Sync markdown document with Taskwarrior |
| `:TaskCalendar`          | Show task calendar                      |
| `:TaskProject`           | Show project summary                    |
| `:TaskPomodoro`          | Start a pomodoro timer for a task       |
| `:TaskImport [filter]`   | Import tasks from Taskwarrior           |
| `:TaskSetPriority`       | Set task priority                       |
| `:TaskSetDue`            | Set task due date                       |

## Status Line Integration

You can add task information to your status line:

### For lualine.nvim

```lua
require('lualine').setup({
  sections = {
    lualine_c = {
      -- Your other components
      { require('taskwarrior.integrations.statusline').lualine }
    }
  }
})
```

### For custom status lines

```lua
function MyStatusLine()
  local tasks = require('taskwarrior.integrations.statusline').get_statusline()
  -- Your other status line components
  return "MyStatusLine " .. tasks
end

vim.o.statusline = '%!v:lua.MyStatusLine()'
```

## Troubleshooting

Run `:checkhealth taskwarrior` to diagnose common issues.

## License

MIT
