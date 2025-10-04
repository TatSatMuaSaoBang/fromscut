-- autopairs.lua
local M = {}

local asymmetric_pairs = {
  ['('] = ')',
  ['['] = ']',
  ['{'] = '}',
}

local symmetric_pairs = { '"', "'", '`' }

-- Check if cursor is at end of line or followed by whitespace/closing bracket
local function can_autopair()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local next_char = line:sub(col, col)
  
  -- Allow pairing at end of line or before whitespace/brackets
  return next_char == '' or next_char:match('[%s%)%]%}]')
end

-- Insert asymmetric pair with cursor positioning
local function insert_asymmetric_pair(open_char)
  if not can_autopair() then
    return open_char
  end
  
  local close_char = asymmetric_pairs[open_char]
  return open_char .. close_char .. '<Left>'
end

-- Handle symmetric pairs intelligently
local function handle_symmetric_pair(char)
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local prev_char = line:sub(col - 1, col - 1)
  local next_char = line:sub(col, col)
  
  -- Skip over matching closing quote
  if next_char == char then
    return '<Right>'
  end
  
  -- Don't pair after alphanumeric or same quote
  if prev_char:match('[%w_]') or prev_char == char then
    return char
  end
  
  -- Don't pair before alphanumeric (unless at start of word)
  if next_char:match('[%w_]') then
    return char
  end
  
  -- Pair the quote
  return char .. char .. '<Left>'
end

-- Skip over closing bracket or insert it
local function skip_or_insert(close_char)
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local next_char = line:sub(col, col)
  
  if next_char == close_char then
    return '<Right>'
  end
  return close_char
end

-- Smart backspace: delete pairs together
local function smart_backspace()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local prev_char = line:sub(col - 1, col - 1)
  local next_char = line:sub(col, col)
  
  -- Delete asymmetric pairs
  if asymmetric_pairs[prev_char] == next_char then
    return '<BS><Del>'
  end
  
  -- Delete symmetric pairs
  for _, char in ipairs(symmetric_pairs) do
    if prev_char == char and next_char == char then
      return '<BS><Del>'
    end
  end
  
  return '<BS>'
end

-- Smart enter: expand braces on newline
local function smart_enter()
  -- Handle completion menu first
  if vim.fn.pumvisible() == 1 then
    return '<C-y>'
  end
  
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local prev_char = line:sub(col - 1, col - 1)
  local next_char = line:sub(col, col)
  
  -- Expand {} with proper indentation
  if prev_char == '{' and next_char == '}' then
    return '<CR><Esc>O'
  end
  
  -- Expand [] with proper indentation
  if prev_char == '[' and next_char == ']' then
    return '<CR><Esc>O'
  end
  
  -- Expand () with proper indentation
  if prev_char == '(' and next_char == ')' then
    return '<CR><Esc>O'
  end
  
  return '<CR>'
end

-- Smart space: add space inside brackets
local function smart_space()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local prev_char = line:sub(col - 1, col - 1)
  local next_char = line:sub(col, col)
  
  -- Add space padding inside brackets: { | } -> {  |  }
  if (prev_char == '{' and next_char == '}') or
     (prev_char == '[' and next_char == ']') or
     (prev_char == '(' and next_char == ')') then
    return '<Space><Space><Left>'
  end
  
  return '<Space>'
end

function M.setup()
  -- Asymmetric pairs
  for open_char, close_char in pairs(asymmetric_pairs) do
    vim.keymap.set('i', open_char, function()
      return insert_asymmetric_pair(open_char)
    end, { expr = true, noremap = true, silent = true })
    
    vim.keymap.set('i', close_char, function()
      return skip_or_insert(close_char)
    end, { expr = true, noremap = true, silent = true })
  end
  
  -- Symmetric pairs
  for _, char in ipairs(symmetric_pairs) do
    vim.keymap.set('i', char, function()
      return handle_symmetric_pair(char)
    end, { expr = true, noremap = true, silent = true })
  end
  
  -- Smart backspace
  vim.keymap.set('i', '<BS>', function()
    return smart_backspace()
  end, { expr = true, noremap = true, silent = true })
  
  -- Smart enter
  vim.keymap.set('i', '<CR>', function()
    return smart_enter()
  end, { expr = true, noremap = true, silent = true })
  
  -- Smart space (optional, but super useful!)
  vim.keymap.set('i', '<Space>', function()
    return smart_space()
  end, { expr = true, noremap = true, silent = true })
  
  print('✨ Autopairs loaded!')
end

return M