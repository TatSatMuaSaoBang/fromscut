local M = {}

local buf, win
local keymaps = {}
local filtered = {}
local search_term = ""

local descriptions = {
  ['<leader>fk'] = 'Open the Keymap Finder window to search and explore all available keybindings',
  ['<leader>e']  = 'Toggle the file explorer (usually NvimTree or similar) to browse project files',
  ['<leader>r']  = 'Open a list of recently used files for quick navigation',
  ['<C-h><C-h>'] = 'Quickly hop between texts or code sections to speed up editing',
  ['<leader>oj'] = 'Open a file in the current window',
  ['<leader>ok'] = 'Open a file in a new horizontal split (stacked view)',
  [' oo']        = 'Open the current buffer in a new split window (duplicate view)',
  ['<leader>ol'] = 'Open a buffer in a vertical split (side-by-side view)',
  ['<leader>w']  = 'Save the current file to disk',
  ['<leader>q']  = 'Quit Neovim with confirmation to prevent accidental exits',
  ['<leader>h']  = 'Clear any active search highlights from the screen',
  ['<Tab>']      = 'Cycle forward to the next buffer in the buffer list',
  ['<S-Tab>']    = 'Cycle backward to the previous buffer in the buffer list',
  ['<C-h>']      = 'Move focus to the window on the left',
  ['<C-j>']      = 'Move focus to the window below',
  ['<C-k>']      = 'Move focus to the window above',
  ['<C-l>']      = 'Move focus to the window on the right',
  ['<C-[>']      = 'Split the window horizontally (top and bottom)',
  ['<C-]>']      = 'Split the window vertically (side by side)',
  ['<F7>']       = 'Toggle a horizontal terminal at the bottom of the screen',
  ['<C-7>']      = 'Toggle a vertical terminal on the side of the screen',
  ['<C-BS>']     = 'Delete the previous word (move cursor back and remove word)',
  ['<C-gg>']     = 'Open and run a test case (used for coding/testing workflow)',
  ['a']          = 'Create a new file or folder (in file explorer context)',
  ['r']          = 'Rename the selected file or folder (in file explorer context)',
  ['<leader>ff'] = 'Search and find files in the current project directory',
}

local function collect_keymaps()
  keymaps = {}
  local modes = {'n', 'i', 'v', 't', 'x', 'o'}
  
  for _, mode in ipairs(modes) do
    local mode_maps = vim.api.nvim_get_keymap(mode)
    for _, map in ipairs(mode_maps) do
      local key = map.lhs:gsub('<leader>', ' ')
      table.insert(keymaps, {
        mode = mode,
        lhs = map.lhs,
        rhs = map.rhs or map.callback and '<function>' or '',
        desc = descriptions[key] or map.desc or ''
      })
    end
    
    local buf_maps = vim.api.nvim_buf_get_keymap(0, mode)
    for _, map in ipairs(buf_maps) do
      local key = map.lhs:gsub('<leader>', ' ')
      table.insert(keymaps, {
        mode = mode .. '*',
        lhs = map.lhs,
        rhs = map.rhs or map.callback and '<function>' or '',
        desc = descriptions[key] or map.desc or ''
      })
    end
  end
  
  return keymaps
end

local function filter_keymaps()
  filtered = {}
  local term = search_term:lower()
  
  for _, km in ipairs(keymaps) do
    local searchable = (km.mode .. km.lhs .. km.rhs .. km.desc):lower()
    if searchable:match(term) then
      table.insert(filtered, km)
    end
  end
end

local function render()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  local lines = {}
  local width = 90
  
  table.insert(lines, "╭─ Keymap Finder " .. string.rep("─", width - 18) .. "╮")
  table.insert(lines, "│ Search: " .. search_term .. "█" .. string.rep(" ", width - 11 - #search_term) .. "│")
  table.insert(lines, "├" .. string.rep("─", width - 2) .. "┤")
  table.insert(lines, string.format("│ %-6s │ %-18s │ %-57s │", "MODE", "KEY", "DESCRIPTION"))
  table.insert(lines, "├" .. string.rep("─", width - 2) .. "┤")
  
  local display_maps = #search_term > 0 and filtered or keymaps
  local max_lines = 20
  
  for i = 1, math.min(#display_maps, max_lines) do
    local km = display_maps[i]
    local mode = string.format("%-6s", km.mode:sub(1, 6))
    local lhs = string.format("%-18s", km.lhs:gsub('<leader>', '␣'):sub(1, 18))
    local desc = km.desc ~= '' and km.desc or km.rhs
    desc = string.format("%-57s", desc:sub(1, 57))
    
    local line = "│ " .. mode .. " │ " .. lhs .. " │ " .. desc .. " │"
    table.insert(lines, line)
  end
  
  if #display_maps > max_lines then
    table.insert(lines, "│" .. string.rep(" ", width - 2) .. "│")
    local remaining = #display_maps - max_lines
    local msg = string.format("... and %d more", remaining)
    local padding = math.floor((width - 2 - #msg) / 2)
    table.insert(lines, "│" .. string.rep(" ", padding) .. msg .. string.rep(" ", width - 2 - padding - #msg) .. "│")
  end
  
  table.insert(lines, "╰" .. string.rep("─", width - 2) .. "╯")
  table.insert(lines, " Press 'q' or <Esc> to close  │  Type to search  │  <BS> to delete")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Position cursor on search line
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_cursor(win, {2, 10 + #search_term})
    end
  end)
end

local function close_window()
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
  vim.api.nvim_buf_set_option(buf, 'filetype', 'keymap-finder')
  
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
    {'n', '<CR>', close_window},
  }
  
  for _, km in ipairs(keymaps_to_set) do
    vim.keymap.set(km[1], km[2], km[3], { buffer = buf, nowait = true, silent = true })
  end
  
  vim.keymap.set('n', '<BS>', function()
    search_term = search_term:sub(1, -2)
    filter_keymaps()
    render()
  end, { buffer = buf, nowait = true, silent = true })
  
  for i = 32, 126 do
    local char = string.char(i)
    vim.keymap.set('n', char, function()
      search_term = search_term .. char
      filter_keymaps()
      render()
    end, { buffer = buf, nowait = true, silent = true })
  end
  
  vim.keymap.set('n', '<Space>', function()
    search_term = search_term .. ' '
    filter_keymaps()
    render()
  end, { buffer = buf, nowait = true, silent = true })
  
  render()
end

function M.show()
  search_term = ""
  collect_keymaps()
  filter_keymaps()
  open_window()
end

return M