local M = {}

-- Available icon providers
local providers = {
  none = {
    name = "none",
    available = true,
    get_file_icon = function(filepath) return "  ", nil, false end,
    get_icon = function(type, name) return "  ", nil, false end
  },
  mini = {
    name = "mini.icons",
    available = false,
    module = nil,
    get_file_icon = function(filepath)
      local icon_str, hl_str, is_default = M.providers.mini.module.get('file', filepath)
      return icon_str or "  ", hl_str, is_default
    end,
    get_icon = function(type, name)
      local icon_str, hl_str, is_default = M.providers.mini.module.get(type, name)
      return icon_str or "  ", hl_str, is_default
    end
  },
  devicons = {
    name = "nvim-web-devicons",
    available = false,
    module = nil,
    get_file_icon = function(filepath)
      if not M.providers.devicons.module then
        return "  ", nil, false
      end
      local icon, hl = M.providers.devicons.module.get_icon(filepath)
      return icon or "  ", hl, false
    end,
    get_icon = function(type, name)
      -- For devicons, we can use the same file icon logic for project types
      if type == "file" then
        return M.providers.devicons.get_file_icon(name)
      end
      if type == "lsp" and name == "file" then
        return M.providers.devicons.get_file_icon("readme")
      end
      if type == "lsp" and name == "key" then
        return M.providers.devicons.get_file_icon("security")
      end
      return "  ", nil, false
    end
  }
}

M.providers = providers
M.active_provider = nil
M.config = { provider = "none" }

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

  -- Initialize the selected provider
  if M.config.provider == "mini" then
    local ok, mini_icons = pcall(require, 'mini.icons')
    if ok and mini_icons then
      providers.mini.available = true
      providers.mini.module = mini_icons
      M.active_provider = providers.mini
    else
      print("Spire: mini.icons not found, falling back to no icons")
      M.active_provider = providers.none
    end
  elseif M.config.provider == "devicons" then
    local ok, devicons = pcall(require, 'nvim-web-devicons')
    if ok and devicons then
      providers.devicons.available = true
      providers.devicons.module = devicons
      M.active_provider = providers.devicons
      -- Setup devicons (this loads the default configurations)
      devicons.setup()
    else
      print("Spire: nvim-web-devicons not found, falling back to no icons")
      M.active_provider = providers.none
    end
  else
    -- "none" or any other value
    M.active_provider = providers.none
  end
end

-- Check if icons are available
function M.has_icons()
  return M.active_provider and M.active_provider.name ~= "none"
end

-- Get icon for a file
function M.get_file_icon(filepath)
  if not M.active_provider then return "  ", nil, false end
  return M.active_provider.get_file_icon(filepath)
end

-- Get icon for specific types
function M.get_icon(type, name)
  if not M.active_provider then return "  ", nil, false end
  return M.active_provider.get_icon(type, name)
end

-- Initialize with default config
M.setup()

return M
