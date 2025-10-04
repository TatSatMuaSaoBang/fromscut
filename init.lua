-- Load themes
require('theme').setup()

-- Load homemade plugins
local keymap_finder = require('keymap_finder')
local testcase = require('testcase')  -- Add this line
local hop = require('hop')
local keymap_finder = require('keymap_finder')

-- Basic settings
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.g.mapleader = " "
vim.opt.encoding = "UTF-8"
vim.opt.fileencoding = "utf-8"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.number = false
vim.opt.relativenumber = true
vim.opt.cursorline = false
vim.opt.signcolumn = "yes"
vim.opt.timeoutlen = 500
vim.opt.cmdheight = 1
vim.opt.autoread = true
vim.opt.wrap = false
vim.opt.mouse = "a"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.completeopt = { "menuone", "noselect" }
vim.opt.termguicolors = true
vim.opt.list = true
vim.opt.listchars = { space = "·", tab = "··" }
vim.opt.wildmenu = true
vim.opt.shortmess:append("c")
vim.opt.pumheight = 10
vim.opt.showtabline = 2
vim.opt.showmode = false
vim.opt.clipboard = "unnamedplus"
vim.g.omni_sql_no_default_maps = 1
vim.g.netrw_winsize = 24
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- Custom bufferline function
function _G.custom_bufferline()
  local buffers = {}
  local current = vim.api.nvim_get_current_buf()
  
  -- Collect all listed buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(buf) == 1 then
      table.insert(buffers, buf)
    end
  end
  
  local line = ""
  for _, buf in ipairs(buffers) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
    if name == '' then name = '[No Name]' end
    
    -- Check if modified
    local modified = vim.fn.getbufvar(buf, "&modified") == 1 and ' [+]' or ''
    
    -- Highlight current buffer differently
    if buf == current then
      line = line .. '%#TabLineSel# ' .. name .. modified .. ' %#TabLine#'
    else
      line = line .. ' ' .. buf .. ':' .. name .. modified .. ' '
    end
    
    line = line .. '│'
  end
  
  return line .. '%#TabLineFill#'
end

-- Set the tabline to use our custom function
vim.opt.tabline = '%!v:lua.custom_bufferline()'

-- Helper for keymap
local map = function(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then options = vim.tbl_extend("force", options, opts) end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- Confirm on unsaved quit
local function check_unsaved()
  for i = 1, vim.fn.bufnr('$') do
    if vim.fn.buflisted(i) == 1 and vim.fn.getbufvar(i, "&modified") == 1 then
      return true
    end
  end
  return false
end

function check_before_quit()
  if check_unsaved() then
    local choice = vim.fn.confirm('Unsaved changes detected. Save before quit?', '&Save\n&Quit\n&Cancel')
    if choice == 1 then
      vim.cmd('wa | qa')
    elseif choice == 2 then
      vim.cmd('qa!')
    end
  else
    vim.cmd('q')
  end
end

-- Toggle netrw
vim.g.NetrwIsOpen = 0
function ToggleNetrw()
  if vim.g.NetrwIsOpen == 1 then
    for i = vim.fn.bufnr("$"), 1, -1 do
      if vim.fn.getbufvar(i, "&filetype") == "netrw" then
        vim.cmd("silent bwipeout " .. i)
      end
    end
    vim.g.NetrwIsOpen = 0
  else
    vim.g.NetrwIsOpen = 1
    vim.cmd("Lexplore")
  end
end

-- Netrw custom keymaps
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    
    -- Create new file/folder with 'a'
    vim.keymap.set('n', 'a', function()
      local dir = vim.fn.expand('%:p:h')
      vim.ui.input({ prompt = dir .. '/' }, function(name)
        if name and name ~= '' then
          local path = dir .. '/' .. name
          
          -- If name has extension, create file and open it
          if name:match('%.[^/]+') then
            local file = io.open(path, 'w')
            if file then
              file:close()
              vim.cmd('wincmd l')
              vim.cmd('edit ' .. vim.fn.fnameescape(path))
              print('Created file: ' .. name)
            else
              print('Failed to create file: ' .. name)
            end
          else
            -- No extension = folder
            local ok = vim.loop.fs_mkdir(path, 493)
            if ok then
              vim.cmd('edit .')
              print('Created folder: ' .. name)
            else
              print('Failed to create folder: ' .. name)
            end
          end
        end
      end)
    end, { buffer = buf, noremap = true, silent = true })
    
    -- Rename file with 'r'
    vim.keymap.set('n', 'r', function()
      local file = vim.fn.expand('<cfile>')
      if file == '' then
        print('No file under cursor')
        return
      end
      vim.ui.input({ prompt = 'Rename to: ', default = file }, function(newname)
        if newname and newname ~= '' and newname ~= file then
          local old_path = vim.fn.expand('%:p:h') .. '/' .. file
          local new_path = vim.fn.expand('%:p:h') .. '/' .. newname
          local ok = vim.loop.fs_rename(old_path, new_path)
          if ok then
            vim.cmd('edit .')
            print('Renamed: ' .. file .. ' → ' .. newname)
          else
            print('Failed to rename file')
          end
        end
      end)
    end, { buffer = buf, noremap = true, silent = true })
  end
})

-- Terminal management
vim.g.TermBuf_H = nil
vim.g.TermWin_H = nil
vim.g.TermBuf_V = nil
vim.g.TermWin_V = nil

function ToggleTerminalHorizontal()
  if vim.g.TermWin_H and vim.api.nvim_win_is_valid(vim.g.TermWin_H) then
    vim.api.nvim_win_hide(vim.g.TermWin_H)
    vim.g.TermWin_H = nil
    return
  end
  if vim.g.TermBuf_H and vim.api.nvim_buf_is_valid(vim.g.TermBuf_H) then
    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, vim.g.TermBuf_H)
    vim.cmd("resize 15")
    vim.cmd("startinsert")
    vim.g.TermWin_H = vim.api.nvim_get_current_win()
    return
  end
  vim.cmd("botright split | term")
  vim.cmd("resize 15")
  vim.cmd("startinsert")
  vim.g.TermBuf_H = vim.api.nvim_get_current_buf()
  vim.g.TermWin_H = vim.api.nvim_get_current_win()
end

function ToggleTerminalVertical()
  if vim.g.TermWin_V and vim.api.nvim_win_is_valid(vim.g.TermWin_V) then
    vim.api.nvim_win_hide(vim.g.TermWin_V)
    vim.g.TermWin_V = nil
    return
  end
  if vim.g.TermBuf_V and vim.api.nvim_buf_is_valid(vim.g.TermBuf_V) then
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, vim.g.TermBuf_V)
    vim.cmd("vertical resize 60")
    vim.cmd("startinsert")
    vim.g.TermWin_V = vim.api.nvim_get_current_win()
    return
  end
  vim.cmd("vsplit | term")
  vim.cmd("vertical resize 60")
  vim.cmd("startinsert")
  vim.g.TermBuf_V = vim.api.nvim_get_current_buf()
  vim.g.TermWin_V = vim.api.nvim_get_current_win()
end

-- Auto pairs
local auto_pairs = {
  ['('] = ')',
  ['['] = ']',
  ['{'] = '}',
  ['"'] = '"',
  ["'"] = "'",
}

for open, close in pairs(auto_pairs) do
  vim.keymap.set("i", open, function()
    return open .. close .. "<Left>"
  end, { expr = true, noremap = true })
  
  vim.keymap.set("i", close, function()
    local col = vim.fn.col(".")
    local line = vim.fn.getline(".")
    if line:sub(col, col) == close then
      return "<Right>"
    else
      return close
    end
  end, { expr = true, noremap = true })
end

-- Basic keymaps
map('i', '<CR>', 'pumvisible() ? "<C-y>" : "<CR>"', { expr = true })
map('i', '<C-BS>', '<C-w>')
map('i', '<S-Tab>', '<C-d>')
map('i', '<Tab>', '<C-t>')

-- File explorer
map('n', '<leader>e', ':lua ToggleNetrw()<CR>')
map('n', '<leader>r', ':browse oldfiles<CR>')

-- Buffer/file management
map('n', '<leader>oj', ':edit<Space>')
map('n', '<leader>ok', ':split<CR>:edit<Space>')
map('n', '<leader>oo', ':split<CR>:buffer<Space>')
map('n', '<leader>ol', ':vsplit<CR>:buffer<Space>')

-- Buffer navigation
map('n', '<Tab>', ':bnext<CR>')
map('n', '<S-Tab>', ':bprevious<CR>')

-- Window navigation (normal mode)
map('n', '<C-h>', '<C-w>h')
map('n', '<C-j>', '<C-w>j')
map('n', '<C-k>', '<C-w>k')
map('n', '<C-l>', '<C-w>l')

-- Window splits
map('n', '<C-[>', ':split<CR>')
map('n', '<C-]>', ':vsplit<CR>')

-- Misc
map('n', '<leader>w', ':w<CR>')
map('n', '<leader>q', ':lua check_before_quit()<CR>')
map('n', '<leader>h', ':nohlsearch<CR>')

-- Terminal toggles (all modes)
vim.keymap.set({ 'n', 'i', 't' }, '<F7>', ToggleTerminalHorizontal, { noremap = true, silent = true })
vim.keymap.set({ 'n', 'i', 't' }, '<C-7>', ToggleTerminalVertical, { noremap = true, silent = true })

-- Terminal navigation
map('t', '<C-h>', [[<C-\><C-n><C-w>h]])
map('t', '<C-j>', [[<C-\><C-n><C-w>j]])
map('t', '<C-l>', [[<C-\><C-n><C-w>l]])
map('t', '<Esc>', [[<C-\><C-n>]])

-- Finding keymaps
map('n', '<leader>fk', ':lua require("keymap_finder").show()<CR>')

-- Finding files
map('n', '<leader>ff', ':lua require("file_finder").show()<CR>')

-- Testcase manager
vim.keymap.set('n', '<C-g><C-g>', function() require('testcase').toggle() end, { noremap = true, silent = true })
vim.keymap.set('n', '<C-g>s', function() require('testcase').start() end, { noremap = true, silent = true })
vim.keymap.set('n', '<C-g>e', function() require('testcase').exit() end, { noremap = true, silent = true })

-- Hop plugin - jump to words
vim.keymap.set('n', '<C-h><C-h>', function() require('hop').hop_line() end, { noremap = true, silent = true })
vim.keymap.set('v', '<C-h><C-h>', function() require('hop').hop_visual() end, { noremap = true, silent = true })

-- Custom Statusline with MORE COLORS! 🌈
local function get_mode_info()
  local mode_map = {
    ['n'] = { name = 'NORMAL', emoji = '😎', color = '%#StatusNormal#' },
    ['i'] = { name = 'INSERT', emoji = '✍️', color = '%#StatusInsert#' },
    ['v'] = { name = 'VISUAL', emoji = '👀', color = '%#StatusVisual#' },
    ['V'] = { name = 'V-LINE', emoji = '📝', color = '%#StatusVisual#' },
    [''] = { name = 'V-BLOCK', emoji = '🔲', color = '%#StatusVisual#' },
    ['c'] = { name = 'COMMAND', emoji = '⚡', color = '%#StatusCommand#' },
    ['r'] = { name = 'REPLACE', emoji = '🔄', color = '%#StatusReplace#' },
    ['t'] = { name = 'TERMINAL', emoji = '💻', color = '%#StatusTerminal#' },
  }
  
  local mode = vim.api.nvim_get_mode().mode
  return mode_map[mode] or { name = mode:upper(), emoji = '🤔', color = '%#StatusNormal#' }
end

local function get_file_icon()
  local ft_icons = {
    lua = '🌙',
    python = '🐍',
    javascript = '📜',
    typescript = '💙',
    java = '☕',
    cpp = '⚙️',
    c = '🔧',
    rust = '🦀',
    go = '🐹',
    html = '🌐',
    css = '🎨',
    json = '📋',
    markdown = '📝',
    vim = '💚',
    sh = '🐚',
  }
  
  local ft = vim.bo.filetype
  return ft_icons[ft] or '📄'
end

local function get_indent_info()
  if vim.bo.expandtab then
    return 'Spaces: ' .. vim.bo.shiftwidth
  else
    return 'Tabs: ' .. vim.bo.tabstop
  end
end

local function word_count()
  local words = vim.fn.wordcount()
  return words.words .. ' words'
end

local function get_time()
  return os.date('%H:%M')
end

local function get_position()
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  local total = vim.fn.line('$')
  return string.format('%d:%d/%d', line, col, total)
end

function _G.custom_statusline()
  local mode_info = get_mode_info()
  local filename = vim.fn.expand('%:t')
  if filename == '' then filename = '[No Name]' end
  
  local modified = vim.bo.modified and ' [+]' or ''
  local readonly = vim.bo.readonly and ' 🔒' or ''
  local filetype = vim.bo.filetype ~= '' and vim.bo.filetype or 'text'
  
  -- Colorful left side
  local left = string.format(
    '%s %s %s %%#StatusSep1#│%%#StatusFile# %s %s%s%s %%#StatusSep2#│%%#StatusLang# %s ',
    mode_info.color,
    mode_info.emoji,
    mode_info.name,
    get_file_icon(),
    filename,
    modified,
    readonly,
    filetype
  )
  
  -- Colorful right side
  local right = string.format(
    '%%#StatusIndent#│ %s %%#StatusWords#│ %s %%#StatusTime#│ 🕐 %s %%#StatusPos#│ 📍 %s ',
    get_indent_info(),
    word_count(),
    get_time(),
    get_position()
  )
  
  return left .. '%#StatusLineFill#%=' .. right
end

-- Set custom statusline
vim.opt.statusline = '%!v:lua.custom_statusline()'

-- Define COLORFUL highlight groups for different modes
vim.api.nvim_set_hl(0, 'StatusNormal', { fg = '#1a1b26', bg = '#7aa2f7', bold = true })    -- Blue
vim.api.nvim_set_hl(0, 'StatusInsert', { fg = '#1a1b26', bg = '#9ece6a', bold = true })    -- Green
vim.api.nvim_set_hl(0, 'StatusVisual', { fg = '#1a1b26', bg = '#bb9af7', bold = true })    -- Purple
vim.api.nvim_set_hl(0, 'StatusCommand', { fg = '#1a1b26', bg = '#e0af68', bold = true })   -- Yellow
vim.api.nvim_set_hl(0, 'StatusReplace', { fg = '#1a1b26', bg = '#f7768e', bold = true })   -- Red
vim.api.nvim_set_hl(0, 'StatusTerminal', { fg = '#1a1b26', bg = '#73daca', bold = true })  -- Cyan

-- Colorful sections
vim.api.nvim_set_hl(0, 'StatusFile', { fg = '#ffffff', bg = '#414868', bold = false })     -- Gray-blue
vim.api.nvim_set_hl(0, 'StatusLang', { fg = '#ffffff', bg = '#565f89', bold = false })     -- Lighter gray
vim.api.nvim_set_hl(0, 'StatusIndent', { fg = '#1a1b26', bg = '#ff9e64', bold = false })   -- Orange
vim.api.nvim_set_hl(0, 'StatusWords', { fg = '#1a1b26', bg = '#2ac3de', bold = false })    -- Bright cyan
vim.api.nvim_set_hl(0, 'StatusTime', { fg = '#1a1b26', bg = '#c0caf5', bold = false })     -- Light blue
vim.api.nvim_set_hl(0, 'StatusPos', { fg = '#1a1b26', bg = '#bb9af7', bold = false })      -- Purple

-- Separators
vim.api.nvim_set_hl(0, 'StatusSep1', { fg = '#7aa2f7', bg = '#414868' })
vim.api.nvim_set_hl(0, 'StatusSep2', { fg = '#7aa2f7', bg = '#565f89' })

-- Fill area
vim.api.nvim_set_hl(0, 'StatusLineFill', { fg = '#c0caf5', bg = '#1f2335' })

-- Update statusline when mode changes
vim.api.nvim_create_autocmd('ModeChanged', {
  pattern = '*',
  callback = function()
    vim.cmd('redrawstatus')
  end
})

-- Update time every minute
vim.fn.timer_start(60000, function()
  vim.cmd('redrawstatus')
end, { ['repeat'] = -1 })