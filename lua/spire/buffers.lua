local SpireBufferPicker = {}
local BasePicker = require('spire.picker')
local SpireBufferPicker = setmetatable({}, { __index = BasePicker })
SpireBufferPicker.__index = SpireBufferPicker

-- Icon utility
local icons = require('spire.icons')

function SpireBufferPicker:new(opts)
  opts = opts or {}
  if active then active:close() end

  local o = BasePicker:new(opts)
  setmetatable(o, SpireBufferPicker)

  o.width = opts.width or 80
  o.prompt_height = 1
  o.res_height = opts.res_height or 15
  o.title = "Buffers"
  o.prompt_text = opts.prompt_text or "> "
  o.search_term = ""
  o.results = {}
  o.selected_index = 1
  o.mappings = opts.mappings or {}
  o.current_buf = vim.api.nvim_get_current_buf()

  o:create_windows()
  o:setup_keymaps()
  o:setup_autocmds()
  o:perform_search("")

  active = o
  return o
end

function SpireBufferPicker:setup_keymaps()
  vim.keymap.set("i", "<C-k>", function() self:select_prev() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<C-j>", function() self:select_next() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<CR>", function() self:open_selected() end, { buffer = self.prompt_buf })
end

function SpireBufferPicker:setup_autocmds()
  self.prompt_autocmd = vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = self.prompt_buf,
    callback = function() self:on_input_change() end
  })
end

function SpireBufferPicker:on_input_change()
  local content = vim.api.nvim_buf_get_lines(self.prompt_buf, 0, -1, false)
  local new_search = table.concat(content, ""):gsub("^" .. self.prompt_text, "")
  if new_search ~= self.search_term then
    self.search_term = new_search
    self:perform_search()
  end
end

function SpireBufferPicker:perform_search()
  local buffers = vim.api.nvim_list_bufs()
  local results = {}
  local current_buf_index = 1

  local modified_icon = icons.has_icons() and icons.get_icon('lsp', 'file') or "[+]"
  local readonly_icon = icons.has_icons() and icons.get_icon('lsp', 'key') or "[RO]"

  for _, bufnr in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" and not name:match("://") then
        local modified = vim.api.nvim_buf_get_option(bufnr, "modified") and modified_icon or ""
        local readonly = vim.api.nvim_buf_get_option(bufnr, "readonly") and readonly_icon or ""
        local flags = modified .. readonly
        local display_name = vim.fn.fnamemodify(name, ":~:.")

        if #self.search_term == 0 or display_name:lower():find(self.search_term:lower(), 1, true) then
          local result = { bufnr = bufnr, display_name = display_name, name = name, flags = flags }
          table.insert(results, result)

          if bufnr == self.current_buf then
            current_buf_index = #results
          end
        end
      end
    end
  end

  self.results = results
  self.selected_index = current_buf_index
  self:update_results()
end

function SpireBufferPicker:update_results()
  if not vim.api.nvim_buf_is_valid(self.res_buf) then return end

  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", true)

  local display_lines = {}
  local ns = vim.api.nvim_create_namespace("spire_highlights")
  vim.api.nvim_buf_clear_namespace(self.res_buf, ns, 0, -1)

  for i, result in ipairs(self.results) do
    local icon = "  "
    if icons.has_icons() then
      local icon_str, hl_str, is_default = icons.get_file_icon(result.name)
      icon = icon_str or "  "
    end

    local prefix = (i == self.selected_index) and "❯ " or "  "
    local prefix_width = vim.fn.strdisplaywidth(prefix)
    local icon_width = vim.fn.strdisplaywidth(icon)
    local name_width = vim.fn.strdisplaywidth(result.display_name)
    local flags_width = vim.fn.strdisplaywidth(result.flags)
    local padding = string.rep(" ", math.max(1, self.width - prefix_width - icon_width - name_width - flags_width - 2))
    local display = prefix .. icon .. " " .. result.display_name .. padding .. result.flags .. " "
    result.display_text = display
    table.insert(display_lines, display)
  end

  if #display_lines == 0 then
    display_lines = { "No buffers found" }
  end

  vim.api.nvim_buf_set_lines(self.res_buf, 0, -1, false, display_lines)

  for i, result in ipairs(self.results) do
    local prefix = (i == self.selected_index) and "❯ " or "  "
    local prefix_len = #prefix

    if icons.has_icons() then
      local icon_str, hl_str, is_default = icons.get_file_icon(result.name)
      if hl_str then
        vim.api.nvim_buf_add_highlight(self.res_buf, ns, hl_str, i - 1, prefix_len, prefix_len + #icon_str)
      end
    end

    if result.flags ~= "" then
      local flag_start = #result.display_text - #result.flags - 1
      vim.api.nvim_buf_add_highlight(self.res_buf, ns, "WarningMsg", i - 1, flag_start, -1)
    end

    if i == self.selected_index then
      vim.api.nvim_buf_add_highlight(self.res_buf, ns, "Visual", i - 1, 0, -1)
    end
  end

  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", false)
  vim.api.nvim_win_set_cursor(self.res_win, { math.min(self.selected_index, #display_lines), 0 })

  local title = #self.results == 0 and self.title or
      string.format("%s (%d/%d)", self.title, self.selected_index, #self.results)
  vim.api.nvim_win_set_config(self.prompt_win, { title = title })
end

function SpireBufferPicker:select_next()
  if #self.results == 0 then return end
  if self.selected_index == #self.results then
    self.selected_index = 1
  else
    self.selected_index = self.selected_index + 1
  end
  self:update_results()
end

function SpireBufferPicker:select_prev()
  if #self.results == 0 then return end
  self.selected_index = self.selected_index - 1
  if self.selected_index < 1 then
    self.selected_index = #self.results
  end
  self:update_results()
end

function SpireBufferPicker:open_selected()
  if #self.results == 0 or not self.results[self.selected_index] then return end
  local bufnr = self.results[self.selected_index].bufnr
  self:close()
  vim.api.nvim_set_current_buf(bufnr)
end

function SpireBufferPicker:close()
  pcall(vim.api.nvim_del_autocmd, self.prompt_autocmd)
  require('spire.picker').close(self)
end

return SpireBufferPicker
