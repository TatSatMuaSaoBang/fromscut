-- autopairs.lua
-- Place this file in your lua/ directory

local M = {}

-- Asymmetric pairs (different open/close)
local asymmetric_pairs = {
  ['('] = ')',
  ['['] = ']',
  ['{'] = '}',
}

-- Symmetric pairs (same char for open/close)
local symmetric_pairs = { '"', "'", '`' }

-- Check if we're inside a string or comment
local function in_string_or_comment()
  local synID = vim.fn.synID(vim.fn.line('.'), vim.fn.col('.'), 1)
  local synName = vim.fn.synIDattr(synID, 'name'):lower()
  return synName:match('string') or synName:match('comment')
end

-- Handle asymmetric opening bracket
local function insert_asymmetric_pair(open_char)
  local close_char = asymmetric_pairs[open_char]
  return open_char .. close_char .. '<Left>'
end

-- Handle symmetric pairs (quotes)
local function handle_symmetric_pair(char)
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local prev_char = line:sub(col - 1, col - 1)
  local next_char = line:sub(col, col)
  
  -- If next char is the same quote, skip over it
  if next_char == char then
    return '<Right>'
  end
  
  -- If previous char is alphanumeric or the same quote, just insert one
  if prev_char:match('[%w_]') or prev_char == char then
    return char
  end
  
  -- If next char is alphanumeric, just insert one (don't pair)
  if next_char:match('[%w_]') then
    return char
  end
  
  -- Otherwise, insert pair
  return char .. char .. '<Left>'
end

-- Handle closing bracket (skip if next char is the same)
local function skip_or_insert(close_char)
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local next_char = line:sub(col, col)
  
  if next_char == close_char then
    return '<Right>'
  else
    return close_char
  end
end

-- Handle backspace (delete pair if next char is closing bracket)
local function smart_backspace()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local prev_char = line:sub(col - 1, col - 1)
  local next_char = line:sub(col, col)
  
  -- Check asymmetric pairs
  if asymmetric_pairs[prev_char] == next_char then
    return '<BS><Del>'
  end
  
  -- Check symmetric pairs
  for _, char in ipairs(symmetric_pairs) do
    if prev_char == char and next_char == char then
      return '<BS><Del>'
    end
  end
  
  return '<BS>'
end

-- Handle Enter key (create pair on new lines for brackets)
local function smart_enter()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local prev_char = line:sub(col - 1, col - 1)
  local next_char = line:sub(col, col)
  
  -- Check if we're between curly braces
  if prev_char == '{' and next_char == '}' then
    return '<CR><Esc>O'
  else
    return '<CR>'
  end
end

function M.setup()
  -- Set up asymmetric pairs (brackets)
  for open_char, close_char in pairs(asymmetric_pairs) do
    vim.keymap.set('i', open_char, function()
      return insert_asymmetric_pair(open_char)
    end, { expr = true, noremap = true, silent = true })
    
    vim.keymap.set('i', close_char, function()
      return skip_or_insert(close_char)
    end, { expr = true, noremap = true, silent = true })
  end
  
  -- Set up symmetric pairs (quotes)
  for _, char in ipairs(symmetric_pairs) do
    vim.keymap.set('i', char, function()
      return handle_symmetric_pair(char)
    end, { expr = true, noremap = true, silent = true })
  end
  
  -- Smart backspace
  vim.keymap.set('i', '<BS>', function()
    return smart_backspace()
  end, { expr = true, noremap = true, silent = true })
  
  -- Smart enter for braces
  vim.keymap.set('i', '<CR>', function()
    -- Check if in completion menu first
    if vim.fn.pumvisible() == 1 then
      return '<C-y>'
    else
      return smart_enter()
    end
  end, { expr = true, noremap = true, silent = true })
  
  print('Autopairs loaded successfully!')
end

return M