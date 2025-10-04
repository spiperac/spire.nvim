local SpirePicker = {}
SpirePicker.__index = SpirePicker

local active = nil
local BORDER_WIDTH = 2 -- single border = 2 lines total

function SpirePicker:create_windows()
  vim.opt.shortmess:append("I")
  local max_width = math.min(self.width, vim.o.columns - BORDER_WIDTH)
  local max_res_height = math.min(self.res_height, vim.o.lines - self.prompt_height - BORDER_WIDTH)

  local row = (vim.o.lines - (self.prompt_height + max_res_height)) / 2
  local col = (vim.o.columns - max_width) / 2

  local prompt_row, res_row
  if self.prompt_location == "bottom" then
    -- Prompt at bottom, results on top
    res_row = row
    prompt_row = row + max_res_height + 1
  else
    -- Default: prompt on top, results below
    prompt_row = row
    res_row = row + self.prompt_height + 1
  end

  self.prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.opt_local.showmode = false
  vim.api.nvim_buf_set_option(self.prompt_buf, "buftype", "prompt")
  vim.fn.prompt_setprompt(self.prompt_buf, self.prompt_text)

  self.prompt_win = vim.api.nvim_open_win(self.prompt_buf, true, {
    relative = "editor",
    width = max_width,
    height = self.prompt_height,
    row = prompt_row,
    col = col,
    style = "minimal",
    border = "single",
    title = self.title,
    title_pos = "center",
  })

  vim.api.nvim_feedkeys("i", "n", false)

  self.res_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", false)

  self.res_win = vim.api.nvim_open_win(self.res_buf, false, {
    relative = "editor",
    width = max_width,
    height = max_res_height,
    row = res_row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.keymap.set({ "i", "n" }, "<Esc>", function() self:close() end, { buffer = self.prompt_buf })
end

function SpirePicker:create_windows_preview()
  vim.opt.shortmess:append("I")
  local total_width = math.min(self.width, vim.o.columns - BORDER_WIDTH * 3)
  local results_width = math.floor(total_width * 0.4)
  local preview_width = total_width - results_width

  local total_height = math.min(self.res_height, vim.o.lines - BORDER_WIDTH * 3)
  local row = (vim.o.lines - (self.prompt_height + total_height)) / 2
  local col = (vim.o.columns - total_width) / 2

  local prompt_row, res_row
  if self.prompt_location == "bottom" then
    -- Prompt at bottom, results on top
    res_row = row
    prompt_row = row + total_height + 1
  else
    -- Default: prompt on top, results below
    prompt_row = row
    res_row = row + self.prompt_height + 1
  end

  -- Create prompt window
  self.prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.opt_local.showmode = false
  vim.api.nvim_buf_set_option(self.prompt_buf, "buftype", "prompt")
  vim.fn.prompt_setprompt(self.prompt_buf, self.prompt_text)

  self.prompt_win = vim.api.nvim_open_win(self.prompt_buf, true, {
    relative = "editor",
    width = results_width,
    height = self.prompt_height,
    row = prompt_row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = self.title,
    title_pos = "center"
  })

  -- Create results window
  self.res_buf = vim.api.nvim_create_buf(false, true)
  self.res_win = vim.api.nvim_open_win(self.res_buf, false, {
    relative = "editor",
    width = results_width,
    height = total_height,
    row = res_row,
    col = col,
    style = "minimal",
    border = "single"
  })

  -- Create preview window (right side, full height)
  self.preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.preview_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(self.preview_buf, "buftype", "nofile")
  self.preview_win = vim.api.nvim_open_win(self.preview_buf, false, {
    relative = "editor",
    width = preview_width,
    height = self.prompt_height + total_height + 10,
    row = row,
    col = col + results_width + 1,
    style = "minimal",
    border = "single",
    title = ""
  })

  vim.api.nvim_feedkeys("i", "n", false)
  vim.keymap.set({ "i", "n" }, "<Esc>", function() self:close() end, { buffer = self.prompt_buf })
  vim.api.nvim_win_set_option(self.prompt_win, "showmode", false)
end

function SpirePicker:create_select_window(items, opts)
  opts = vim.tbl_extend("force", {
    border = "rounded",
    prompt = "Select:",
    format_item = function(item) return item end
  }, opts or {})

  vim.ui.select(items, opts, opts.on_select)
end

function SpirePicker:new(opts)
  opts = opts or {}
  if active then active:close() end
  local o = setmetatable({}, SpirePicker)
  o.width = opts.width or 50
  o.prompt_height = 1
  o.res_height = opts.res_height or 10
  o.prompt_text = opts.prompt_text or "> "
  o.title = opts.title or "SpirePicker"
  o.prompt_location = opts.prompt_location or "bottom" -- "top" or "bottom"
  active = o
  return o
end

function SpirePicker:close()
  -- Switch to normal mode before closing
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  pcall(vim.api.nvim_win_close, self.preview_win, true)
  pcall(vim.api.nvim_win_close, self.prompt_win, true)
  pcall(vim.api.nvim_win_close, self.res_win, true)
  pcall(vim.api.nvim_buf_delete, self.prompt_buf, { force = true })
  pcall(vim.api.nvim_buf_delete, self.res_buf, { force = true })
  pcall(vim.api.nvim_buf_delete, self.preview_buf, { force = true })
  active = nil
end

return SpirePicker
