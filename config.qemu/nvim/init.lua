-- Suppress all deprecation warnings
vim.deprecate = function() end

-- Set <space> as the leader key
-- NOTE: Must be set before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Install lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  print("Installing lazy.nvim...")
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  print("Lazy.nvim installed!")
end
vim.opt.rtp:prepend(lazypath)

-- Verify lazy.nvim loaded
local ok, lazy = pcall(require, "lazy")
if not ok then
  print("ERROR: lazy.nvim failed to load!")
  return
end

-- Set basic options
vim.wo.number = true
vim.wo.relativenumber = true
vim.opt.termguicolors = true -- Enable true color support

-- Force line number colors after any colorscheme is loaded
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    -- User reports LineNr is the current line, so make it brightest
    vim.api.nvim_set_hl(0, "LineNr", { fg = "#E0E0E0" })
    vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#E0E0E0" })

    -- Set other lines to be dimmer
    vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#A0A0A0" })
    vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#A0A0A0" })
  end,
})

-- Load plugins from lua/plugins.lua
lazy.setup("plugins", {
  install = {
    missing = true,
  },
  checker = {
    enabled = false,
  },
  change_detection = {
    enabled = false,
  },
})
