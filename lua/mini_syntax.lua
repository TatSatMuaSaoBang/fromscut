-- mini_syntax.lua
-- A homemade, pattern-based syntax highlighter.
-- No treesitter. No C compiler. No downloaded parser binaries.
-- It tokenizes visible lines with plain Lua patterns and paints them with
-- extmarks, reusing the highlight groups theme.lua already defines
-- (Keyword, String, Comment, Number, Function, PreProc, Identifier...).
--
-- PERF NOTES (v2 — fixed a real lag source):
--   * schedule_highlight used to call vim.defer_fn() on every single
--     keystroke. vim.defer_fn creates a brand-new libuv timer each call,
--     and the old code only ever :stop()'d the previous one instead of
--     :close()'ing it — so every keystroke leaked a timer handle. Over a
--     long editing session that's thousands of never-freed handles, which
--     shows up exactly as "gets laggier the longer I type". Fixed by
--     keeping ONE persistent timer per buffer (vim.uv.new_timer()) that
--     gets reused via :stop()/:start(), and properly :close()'d on
--     BufDelete.
--   * DEBOUNCE_MS raised from 40 -> 120ms. 40ms was too short to actually
--     coalesce fast typing, so it was running a full re-highlight on
--     nearly every keystroke anyway.
--   * PAD_LINES halved 40 -> 20. Each highlight pass tokenizes
--     (PAD_LINES*2 + visible window) lines character-by-character in pure
--     Lua — this is the single most expensive part of a highlight pass,
--     so scanning less is the biggest lever for feel.
--   * nvim_buf_clear_namespace now only clears the [top, bottom) range
--     being redrawn instead of the whole buffer (0, -1). On long files
--     the old approach re-cleared everything every pass even though only
--     a small window was ever repainted.

local M = {}

local ns = vim.api.nvim_create_namespace('mini_syntax')

local function keyword_set(list)
  local set = {}
  for _, w in ipairs(list) do
    set[w] = true
  end
  return set
end

-- rules_by_ft[filetype] = {
--   keywords       = set of keyword strings,
--   line_comment   = lua-pattern-safe literal prefix, e.g. '//',
--   block_comment  = { open = pattern, close = pattern },
--   string_delims  = { '"', "'", ... },
--   preproc        = pattern for a leading preprocessor line (C/C++), optional
-- }
local rules_by_ft = {}

rules_by_ft.lua = {
  keywords = keyword_set({
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
    'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return',
    'then', 'true', 'until', 'while',
  }),
  line_comment = '--',
  block_comment = { open = '%-%-%[%[', close = '%]%]' },
  string_delims = { '"', "'" },
}

rules_by_ft.python = {
  keywords = keyword_set({
    'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
    'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
    'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is',
    'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try',
    'while', 'with', 'yield',
  }),
  line_comment = '#',
  string_delims = { '"', "'" },
}

rules_by_ft.javascript = {
  keywords = keyword_set({
    'async', 'await', 'break', 'case', 'catch', 'class', 'const',
    'continue', 'debugger', 'default', 'delete', 'do', 'else', 'export',
    'extends', 'finally', 'for', 'function', 'if', 'import', 'in',
    'instanceof', 'let', 'new', 'return', 'super', 'switch', 'this',
    'throw', 'try', 'typeof', 'var', 'void', 'while', 'with', 'yield',
  }),
  line_comment = '//',
  block_comment = { open = '/%*', close = '%*/' },
  string_delims = { '"', "'", '`' },
}
rules_by_ft.typescript = rules_by_ft.javascript
rules_by_ft.javascriptreact = rules_by_ft.javascript
rules_by_ft.typescriptreact = rules_by_ft.javascript

rules_by_ft.cpp = {
  keywords = keyword_set({
    'alignas', 'alignof', 'and', 'asm', 'auto', 'bool', 'break', 'case',
    'catch', 'char', 'class', 'const', 'constexpr', 'continue', 'default',
    'delete', 'do', 'double', 'else', 'enum', 'explicit', 'export',
    'extern', 'false', 'float', 'for', 'friend', 'goto', 'if', 'inline',
    'int', 'long', 'mutable', 'namespace', 'new', 'noexcept', 'nullptr',
    'operator', 'private', 'protected', 'public', 'register', 'return',
    'short', 'signed', 'sizeof', 'static', 'struct', 'switch', 'template',
    'this', 'throw', 'true', 'try', 'typedef', 'typename', 'union',
    'unsigned', 'using', 'virtual', 'void', 'volatile', 'while',
  }),
  line_comment = '//',
  block_comment = { open = '/%*', close = '%*/' },
  string_delims = { '"', "'" },
  preproc = '^%s*#',
}
rules_by_ft.c = rules_by_ft.cpp

rules_by_ft.java = {
  keywords = keyword_set({
    'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch',
    'char', 'class', 'const', 'continue', 'default', 'do', 'double',
    'else', 'enum', 'extends', 'final', 'finally', 'float', 'for', 'goto',
    'if', 'implements', 'import', 'instanceof', 'int', 'interface',
    'long', 'native', 'new', 'package', 'private', 'protected', 'public',
    'return', 'short', 'static', 'strictfp', 'super', 'switch',
    'synchronized', 'this', 'throw', 'throws', 'transient', 'try', 'void',
    'volatile', 'while',
  }),
  line_comment = '//',
  block_comment = { open = '/%*', close = '%*/' },
  string_delims = { '"', "'" },
}

-- how far outside the visible window (in lines) to also highlight, so
-- scrolling a bit doesn't flash unhighlighted text before the next pass
local PAD_LINES = 20
-- debounce delay in ms before a buffer is re-highlighted after an edit/scroll
local DEBOUNCE_MS = 120

local function set_hl(bufnr, line, col_start, col_end, group)
  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line, col_start, {
    end_col = col_end,
    hl_group = group,
    priority = 110,
  })
end

-- Highlights one line given the filetype rules and whether the line starts
-- inside an unterminated block comment. Returns whether the line ends
-- inside an unterminated block comment (carried into the next line).
local function highlight_line(bufnr, line_idx, text, rules, in_block_comment)
  local len = #text
  local i = 1

  if in_block_comment and rules.block_comment then
    local _, close_e = text:find(rules.block_comment.close)
    if close_e then
      set_hl(bufnr, line_idx, 0, close_e, 'Comment')
      i = close_e + 1
      in_block_comment = false
    else
      set_hl(bufnr, line_idx, 0, len, 'Comment')
      return true
    end
  end

  if rules.preproc then
    local s, e = text:find(rules.preproc)
    if s then
      set_hl(bufnr, line_idx, s - 1, e, 'PreProc')
    end
  end

  while i <= len do
    local c = text:sub(i, i)

    if rules.line_comment and text:sub(i, i + #rules.line_comment - 1) == rules.line_comment then
      set_hl(bufnr, line_idx, i - 1, len, 'Comment')
      break
    end

    if rules.block_comment then
      local s, e = text:find(rules.block_comment.open, i)
      if s == i then
        local _, close_e = text:find(rules.block_comment.close, e + 1)
        if close_e then
          set_hl(bufnr, line_idx, i - 1, close_e, 'Comment')
          i = close_e + 1
          goto continue
        else
          set_hl(bufnr, line_idx, i - 1, len, 'Comment')
          return true
        end
      end
    end

    if rules.string_delims then
      local matched_delim = false
      for _, delim in ipairs(rules.string_delims) do
        if c == delim then
          local j = i + 1
          while j <= len and text:sub(j, j) ~= delim do
            if text:sub(j, j) == '\\' then
              j = j + 1
            end
            j = j + 1
          end
          j = math.min(j, len)
          set_hl(bufnr, line_idx, i - 1, j, 'String')
          i = j + 1
          matched_delim = true
          break
        end
      end
      if matched_delim then
        goto continue
      end
    end

    if c:match('%d') and not text:sub(i - 1, i - 1):match('[%w_]') then
      local s, e = text:find('^%d[%d%.xXa-fA-F]*', i)
      if s then
        set_hl(bufnr, line_idx, s - 1, e, 'Number')
        i = e + 1
        goto continue
      end
    end

    if c:match('[%a_]') then
      local s, e = text:find('^[%w_]+', i)
      if s then
        local word = text:sub(s, e)
        if rules.keywords[word] then
          set_hl(bufnr, line_idx, s - 1, e, 'Keyword')
        elseif text:sub(e + 1, e + 1) == '(' then
          set_hl(bufnr, line_idx, s - 1, e, 'Function')
        end
        i = e + 1
        goto continue
      end
    end

    i = i + 1
    ::continue::
  end

  return false
end

local function highlight_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local ft = vim.bo[bufnr].filetype
  local rules = rules_by_ft[ft]
  if not rules then
    return
  end

  local win = vim.fn.bufwinid(bufnr)
  local top, bottom
  if win ~= -1 then
    top = math.max(0, vim.fn.line('w0', win) - PAD_LINES)
    bottom = vim.fn.line('w$', win) + PAD_LINES
  else
    top = 0
    bottom = vim.api.nvim_buf_line_count(bufnr)
  end

  -- Only clear the range we're about to repaint, not the whole buffer —
  -- clearing (0, -1) every pass got expensive on long files with lots of
  -- accumulated extmarks for no benefit, since only [top, bottom) is ever
  -- redrawn here anyway.
  vim.api.nvim_buf_clear_namespace(bufnr, ns, top, bottom)

  local lines = vim.api.nvim_buf_get_lines(bufnr, top, bottom, false)
  local in_comment = false
  for offset, text in ipairs(lines) do
    in_comment = highlight_line(bufnr, top + offset - 1, text, rules, in_comment)
  end
end

-- One persistent libuv timer per buffer, reused via :stop()/:start() and
-- properly :close()'d on BufDelete — see PERF NOTES at the top of this file
-- for why this replaced the old vim.defer_fn()-per-keystroke approach.
local timers = {}

local function schedule_highlight(bufnr)
  if not rules_by_ft[vim.bo[bufnr].filetype] then
    return
  end

  local timer = timers[bufnr]
  if not timer then
    timer = vim.uv.new_timer()
    timers[bufnr] = timer
  end

  timer:stop()
  timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    highlight_buffer(bufnr)
  end))
end

local function cleanup_timer(bufnr)
  local timer = timers[bufnr]
  if timer then
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    timers[bufnr] = nil
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('MiniSyntax', { clear = true })

  -- Supported filetypes get vim's builtin regex syntax turned off so the
  -- two systems don't fight over the same highlight groups.
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    callback = function(args)
      if rules_by_ft[vim.bo[args.buf].filetype] then
        vim.bo[args.buf].syntax = ''
      end
      schedule_highlight(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    callback = function(args)
      schedule_highlight(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'InsertLeave' }, {
    group = group,
    callback = function(args)
      schedule_highlight(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd('WinScrolled', {
    group = group,
    callback = function()
      schedule_highlight(vim.api.nvim_get_current_buf())
    end,
  })

  -- Free the timer handle instead of leaking it when a buffer goes away.
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(args)
      cleanup_timer(args.buf)
    end,
  })
end

-- Manual refresh, exposed for a keymap.
function M.refresh()
  highlight_buffer(vim.api.nvim_get_current_buf())
end

-- Let other configs register more filetypes without editing this file.
function M.register_filetype(ft, rules)
  rules_by_ft[ft] = rules
end

return M