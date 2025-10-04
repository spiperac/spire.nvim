local SpirePickerFiles = {}
local BasePicker = require('spire.picker')
local SpirePickerFiles = setmetatable({}, { __index = BasePicker })
SpirePickerFiles.__index = SpirePickerFiles

-- Settings
vim.cmd("highlight SpireMatchHighlight guifg=#ff6b6b")

-- Icon utility
local icons = require('spire.icons')

function SpirePickerFiles:new(opts)
  opts = opts or {}
  if active then active:close() end

  local o = BasePicker:new(opts)
  setmetatable(o, SpirePickerFiles)
  o.width = opts.width or 80
  o.prompt_height = 1
  o.res_height = opts.res_height or 15
  o.title = "Files"
  o.prompt_text = opts.files.prompt_text or "> "
  o.hidden_files = opts.files.hidden_files or false
  o.search_term = ""
  o.results = {}
  o.selected_index = 1
  o.mappings = opts.files.mappings or {}
  o.ignore_list = opts.files.ignore_list or {}
  o.ignore_patterns = o.ignore_list[1] and table.concat(vim.tbl_map(function(p) return '--glob=!' .. p end, o.ignore_list), ' ') or ''
  o:create_windows()
  o:setup_keymaps()
  o:setup_autocmds()

  -- Populate with all files on startup
  o:perform_search("") -- Empty search = all files

  active = o
  return o
end

function SpirePickerFiles:setup_keymaps()
  -- Navigation in results
  vim.keymap.set("i", "<C-k>", function() self:select_prev() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<C-j>", function() self:select_next() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<A-h>", function() self:toggle_hidden_files() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<CR>", function() self:open_selected() end, { buffer = self.prompt_buf })

  -- Configurable mappings
  if self.mappings and self.mappings.open_vsplit then
    vim.keymap.set("i", self.mappings.open_vsplit, function() self:open_vsplit() end, { buffer = self.prompt_buf })
  end

  if self.mappings and self.mappings.open_split then
    vim.keymap.set("i", self.mappings.open_split, function() self:open_split() end, { buffer = self.prompt_buf })
  end
end

function SpirePickerFiles:toggle_hidden_files()
  self.hidden_files = not self.hidden_files
  self:perform_search()
end

function SpirePickerFiles:open_vsplit()
  if #self.results == 0 or not self.results[self.selected_index] then return end
  local file_path = self.results[self.selected_index]
  self:close()
  -- Switch to normal mode before opening
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.cmd("vsplit " .. vim.fn.fnameescape(file_path))
end

function SpirePickerFiles:open_split()
  if #self.results == 0 or not self.results[self.selected_index] then return end
  local file_path = self.results[self.selected_index]
  self:close()
  -- Switch to normal mode before opening
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.cmd("split " .. vim.fn.fnameescape(file_path))
end

function SpirePickerFiles:setup_autocmds()
  self.prompt_autocmd = vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = self.prompt_buf,
    callback = function() self:on_input_change() end
  })
end

function SpirePickerFiles:on_input_change()
  local content = vim.api.nvim_buf_get_lines(self.prompt_buf, 0, -1, false)
  local new_search = table.concat(content, ""):gsub("^" .. self.prompt_text, "")

  if new_search ~= self.search_term then
    self.search_term = new_search
    self:debounced_search()
  end
end

function SpirePickerFiles:debounced_search()
  if self.search_timer then
    vim.fn.timer_stop(self.search_timer)
  end

  self.search_timer = vim.fn.timer_start(30, function()
    self:perform_search()
  end)
end

function SpirePickerFiles:perform_search(force_search)
  local search_term = force_search or self.search_term
  local cmd = {'rg', '--files', '--color=never'}
  for _, pattern in ipairs(self.ignore_list) do
    table.insert(cmd, '--glob=!' .. pattern)
  end
  if self.hidden_files then
    table.insert(cmd, '--hidden')
  end

  if #search_term == 0 then
    -- Show all files by default with no search
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        self.results = vim.tbl_filter(function(line)
          return line ~= "" and line ~= nil
        end, data or {})
        self.selected_index = 1
        vim.schedule(function()
          self:update_results()
        end)
      end,
    })
    return
  end

  -- Pipe rg per word
  local words = vim.split(self.search_term, "%s+")
  
  local search_cmd = "rg --files --color=never " .. self.ignore_patterns .. (self.hidden_files and " --hidden" or "")
  for _, w in ipairs(words) do
    search_cmd = search_cmd .. " | rg -i " .. vim.fn.shellescape(w)
  end
  
  local this = self
  vim.fn.jobstart({"sh", "-c", search_cmd}, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      this.results = vim.tbl_filter(function(line)
        return line ~= "" and line ~= nil
      end, data or {})
      this.selected_index = 1
      vim.schedule(function()
        this:update_results()
      end)
    end,
  })
end

function SpirePickerFiles:update_results()
  if not vim.api.nvim_buf_is_valid(self.res_buf) then return end

  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", true)

  local display_lines = {}

  for i, result in ipairs(self.results) do
    if result ~= "" then
      local icon = "  "
      local icon_str, hl_str, is_default = icons.get_file_icon(result)
      if icons.has_icons() then
        icon = icon_str or "  "
      end
      local prefix = (i == self.selected_index) and "❯ " or "  "
      table.insert(display_lines, prefix .. icon .. " " .. result)
    end
  end

  if #display_lines == 0 then
    display_lines = { "No results found" }
  end

  vim.api.nvim_buf_set_lines(self.res_buf, 0, -1, false, display_lines)

  -- Add highlights after setting lines
  local ns = vim.api.nvim_create_namespace("spire_highlights")
  vim.api.nvim_buf_clear_namespace(self.res_buf, ns, 0, -1)

  for i, result in ipairs(self.results) do
    if result ~= "" then
      local prefix = (i == self.selected_index) and "❯ " or "  "
      local prefix_len = #prefix

      -- Icon highlighting
      if icons.has_icons() then
        local icon_str, hl_str, is_default = icons.get_file_icon(result)
        if hl_str then
          vim.api.nvim_buf_add_highlight(self.res_buf, ns, hl_str, i - 1, prefix_len, prefix_len + #icon_str)
        end
      end

      -- Search term highlighting
      if #self.search_term >= 1 then
        local result_lower = result:lower()
        local words = vim.split(self.search_term:lower(), "%s+")
        local icon_len = 0
        if icons.has_icons() then
          local icon_str = icons.get_file_icon(result) -- Get icon again
          icon_len = #icon_str
        end
        local text_start = prefix_len + icon_len + 1

        for _, word in ipairs(words) do
          if #word >= 1 then
            local start_pos, end_pos = result_lower:find(word, 1, true)
            if start_pos then
              vim.api.nvim_buf_add_highlight(self.res_buf, ns, "SpireMatchHighlight", i - 1, text_start + start_pos - 1,
                text_start + end_pos)
            end
          end
        end
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

function SpirePickerFiles:select_next()
  if #self.results == 0 then return end
  if self.selected_index == #self.results then
    self.selected_index = 1
  else
    self.selected_index = self.selected_index + 1
  end
  self:update_results()
end

function SpirePickerFiles:select_prev()
  if #self.results == 0 then return end
  self.selected_index = self.selected_index - 1

  if self.selected_index < 1 then
    self.selected_index = #self.results
  end
  self:update_results()
end

function SpirePickerFiles:open_selected()
  if #self.results == 0 or self.results[1] == "No results found" or not self.results[self.selected_index] then
    vim.api.nvim_echo({ { "No file to open", "WarningMsg" } }, true, {})
    return
  end

  local file_path = self.results[self.selected_index]
  if file_path == "" or file_path == "No results found" then return end

  self:close()

  -- Switch to normal mode before opening the file
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.cmd("edit " .. vim.fn.fnameescape(file_path))
end

function SpirePickerFiles:close()
  pcall(vim.api.nvim_del_autocmd, self.prompt_autocmd)
  if self.search_timer then
    vim.fn.timer_stop(self.search_timer)
  end
  require('spire.picker').close(self)
end

return SpirePickerFiles
