local M = {}

local namespace = vim.api.nvim_create_namespace('buffer_mask')
local active = false
local mode = nil  -- 'close' or 'switch'

local function clear_masks()
  vim.opt.tabline = '%!v:lua.custom_bufferline()'
  active = false
  mode = nil
  
  -- Clean up number keymaps
  for i = 0, 9 do
    pcall(vim.keymap.del, 'n', tostring(i))
  end
  pcall(vim.keymap.del, 'n', '<Esc>')
end

local function get_listed_buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(buf) == 1 then
      table.insert(buffers, buf)
    end
  end
  return buffers
end

local function create_masked_bufferline()
  local buffers = get_listed_buffers()
  local current = vim.api.nvim_get_current_buf()
  
  if #buffers == 0 then
    return '%#TabLineFill#'
  end
  
  local line = ""
  for idx, buf in ipairs(buffers) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
    if name == '' then name = '[No Name]' end
    
    local modified = vim.fn.getbufvar(buf, "&modified") == 1 and ' [+]' or ''
    
    -- Show mask number with highlight
    local mask = '%#BufferMask#[' .. idx .. ']%#TabLine# '
    
    if buf == current then
      line = line .. mask .. '%#TabLineSel# ' .. name .. modified .. ' %#TabLine#'
    else
      line = line .. mask .. ' ' .. name .. modified .. ' '
    end
    
    line = line .. '│'
  end
  
  return line .. '%#TabLineFill#'
end

local function handle_buffer_action(num)
  local buffers = get_listed_buffers()
  
  if num < 1 or num > #buffers then
    clear_masks()
    return
  end
  
  local target_buf = buffers[num]
  
  if mode == 'close' then
    -- Close the buffer
    if vim.fn.getbufvar(target_buf, "&modified") == 1 then
      local choice = vim.fn.confirm(
        'Buffer has unsaved changes. Save before closing?',
        '&Save\n&Discard\n&Cancel'
      )
      if choice == 1 then
        vim.api.nvim_buf_call(target_buf, function()
          vim.cmd('write')
        end)
        vim.cmd('bdelete ' .. target_buf)
      elseif choice == 2 then
        vim.cmd('bdelete! ' .. target_buf)
      end
    else
      vim.cmd('bdelete ' .. target_buf)
    end
  elseif mode == 'switch' then
    -- Switch to the buffer
    vim.cmd('buffer ' .. target_buf)
  end
  
  clear_masks()
end

local function setup_number_handler()
  local input = ""
  local max_buffers = #get_listed_buffers()
  local max_digits = tostring(max_buffers):len()
  
  for i = 0, 9 do
    vim.keymap.set('n', tostring(i), function()
      if not active then return end
      
      input = input .. tostring(i)
      local num = tonumber(input)
      
      -- If we've typed enough digits or number is out of range
      if #input >= max_digits or num > max_buffers then
        -- Try the full number first
        if num <= max_buffers then
          handle_buffer_action(num)
          return
        end
        -- Try just the last digit
        local single = tonumber(input:sub(-1))
        if single <= max_buffers then
          handle_buffer_action(single)
          return
        end
        -- Invalid, reset
        input = ""
        clear_masks()
        return
      end
      
      -- Check if current input could be extended
      local could_extend = false
      for idx = 1, max_buffers do
        local idx_str = tostring(idx)
        if idx_str:sub(1, #input) == input and #idx_str > #input then
          could_extend = true
          break
        end
      end
      
      -- If can't extend or is valid complete number, execute
      if not could_extend and num <= max_buffers then
        handle_buffer_action(num)
      end
    end, { noremap = true, silent = true, nowait = true })
  end
  
  vim.keymap.set('n', '<Esc>', function()
    clear_masks()
  end, { noremap = true, silent = true, nowait = true })
end

function M.close_buffer()
  if active then
    clear_masks()
    return
  end
  
  local buffers = get_listed_buffers()
  if #buffers == 0 then
    print("No buffers to close")
    return
  end
  
  mode = 'close'
  active = true
  
  -- Update tabline with masks
  vim.opt.tabline = '%!v:lua.masked_bufferline()'
  
  setup_number_handler()
end

function M.switch_buffer()
  if active then
    clear_masks()
    return
  end
  
  local buffers = get_listed_buffers()
  if #buffers == 0 then
    print("No buffers to switch to")
    return
  end
  
  mode = 'switch'
  active = true
  
  -- Update tabline with masks
  vim.opt.tabline = '%!v:lua.masked_bufferline()'
  
  setup_number_handler()
end

-- Global function for tabline
_G.masked_bufferline = create_masked_bufferline

-- Define highlight group for mask numbers
vim.api.nvim_set_hl(0, 'BufferMask', { fg = '#000000', bg = '#FFFF00', bold = true })

return M