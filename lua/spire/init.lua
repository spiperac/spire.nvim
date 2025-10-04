local M = {}

-- Default configurations
local default_config = {
  prompt_location = "bottom", -- top
  icons = {
    provider = "none" -- "none", "mini", "devicons"
  },
  files = {
    hidden_files = true,
    ignore_list = {
      ".git",
      "*.pyc"
    },
    mappings = {
      open_vsplit = '<C-s>',
      open_split = '<C-h>'
    }
  },
  grep = {
    ignore_list = {
      ".git",
      "*.pyc"
    },
    mappings = {
      open_vsplit = '<C-s>',
      open_split = '<C-h>'
    }
  },
  buffers = {}
}

local config = vim.deepcopy(default_config)

M.setup = function(user_opts)
  config = vim.tbl_deep_extend("force", default_config, user_opts or {})

  -- Initialize icons with user configuration
  require('spire.icons').setup(config.icons)
end

M.files = function()
  return require('spire.files'):new(config, config.files)
end

M.buffers = function()
  return require('spire.buffers'):new(config, config.buffers or {})
end

M.grep = function(opts)
  local grep_config = config.grep or {}
  local merged = vim.tbl_deep_extend("force", grep_config, opts or {})
  return require('spire.grep'):new(config, merged)
end

M.projects = function(opts)
  local projects_config = config.projects or {}
  local merged = vim.tbl_deep_extend("force", projects_config, opts or {})
  return require('spire.projects'):new(config, merged)
end

-- Create commands (unchanged)
vim.api.nvim_create_user_command('SpireFiles', function()
  require('spire').files()
end, {})

vim.api.nvim_create_user_command('SpireBuffers', function()
  require('spire').buffers()
end, {})

vim.api.nvim_create_user_command('SpireGrep', function()
  require('spire').grep()
end, {})

vim.api.nvim_create_user_command('SpireProjects', function()
  require('spire').projects()
end, {})

return M
