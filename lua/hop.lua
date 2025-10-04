local M = {}

local namespace = vim.api.nvim_create_namespace('hop_highlight')
local active = false
local positions = {}

local function clear_highlights()
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  positions = {}
  active = false
end

local function get_first_letter_positions(start_line, end_line)
  local pos = {}
  local idx = 1
  
  for line_num = start_line, end_line do
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
    if line then
      local in_word = false
      for col = 1, #line do
        local char = line:sub(col, col)
        -- Check if this is the start of a word (alphanumeric or underscore)
        if char:match('[%w_]') then
          if not in_word then
            table.insert(pos, {
              line = line_num,
              col = col,
              idx = idx
            })
            idx = idx + 1
            in_word = true
          end
        else
          in_word = false
        end
      end
    end
  end
  
  return pos
end

local function create_virtual_text(line, col, number)
  -- Create highlight group with yellow background
  vim.api.nvim_set_hl(0, 'HopLabel', { fg = '#000000', bg = '#FFFF00', bold = true })
  
  -- Place virtual text at the position
  vim.api.nvim_buf_set_extmark(0, namespace, line - 1, col - 1, {
    virt_text = {{ tostring(number), 'HopLabel' }},
    virt_text_pos = 'overlay',
    priority = 1000,
  })
end

local function highlight_positions(start_line, end_line)
  positions = get_first_letter_positions(start_line, end_line)
  
  if #positions == 0 then
    print("No words found to hop to!")
    return false
  end
  
  for _, pos in ipairs(positions) do
    create_virtual_text(pos.line, pos.col, pos.idx)
  end
  
  return true
end

local function hop_to_position(number)
  for _, pos in ipairs(positions) do
    if pos.idx == number then
      -- Move cursor to the position
      vim.api.nvim_win_set_cursor(0, {pos.line, pos.col - 1})
      clear_highlights()
      return true
    end
  end
  return false
end

local function setup_input_handler()
  local input = ""
  local max_idx = #positions
  local max_digits = tostring(max_idx):len()
  
  -- Set up temporary keymaps for number input
  local function handle_number(num)
    return function()
      if not active then return end
      
      input = input .. tostring(num)
      local target = tonumber(input)
      
      -- If we've reached max digits or the number is valid
      if #input >= max_digits or target > max_idx then
        if hop_to_position(target) then
          return
        else
          -- Invalid number, try single digit
          local single = tonumber(input:sub(-1))
          if hop_to_position(single) then
            return
          end
        end
        -- If nothing worked, clear and reset
        input = ""
        clear_highlights()
      elseif target <= max_idx and target > 0 then
        -- Check if this could be a complete number
        local could_be_more = false
        for _, pos in ipairs(positions) do
          local idx_str = tostring(pos.idx)
          if idx_str:sub(1, #input) == input and #idx_str > #input then
            could_be_more = true
            break
          end
        end
        
        if not could_be_more then
          -- This is a complete number
          hop_to_position(target)
        end
      end
    end
  end
  
  -- Map number keys
  local keymaps = {}
  for i = 0, 9 do
    local map_id = vim.keymap.set('n', tostring(i), handle_number(i), { 
      buffer = true, 
      silent = true,
      nowait = true 
    })
    table.insert(keymaps, {i, map_id})
  end
  
  -- Escape to cancel
  vim.keymap.set('n', '<Esc>', function()
    clear_highlights()
    -- Clean up number keymaps
    for i = 0, 9 do
      pcall(vim.keymap.del, 'n', tostring(i), { buffer = true })
    end
  end, { buffer = true, silent = true, nowait = true })
end

function M.hop_line()
  if active then
    clear_highlights()
    return
  end
  
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  
  if highlight_positions(current_line, current_line) then
    active = true
    setup_input_handler()
  end
end

function M.hop_visual()
  if active then
    clear_highlights()
    return
  end
  
  -- Get visual selection range
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  
  -- Exit visual mode
  vim.cmd('normal! ')
  
  if highlight_positions(start_line, end_line) then
    active = true
    setup_input_handler()
  end
end

return M