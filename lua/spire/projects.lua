local SpirePickerProjects = {}
local BasePicker = require('spire.picker')
local SpirePickerProjects = setmetatable({}, { __index = BasePicker })
SpirePickerProjects.__index = SpirePickerProjects

-- Project storage
local project_file = vim.fn.stdpath("data") .. "/spire_projects.json"

-- Icon utility
local icons = require('spire.icons')

function SpirePickerProjects:new(opts)
  opts = opts or {}
  if active then active:close() end

  local o = BasePicker:new(opts)
  setmetatable(o, SpirePickerProjects)

  o.width = opts.width or 80
  o.prompt_height = 1
  o.res_height = opts.res_height or 15
  o.title = "Projects"
  o.prompt_text = opts.prompt_text or "> "
  o.search_term = ""
  o.results = {}
  o.selected_index = 1
  o.mappings = opts.mappings or {}

  o:create_windows()
  o:setup_keymaps()
  o:setup_autocmds()
  o:load_projects()

  active = o
  return o
end

function SpirePickerProjects:load_projects()
  local ok, content = pcall(vim.fn.readfile, project_file)
  if not ok or #content == 0 then
    self.results = {}
    return
  end

  local ok, projects = pcall(vim.json.decode, content[1])
  if ok and type(projects) == "table" then
    -- SORT ON LOAD
    table.sort(projects, function(a, b)
      return (a.last_accessed or 0) > (b.last_accessed or 0)
    end)
    self.results = projects
  else
    self.results = {}
  end
  self:update_results()
end

function SpirePickerProjects:save_projects()
  vim.fn.mkdir(vim.fn.fnamemodify(project_file, ":h"), "p")
  vim.fn.writefile({ vim.json.encode(self.results) }, project_file)
end

function SpirePickerProjects:detect_project_type(path)
  local checks = {
    { file = ".git",           type = "git",    is_dir = true },
    { file = "package.json",   type = "npm",    is_dir = false },
    { file = "Cargo.toml",     type = "rust",   is_dir = false },
    { file = "pyproject.toml", type = "python", is_dir = false },
    { file = "go.mod",         type = "go",     is_dir = false },
    { file = "Makefile",       type = "make",   is_dir = false },
  }

  for _, check in ipairs(checks) do
    local full_path = path .. "/" .. check.file
    if check.is_dir then
      if vim.fn.isdirectory(full_path) == 1 then
        return check.type
      end
    else
      if vim.fn.filereadable(full_path) == 1 then
        return check.type
      end
    end
  end
  return "unknown"
end

function SpirePickerProjects:setup_keymaps()
  vim.keymap.set("i", "<C-k>", function() self:select_prev() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<C-j>", function() self:select_next() end, { buffer = self.prompt_buf })
  vim.keymap.set("i", "<CR>", function() self:open_selected() end, { buffer = self.prompt_buf })

  vim.keymap.set("i", "<C-a>", function()
    local cwd = vim.fn.getcwd()
    local project_type = self:detect_project_type(cwd)

    if project_type == "unknown" then
      vim.notify("Not a detectable project directory", vim.log.levels.WARN)
      return
    end

    local project_name = vim.fn.fnamemodify(cwd, ":t")

    -- Check if already in list using the FULL results list
    local already_exists = false
    for _, proj in ipairs(self.results) do
      if proj.path == cwd then
        already_exists = true
        break
      end
    end

    if already_exists then
      vim.notify("Project already exists in list!", vim.log.levels.WARN)
      return
    end

    -- Add to the main results list
    table.insert(self.results, {
      path = cwd,
      name = project_name,
      type = project_type,
      last_accessed = os.time()
    })

    -- Save to disk
    self:save_projects()

    -- Refresh the search to update both main and filtered results
    self:perform_search()
    vim.notify("Project added successfully!")
  end, { buffer = self.prompt_buf })

  vim.keymap.set("i", "<C-d>", function() self:delete_selected() end, { buffer = self.prompt_buf })
end

function SpirePickerProjects:setup_autocmds()
  self.prompt_autocmd = vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = self.prompt_buf,
    callback = function() self:on_input_change() end
  })
end

function SpirePickerProjects:on_input_change()
  local content = vim.api.nvim_buf_get_lines(self.prompt_buf, 0, -1, false)
  local new_search = table.concat(content, ""):gsub("^" .. self.prompt_text, "")

  if new_search ~= self.search_term then
    self.search_term = new_search
    self:debounced_search()
  end
end

function SpirePickerProjects:debounced_search()
  if self.search_timer then
    vim.fn.timer_stop(self.search_timer)
  end

  self.search_timer = vim.fn.timer_start(30, function()
    self:perform_search()
  end)
end

function SpirePickerProjects:perform_search()
  local filtered_results = {}

  if #self.search_term == 0 then
    filtered_results = self.results
  else
    local search_lower = self.search_term:lower()
    for _, project in ipairs(self.results) do
      if project.name:lower():find(search_lower, 1, true) or
          project.type:lower():find(search_lower, 1, true) or
          project.path:lower():find(search_lower, 1, true) then
        table.insert(filtered_results, project)
      end
    end
  end

  self.filtered_results = filtered_results
  self.selected_index = 1
  self:update_results()
end

function SpirePickerProjects:update_results()
  if not vim.api.nvim_buf_is_valid(self.res_buf) then return end

  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", true)

  local display_lines = {}
  local results = self.filtered_results or self.results

  for i, project in ipairs(results) do
    local icon = "  "
    if icons.has_icons() then
      local icon_str, hl_str, is_default = icons.get_file_icon(project.type)
      icon = icon_str or "  "
    end

    local prefix = (i == self.selected_index) and "❯ " or "  "
    local display_text = string.format("%s%s %s (%s)", prefix, icon, project.name, project.type)
    table.insert(display_lines, display_text)
  end

  if #display_lines == 0 then
    display_lines = { "No projects found. Use <C-a> to add current directory." }
  end

  vim.api.nvim_buf_set_lines(self.res_buf, 0, -1, false, display_lines)

  -- Highlights
  local ns = vim.api.nvim_create_namespace("spire_projects_highlights")
  vim.api.nvim_buf_clear_namespace(self.res_buf, ns, 0, -1)

  for i, project in ipairs(results) do
    if i == self.selected_index then
      vim.api.nvim_buf_add_highlight(self.res_buf, ns, "Visual", i - 1, 0, -1)
    end
  end

  vim.api.nvim_buf_set_option(self.res_buf, "modifiable", false)
  vim.api.nvim_win_set_cursor(self.res_win, { math.min(self.selected_index, #display_lines), 0 })
end

function SpirePickerProjects:select_next()
  local results = self.filtered_results or self.results
  if #results == 0 then return end
  if self.selected_index == #results then
    self.selected_index = 1
  else
    self.selected_index = self.selected_index + 1
  end
  self:update_results()
end

function SpirePickerProjects:select_prev()
  local results = self.filtered_results or self.results
  if #results == 0 then return end
  self.selected_index = self.selected_index - 1
  if self.selected_index < 1 then
    self.selected_index = #results
  end
  self:update_results()
end

function SpirePickerProjects:open_selected()
  local results = self.filtered_results or self.results
  if #results == 0 or not results[self.selected_index] then return end

  local project = results[self.selected_index]
  self:close()

  -- Update last accessed time
  project.last_accessed = os.time()
  self:save_projects()

  vim.cmd("cd " .. vim.fn.fnameescape(project.path))
  vim.notify("Switched to project: " .. project.name)
end

function SpirePickerProjects:delete_selected()
  local results = self.filtered_results or self.results
  if #results == 0 or not results[self.selected_index] then return end

  local project = results[self.selected_index]

  -- Remove from main results list
  for i, proj in ipairs(self.results) do
    if proj.path == project.path then
      table.remove(self.results, i)
      break
    end
  end

  self:save_projects()
  self:load_projects() -- Reload
  vim.notify("Project removed: " .. project.name)
end

function SpirePickerProjects:close()
  pcall(vim.api.nvim_del_autocmd, self.prompt_autocmd)
  if self.search_timer then
    vim.fn.timer_stop(self.search_timer)
  end
  require('spire.picker').close(self)
end

return SpirePickerProjects
