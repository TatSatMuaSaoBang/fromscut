local M = {}

local buf_inp, buf_out, buf_control
local win_inp, win_out, win_control
local main_file = nil

local function ensure_files_exist()
  local cwd = vim.fn.getcwd()
  local inp_path = cwd .. "/inp.inp"
  local out_path = cwd .. "/out.out"
  
  -- Create inp.inp if it doesn't exist
  local inp_file = io.open(inp_path, "r")
  if not inp_file then
    inp_file = io.open(inp_path, "w")
    if inp_file then
      inp_file:write("")
      inp_file:close()
    end
  else
    inp_file:close()
  end
  
  -- Create out.out if it doesn't exist
  local out_file = io.open(out_path, "r")
  if not out_file then
    out_file = io.open(out_path, "w")
    if out_file then
      out_file:write("")
      out_file:close()
    end
  else
    out_file:close()
  end
  
  return inp_path, out_path
end

local function close_testcase()
  -- Close windows
  if win_control and vim.api.nvim_win_is_valid(win_control) then
    vim.api.nvim_win_close(win_control, true)
  end
  if win_inp and vim.api.nvim_win_is_valid(win_inp) then
    vim.api.nvim_win_close(win_inp, true)
  end
  if win_out and vim.api.nvim_win_is_valid(win_out) then
    vim.api.nvim_win_close(win_out, true)
  end
  
  -- Close and delete inp.inp and out.out buffers
  if buf_inp and vim.api.nvim_buf_is_valid(buf_inp) then
    vim.api.nvim_buf_delete(buf_inp, { force = true })
  end
  if buf_out and vim.api.nvim_buf_is_valid(buf_out) then
    vim.api.nvim_buf_delete(buf_out, { force = true })
  end
  if buf_control and vim.api.nvim_buf_is_valid(buf_control) then
    vim.api.nvim_buf_delete(buf_control, { force = true })
  end
  
  buf_inp, buf_out, buf_control = nil, nil, nil
  win_inp, win_out, win_control = nil, nil, nil
  
  print("✓ Testcase mode closed")
end

local function render_control_panel(status_msg)
  if not vim.api.nvim_buf_is_valid(buf_control) then return end
  
  vim.api.nvim_buf_set_option(buf_control, 'modifiable', true)
  
  local lines = {}
  local width = 80
  
  table.insert(lines, "╭" .. string.rep("─", width - 2) .. "╮")
  
  if status_msg then
    local msg = string.format("%-" .. (width - 4) .. "s", status_msg)
    table.insert(lines, "│ " .. msg .. " │")
    table.insert(lines, "├" .. string.rep("─", width - 2) .. "┤")
  end
  
  table.insert(lines, "│" .. string.rep(" ", width - 2) .. "│")
  
  local start_btn = "[ ▶ START ]"
  local exit_btn = "[ ✕ EXIT ]"
  local padding = math.floor((width - 2 - #start_btn - #exit_btn - 6) / 2)
  
  local btn_line = "│" .. string.rep(" ", padding) .. start_btn .. 
                   string.rep(" ", 6) .. exit_btn .. 
                   string.rep(" ", width - 2 - padding - #start_btn - #exit_btn - 6) .. "│"
  table.insert(lines, btn_line)
  
  table.insert(lines, "│" .. string.rep(" ", width - 2) .. "│")
  table.insert(lines, "╰" .. string.rep("─", width - 2) .. "╯")
  table.insert(lines, " Press Ctrl+g then 's' to START  |  Press Ctrl+g then 'e' to EXIT")
  
  vim.api.nvim_buf_set_lines(buf_control, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf_control, 'modifiable', false)
end

local function run_current_file()
  if not main_file then
    render_control_panel("⚠ No file is currently open to run!")
    return
  end
  
  local cwd = vim.fn.getcwd()
  local inp_path = cwd .. "/inp.inp"
  
  -- Save all buffers
  vim.cmd("silent! wa")
  
  -- Determine file extension and run command
  local ext = main_file:match("%.([^%.]+)$")
  local cmd
  
  if ext == "cpp" or ext == "cc" or ext == "cxx" then
    local exe = main_file:gsub("(%.[^%.]+)$", "")
    cmd = string.format("g++ -std=c++17 -O2 %s -o %s && %s < %s", 
                       vim.fn.shellescape(main_file), 
                       vim.fn.shellescape(exe),
                       vim.fn.shellescape(exe),
                       vim.fn.shellescape(inp_path))
  elseif ext == "py" then
    cmd = string.format("python3 %s < %s", 
                       vim.fn.shellescape(main_file), 
                       vim.fn.shellescape(inp_path))
  elseif ext == "java" then
    local class_name = main_file:match("([^/\\]+)%.java$")
    cmd = string.format("javac %s && java %s < %s", 
                       vim.fn.shellescape(main_file),
                       class_name:gsub("%.java$", ""),
                       vim.fn.shellescape(inp_path))
  elseif ext == "js" then
    cmd = string.format("node %s < %s", 
                       vim.fn.shellescape(main_file), 
                       vim.fn.shellescape(inp_path))
  else
    render_control_panel("⚠ Unsupported file type: " .. (ext or "unknown"))
    return
  end
  
  render_control_panel("⏳ Running " .. vim.fn.fnamemodify(main_file, ":t") .. "...")
  
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        local output = table.concat(data, "\n")
        if output:match("%S") then
          local out_path = cwd .. "/out.out"
          local file = io.open(out_path, "w")
          if file then
            file:write(output)
            file:close()
            -- Reload out.out buffer
            if vim.api.nvim_buf_is_valid(buf_out) then
              vim.api.nvim_buf_call(buf_out, function()
                vim.cmd("edit!")
              end)
            end
            render_control_panel("✓ Completed successfully!")
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        local errors = table.concat(data, "\n")
        if errors:match("%S") then
          render_control_panel("✗ Error: " .. errors:sub(1, 60))
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        render_control_panel("✗ Execution failed with exit code " .. exit_code)
      end
    end
  })
end

local function is_testcase_active()
  return win_inp and vim.api.nvim_win_is_valid(win_inp)
end

local function open_testcase()
  -- Get the current file being edited
  main_file = vim.api.nvim_buf_get_name(0)
  if main_file == "" then
    print("⚠ Please open a file first before using testcase mode")
    return
  end
  
  -- Ensure inp.inp and out.out exist
  local inp_path, out_path = ensure_files_exist()
  
  -- Calculate window dimensions
  local ui = vim.api.nvim_list_uis()[1]
  local total_width = ui.width
  local total_height = ui.height
  
  local win_width = math.floor(total_width * 0.8)
  local win_height = math.floor(total_height * 0.7)
  local file_width = math.floor(win_width / 2) - 1
  local control_height = 7
  
  local start_col = math.floor((total_width - win_width) / 2)
  local start_row = math.floor((total_height - win_height - control_height) / 2)
  
  -- Create buffers
  buf_inp = vim.api.nvim_create_buf(false, false)
  buf_out = vim.api.nvim_create_buf(false, false)
  buf_control = vim.api.nvim_create_buf(false, true)
  
  -- Load files into buffers
  vim.api.nvim_buf_call(buf_inp, function()
    vim.cmd("edit " .. vim.fn.fnameescape(inp_path))
  end)
  
  vim.api.nvim_buf_call(buf_out, function()
    vim.cmd("edit " .. vim.fn.fnameescape(out_path))
  end)
  
  -- Create inp.inp window (left)
  win_inp = vim.api.nvim_open_win(buf_inp, true, {
    relative = 'editor',
    width = file_width,
    height = win_height,
    col = start_col,
    row = start_row,
    style = 'minimal',
    border = 'rounded',
    title = ' inp.inp ',
    title_pos = 'center'
  })
  
  -- Create out.out window (right)
  win_out = vim.api.nvim_open_win(buf_out, false, {
    relative = 'editor',
    width = file_width,
    height = win_height,
    col = start_col + file_width + 2,
    row = start_row,
    style = 'minimal',
    border = 'rounded',
    title = ' out.out ',
    title_pos = 'center'
  })
  
  -- Create control panel window (bottom)
  win_control = vim.api.nvim_open_win(buf_control, false, {
    relative = 'editor',
    width = win_width,
    height = control_height,
    col = start_col,
    row = start_row + win_height + 1,
    style = 'minimal',
    border = 'none'
  })
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf_control, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_control, 'filetype', 'testcase-control')
  
  -- Window options for control panel
  vim.api.nvim_win_set_option(win_control, 'cursorline', false)
  vim.api.nvim_win_set_option(win_control, 'number', false)
  vim.api.nvim_win_set_option(win_control, 'relativenumber', false)
  
  -- Set up keymaps for all three windows
  local function setup_keymaps(buf)
    -- Navigate between windows
    vim.keymap.set('n', '<C-h>', function()
      if vim.api.nvim_win_is_valid(win_inp) then
        vim.api.nvim_set_current_win(win_inp)
      end
    end, { buffer = buf, silent = true })
    
    vim.keymap.set('n', '<C-l>', function()
      if vim.api.nvim_win_is_valid(win_out) then
        vim.api.nvim_set_current_win(win_out)
      end
    end, { buffer = buf, silent = true })
    
    vim.keymap.set('n', '<C-j>', function()
      if vim.api.nvim_win_is_valid(win_control) then
        vim.api.nvim_set_current_win(win_control)
      end
    end, { buffer = buf, silent = true })
    
    vim.keymap.set('n', '<C-k>', function()
      local current = vim.api.nvim_get_current_win()
      if current == win_control then
        if vim.api.nvim_win_is_valid(win_inp) then
          vim.api.nvim_set_current_win(win_inp)
        end
      end
    end, { buffer = buf, silent = true })
  end
  
  setup_keymaps(buf_inp)
  setup_keymaps(buf_out)
  setup_keymaps(buf_control)
  
  -- Render control panel
  render_control_panel("Ready! Press Ctrl+g then 's' to START or Ctrl+g then 'e' to EXIT")
  
  -- Focus on inp.inp
  vim.api.nvim_set_current_win(win_inp)
end

function M.toggle()
  if win_inp and vim.api.nvim_win_is_valid(win_inp) then
    close_testcase()
  else
    open_testcase()
  end
end

function M.start()
  if is_testcase_active() then
    run_current_file()
  else
    print("⚠ Warning: Testcase mode is not active! Press Ctrl+g+g first.")
  end
end

function M.exit()
  if is_testcase_active() then
    close_testcase()
  else
    print("⚠ Warning: Testcase mode is not active!")
  end
end

return M