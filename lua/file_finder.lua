local M = {}

local buf, win
local files = {}
local filtered = {}
local search_term = ""
local current_dir = ""

local function scan_directory(dir)
  files = {}
  current_dir = dir
  
  local handle = vim.loop.fs_scandir(dir)
  if not handle then return end
  
  while true do
    local name, ftype = vim.loop.fs_scandir_next(handle)
    if not name then break end
    
    if not name:match("^%.") then
      local path = dir .. "/" .. name
      local icon = ftype == "directory" and "📁" or "📄"
      
      table.insert(files, {
        name = name,
        path = path,
        type = ftype,
        icon = icon
      })
    end
  end
  
  table.sort(files, function(a, b)
    if a.type == b.type then
      return a.name < b.name
    end
    return a.type == "directory"
  end)
end

local function filter_files()
  filtered = {}
  local term = search_term:lower()
  
  for _, file in ipairs(files) do
    if file.name:lower():match(term) then
      table.insert(filtered, file)
    end
  end
end

local function render()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  local lines = {}
  local width = 90
  
  table.insert(lines, "╭─ File Finder " .. string.rep("─", width - 16) .. "╮")
  table.insert(lines, "│ Search: " .. search_term .. "█" .. string.rep(" ", width - 11 - #search_term) .. "│")
  table.insert(lines, "├" .. string.rep("─", width - 2) .. "┤")
  
  local dir_display = current_dir:gsub(vim.fn.expand("~"), "~")
  if #dir_display > width - 6 then
    dir_display = "..." .. dir_display:sub(-(width - 9))
  end
  table.insert(lines, "│ " .. string.format("%-" .. (width - 4) .. "s", dir_display) .. " │")
  table.insert(lines, "├" .. string.rep("─", width - 2) .. "┤")
  table.insert(lines, string.format("│ %-6s │ %-78s │", "TYPE", "NAME"))
  table.insert(lines, "├" .. string.rep("─", width - 2) .. "┤")
  
  local display_files = #search_term > 0 and filtered or files
  local max_lines = 18
  
  for i = 1, math.min(#display_files, max_lines) do
    local file = display_files[i]
    local type_str = string.format("%-6s", file.icon)
    local name = string.format("%-78s", file.name:sub(1, 78))
    
    local line = "│ " .. type_str .. " │ " .. name .. " │"
    table.insert(lines, line)
  end
  
  if #display_files > max_lines then
    table.insert(lines, "│" .. string.rep(" ", width - 2) .. "│")
    local remaining = #display_files - max_lines
    local msg = string.format("... and %d more", remaining)
    local padding = math.floor((width - 2 - #msg) / 2)
    table.insert(lines, "│" .. string.rep(" ", padding) .. msg .. string.rep(" ", width - 2 - padding - #msg) .. "│")
  end
  
  table.insert(lines, "╰" .. string.rep("─", width - 2) .. "╯")
  table.insert(lines, " <CR> to open  │  q/<Esc> to close  │  Type to search  │  <BS> to delete")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Position cursor on search line at the cursor position (after "Search: " text)
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_cursor(win, {2, 10 + #search_term})
    end
  end)
end

local function open_selected()
  local display_files = #search_term > 0 and filtered or files
  if #display_files == 0 then return end
  
  local file = display_files[1]
  
  close_window()
  
  if file.type == "directory" then
    vim.cmd("cd " .. vim.fn.fnameescape(file.path))
    print("Changed directory to: " .. file.name)
  else
    vim.cmd("edit " .. vim.fn.fnameescape(file.path))
  end
end

function close_window()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  buf, win = nil, nil
end

local function open_window()
  buf = vim.api.nvim_create_buf(false, true)
  
  local width = 92
  local height = 27
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui.width
  local win_height = ui.height
  
  local col = math.floor((win_width - width) / 2)
  local row = math.floor((win_height - height) / 2)
  
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'none',
  }
  
  win = vim.api.nvim_open_win(buf, true, opts)
  
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'file-finder')
  
  vim.api.nvim_win_set_option(win, 'cursorline', false)
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'wrap', false)
  
-- Hide the actual cursor completely
vim.api.nvim_win_set_option(win, 'cursorline', false)
vim.cmd('highlight Cursor blend=100')
vim.cmd('set guicursor=a:Cursor/lCursor')

vim.api.nvim_create_autocmd('BufLeave', {
  buffer = buf,
  callback = function()
    vim.cmd('highlight Cursor blend=0')
    vim.cmd('set guicursor&')
  end,
  once = true
})
  
  local keymaps_to_set = {
    {'n', 'q', close_window},
    {'n', '<Esc>', close_window},
    {'n', '<CR>', open_selected},
  }
  
  for _, km in ipairs(keymaps_to_set) do
    vim.keymap.set(km[1], km[2], km[3], { buffer = buf, nowait = true, silent = true })
  end
  
  vim.keymap.set('n', '<BS>', function()
    search_term = search_term:sub(1, -2)
    filter_files()
    render()
  end, { buffer = buf, nowait = true, silent = true })
  
  for i = 32, 126 do
    local char = string.char(i)
    vim.keymap.set('n', char, function()
      search_term = search_term .. char
      filter_files()
      render()
    end, { buffer = buf, nowait = true, silent = true })
  end
  
  vim.keymap.set('n', '<Space>', function()
    search_term = search_term .. ' '
    filter_files()
    render()
  end, { buffer = buf, nowait = true, silent = true })
  
  render()
end

function M.show()
  search_term = ""
  scan_directory(vim.fn.getcwd())
  filter_files()
  open_window()
end

return M