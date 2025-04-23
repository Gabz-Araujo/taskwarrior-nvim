-- tests/minimal_init.lua
-- Create minimal configuration
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=]])

-- Add the current directory to runtimepath
local project_root = vim.fn.getcwd()
vim.opt.runtimepath:append(project_root)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Add the tests directory to package path
package.path = project_root .. "/tests/?.lua;" .. package.path
package.path = project_root .. "/?.lua;" .. package.path

-- Set up plenary
local plenary_path = project_root .. "/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
	vim.fn.system({ "git", "clone", "https://github.com/nvim-lua/plenary.nvim", plenary_path })
end

vim.opt.runtimepath:append(plenary_path)
