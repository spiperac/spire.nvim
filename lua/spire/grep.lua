local SpirePickerGrep = {}
local BasePicker = require('spire.picker')
local SpirePickerGrep = setmetatable({}, { __index = BasePicker })
SpirePickerGrep.__index = SpirePickerGrep

-- Preview highlight
vim.cmd("highlight PreviewMatch guifg=#ff6b6b gui=bold")

-- Icon utility
local icons = require('spire.icons')

function SpirePickerGrep:new(opts)
  opts = opts or {}
  if active then active:close() end

  local o = BasePicker:new(opts)
  setmetatable(o, SpirePickerGrep)
  o.width = opts.width or 150
  o.prompt_height = 1
  o.res_height = opts.res_height or 15
  o.title = "Search"
  o.prompt_text = opts.grep.prompt_text or "> "
  o.hidden_files = opts.grep.hidden_files or false
  o.search_term = ""
  o.results = {}
  o.selected_index = 1
  o.mappings = opts.grep.mappings or {}
  o.ignore_list = opts.grep.ignore_list or {}
  o.ignore_patterns = o.ignore_list[1] and table.concat(vim.tbl_map(function(p) return '--glob=!' .. p end, o.ignore_list), ' ') or ''

  o:create_windows_preview()
  o:setup_keymaps()
  o:setup_autocmds()
  o:perform_search("")

  active = o
  return o
end

function SpirePickerGrep:setup_keymaps()
  vim.keymap.set("i", "<C-k>", function() self:select_prev() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<C-j>", function() self:select_next() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<CR>", function() self:open_selected() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<A-h>", function() self:toggle_hidden_files() end, { buffer = self.prompt_buf })
  
  if self.mappings and self.mappings.open_vsplit then
    vim.keymap.set("i", self.mappings.open_vsplit, function() self:open_vsplit() end, { buffer = self.prompt_buf })
  end
  if self.mappings and self.mappings.open_split then
    vim.keymap.set("i", self.mappings.open_split, function() self:open_split() end, { buffer = self.prompt_buf })
  end
end

function SpirePickerGrep:toggle_hidden_files()
  self.hidden_files = not self.hidden_files
  self:perform_search()
end

function SpirePickerGrep:setup_autocmds()
  self.prompt_autocmd = vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = self.prompt_buf,
    callback = function() self:on_input_change() end
  })
end

function SpirePickerGrep:on_input_change()
  local content = vim.api.nvim_buf_get_lines(self.prompt_buf, 0, -1, false)
  local new_search = table.concat(content, ""):gsub("^" .. self.prompt_text, "")

  if new_search ~= self.search_term then
    self.search_term = new_search
    self:debounced_search()
  end
end

function SpirePickerGrep:debounced_search()
  if self.search_timer then
    vim.fn.timer_stop(self.search_timer)
  end

  self.search_timer = vim.fn.timer_start(100, function()
    self:perform_search()
  end)
end

function SpirePickerGrep:perform_search(force_search)
  local search_term = force_search or self.search_term

  if #search_term == 0 then
    self.results = {}
    self:update_results()
    self:update_preview()
    return
  elseif #search_term >= 2 then -- Tweak, but 2 is optimal
    -- self.results = {}
  
    local cmd = {'rg', '--line-number', '--no-heading', '--color=never', '--smart-case'}
    if self.hidden_files then
      table.insert(cmd, '--hidden')
    end
    for _, pattern in ipairs(self.ignore_list) do
      table.insert(cmd, '--glob=!' .. pattern)
    end
    table.insert(cmd, search_term)
    table.insert(cmd, '.')

    local this = self
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        this.results = vim.tbl_filter(function(line)
          return line ~= "" and line ~= nil
        end, data or {})
        this.selected_index = 1
        vim.schedule(function()
          this:update_results()
          this:update_preview()
        end)
      end,
      -- on_stderr = function(_, data)
      --   print("Stderr data:", vim.inspect(data))
      -- end,
      -- on_exit = function(_, code)
      --   print("Job exited with code:", code)
      -- end
    })
  end
end

function SpirePickerGrep:update_results()
  if not vim.api.nvim_buf_is_valid(self.res_buf) then return end

  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", true)

  local display_lines = {}
  for i, result in ipairs(self.results) do
    if result ~= "" then
      local icon = "  "
      if icons.has_icons() then
        local file = result:match("([^:]+):") or ""
        local icon_str, hl_str, is_default = icons.get_file_icon(file)
        icon = icon_str or "  "
      end

      local prefix = (i == self.selected_index) and "❯ " or "  "
      -- Shorten long results for display
      local display_result = result:match("^([^:]+:[^:]+):") or result
      table.insert(display_lines, prefix .. icon .. " " .. display_result)
    end
  end

  if #display_lines == 0 then
    display_lines = { "No results found" }
  end

  vim.api.nvim_buf_set_lines(self.res_buf, 0, -1, false, display_lines)

  -- Highlights
  local ns = vim.api.nvim_create_namespace("spire_grep_highlights")
  vim.api.nvim_buf_clear_namespace(self.res_buf, ns, 0, -1)

  for i, result in ipairs(self.results) do
    if result ~= "" then
      local prefix = (i == self.selected_index) and "❯ " or "  "
      local prefix_len = #prefix
      local icon_len = icons.has_icons() and 2 or 0

      -- Icon highlighting
      if icons.has_icons() then
        local file = result:match("([^:]+):") or ""
        local icon_str, hl_str, is_default = icons.get_file_icon(file)
        if hl_str then
          vim.api.nvim_buf_add_highlight(self.res_buf, ns, hl_str, i - 1, prefix_len, prefix_len + icon_len)
        end
      end

      -- Matching file highlight
      if i == self.selected_index then
        vim.api.nvim_buf_add_highlight(self.res_buf, ns, "Visual", i - 1, 0, -1)
      end
    end
  end

  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", false)
  vim.api.nvim_win_set_cursor(self.res_win, { math.min(self.selected_index, #display_lines), 0 })

  -- Set matched count
  local title
  if #self.results == 0 then
    title = self.title
  else
    title = string.format("%s (%d/%d)", self.title, self.selected_index, #self.results)
  end

  vim.api.nvim_win_set_config(self.prompt_win, {
    title = title,
  })
end

function SpirePickerGrep:update_preview()
  if not self.preview_buf or not vim.api.nvim_buf_is_valid(self.preview_buf) then return end

  vim.api.nvim_buf_set_option(self.preview_buf, "modifiable", true)

  if #self.results == 0 or not self.results[self.selected_index] then
    vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, { "No preview available" })
    vim.api.nvim_buf_set_option(self.preview_buf, "modifiable", false)
    return
  end

  local result = self.results[self.selected_index]
  local file, line_num = result:match("^([^:]+):(%d+):")

  if file and line_num then
    local line = tonumber(line_num)
    local preview_lines = {}

    local ok, file_lines = pcall(vim.fn.readfile, file)

    -- Use basic syntax, no LSP
    local ft = vim.filetype.match({ filename = file })
    vim.api.nvim_buf_set_option(self.preview_buf, "syntax", ft or "")

    if ok and file_lines then
      local start = math.max(1, line - 10)
      local finish = math.min(#file_lines, line + 10)
      for i = start, finish do
        table.insert(preview_lines, file_lines[i])
      end

      vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, preview_lines)

      if #preview_lines > 0 then
        local match_line_in_preview = line - start + 1
        local center_line = math.min(math.floor(#preview_lines / 2), #preview_lines)
        vim.api.nvim_win_set_cursor(self.preview_win, { center_line, 0 })
        vim.api.nvim_buf_add_highlight(self.preview_buf, -1, "PreviewMatch", match_line_in_preview - 1, 0, -1)
      end
    else
      vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, { "Failed to read: " .. file })
    end
  else
    vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, { "Invalid result format" })
  end

  vim.api.nvim_buf_set_option(self.preview_buf, "modifiable", false)
end

function SpirePickerGrep:select_next()
  if #self.results == 0 then return end
  self.selected_index = (self.selected_index % #self.results) + 1
  self:update_results()
  self:update_preview()
end

function SpirePickerGrep:select_prev()
  if #self.results == 0 then return end
  self.selected_index = self.selected_index - 1
  if self.selected_index < 1 then
    self.selected_index = #self.results
  end
  self:update_results()
  self:update_preview()
end

function SpirePickerGrep:open_selected()
  if #self.results == 0 or not self.results[self.selected_index] then
    vim.api.nvim_echo({ { "No result to open", "WarningMsg" } }, true, {})
    return
  end

  local result = self.results[self.selected_index]
  local file, line = result:match("^([^:]+):(%d+):")

  if file and line then
    self:close()
    -- Switch to normal mode before opening
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    vim.cmd("edit +" .. line .. " " .. vim.fn.fnameescape(file))
  end
end

function SpirePickerGrep:open_vsplit()
  if #self.results == 0 or not self.results[self.selected_index] then return end

  local result = self.results[self.selected_index]
  local file, line = result:match("^([^:]+):(%d+):")

  if file and line then
    self:close()
    -- Switch to normal mode before opening
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    vim.cmd("vsplit +" .. line .. " " .. vim.fn.fnameescape(file))
  end
end

function SpirePickerGrep:open_split()
  if #self.results == 0 or not self.results[self.selected_index] then return end

  local result = self.results[self.selected_index]
  local file, line = result:match("^([^:]+):(%d+):")

  if file and line then
    self:close()
    -- Switch to normal mode before opening
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    vim.cmd("split +" .. line .. " " .. vim.fn.fnameescape(file))
  end
end

function SpirePickerGrep:close()
  self.results = nil
  pcall(vim.api.nvim_del_autocmd, self.prompt_autocmd)
  if self.search_timer then
    vim.fn.timer_stop(self.search_timer)
  end
  require('spire.picker').close(self)
end

return SpirePickerGrep
