-- ~/.config/nvim/lua/notification.lua
--------------------------------------------------------------------------
-- notification.lua — homemade notification system
--
-- Why not nvim-notify/noice: those pull in plenary/treesitter/nui and a lot
-- of machinery. This is ~1 file, native API only, and covers what you
-- actually use a notifier for:
--
--   * replaces vim.notify, so every plugin's messages land here
--   * stacked popups in a screen corner, auto-dismissed, optional fade-out
--   * duplicate messages merge into one popup with an (x3) counter
--   * notify() returns an id -> you can replace or dismiss that popup later
--   * progress() gives you a spinner popup for long-running jobs
--   * scrollable history (nothing is ever lost to a 200ms popup again)
--   * never steals focus, never enters the buffer list, never blocks
--
-- API
--   require("notification").notify(msg, level, opts) -> id
--   ... .info/.warn/.error/.debug(msg, opts)         -> id
--   ... .dismiss(id) / .dismiss_all() / .count()
--   ... .show_history() / .history() / .clear_history()
--   ... .progress("Title")  -> handle:report(msg) / handle:finish(msg)
--
-- opts: title, icon, timeout (ms, or false = sticky), replace (id), level
--------------------------------------------------------------------------

local api = vim.api
local uv = vim.uv or vim.loop
local L = vim.log.levels

local M = {}

local LEVEL_NAME = {
  [L.TRACE] = "TRACE", [L.DEBUG] = "DEBUG", [L.INFO] = "INFO",
  [L.WARN]  = "WARN",  [L.ERROR] = "ERROR",
}
local NAME_LEVEL = {
  TRACE = L.TRACE, DEBUG = L.DEBUG, INFO = L.INFO, WARN = L.WARN, ERROR = L.ERROR,
}

--------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------
M.config = {
  timeout = 3000,                                  -- default lifetime (ms)
  level_timeout = { WARN = 5000, ERROR = 7000 },   -- louder levels stay longer
  min_level = L.INFO,                              -- drop DEBUG/TRACE spam
  position = "top_right",                          -- also bottom_right/top_left/bottom_left
  margin = { top = 1, right = 2, bottom = 1 },
  gap = 1,
  min_width = 22,
  max_width = 64,
  max_height = 12,
  border = "rounded",
  winblend = 10,
  fade = true,
  merge_duplicates = true,
  history_limit = 200,
  override_vim_notify = true,
  -- Nerd Font glyphs; swap for { INFO="i", WARN="!", ERROR="x", ... } if needed.
  icons = { TRACE = "", DEBUG = "", INFO = "", WARN = "", ERROR = "" },
}

--------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------
local ns = api.nvim_create_namespace("notification")
local state = { seq = 0, active = {}, history = {}, initialized = false }

--------------------------------------------------------------------------
-- Highlights (linked with default=true so your theme.lua always wins)
--------------------------------------------------------------------------
local function setup_highlights()
  local links = {
    NotificationBody        = "NormalFloat",
    NotificationCount       = "Comment",
    NotificationTitleTRACE  = "Comment",
    NotificationTitleDEBUG  = "Comment",
    NotificationTitleINFO   = "DiagnosticInfo",
    NotificationTitleWARN   = "DiagnosticWarn",
    NotificationTitleERROR  = "DiagnosticError",
    NotificationBorderTRACE = "FloatBorder",
    NotificationBorderDEBUG = "FloatBorder",
    NotificationBorderINFO  = "DiagnosticInfo",
    NotificationBorderWARN  = "DiagnosticWarn",
    NotificationBorderERROR = "DiagnosticError",
  }
  for from, to in pairs(links) do
    api.nvim_set_hl(0, from, { link = to, default = true })
  end
end

--------------------------------------------------------------------------
-- Text helpers
--------------------------------------------------------------------------
local function push_wrapped(out, line, width)
  while vim.fn.strdisplaywidth(line) > width do
    local head = vim.fn.strcharpart(line, 0, width)
    if head == "" then break end
    table.insert(out, head)
    line = vim.fn.strcharpart(line, width)
  end
  table.insert(out, line)
end

local function wrap_text(text, width)
  local out = {}
  text = (tostring(text):gsub("\r", ""))
  for _, para in ipairs(vim.split(text, "\n", { plain = true })) do
    if vim.fn.strdisplaywidth(para) <= width then
      table.insert(out, para)          -- short line: keep indentation intact
    else
      local line = ""
      for word in para:gmatch("%S+") do
        if line == "" then
          line = word
        elseif vim.fn.strdisplaywidth(line .. " " .. word) <= width then
          line = line .. " " .. word
        else
          push_wrapped(out, line, width)
          line = word
        end
      end
      push_wrapped(out, line, width)
    end
  end
  if #out == 0 then out = { "" } end
  return out
end

--------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------
local function usable_height()
  local h = vim.o.lines - vim.o.cmdheight
  if vim.o.laststatus > 0 then h = h - 1 end
  return h
end

local function top_offset()
  local off = M.config.margin.top
  local st = vim.o.showtabline
  if st == 2 or (st == 1 and vim.fn.tabpagenr("$") > 1) then off = off + 1 end
  return off
end

--------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------
local function render_buffer(rec)
  local cfg = M.config
  local budget = cfg.max_width - 2
  local body = wrap_text(rec.message, budget)
  local icon = rec.icon or cfg.icons[rec.level_name] or ""
  local prefix = icon ~= "" and (icon .. "  ") or ""
  local suffix = rec.count > 1 and string.format("  (x%d)", rec.count) or ""
  local title_hl = "NotificationTitle" .. rec.level_name

  local lines, marks = {}, {}
  if rec.title == nil and #body == 1 then
    -- Short one-liner: no header row, the message *is* the header.
    lines[1] = " " .. prefix .. body[1] .. suffix
    table.insert(marks, { row = 0, hl = title_hl })
  else
    lines[1] = " " .. prefix .. (rec.title or rec.level_name) .. suffix
    table.insert(marks, { row = 0, hl = title_hl })
    for i, l in ipairs(body) do lines[i + 1] = " " .. l end
  end

  local width = cfg.min_width
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 1)
  end

  rec.width  = math.min(width, cfg.max_width)
  rec.height = math.min(#lines, cfg.max_height)

  if not (rec.buf and api.nvim_buf_is_valid(rec.buf)) then
    rec.buf = api.nvim_create_buf(false, true)
    vim.bo[rec.buf].bufhidden = "wipe"
    vim.bo[rec.buf].filetype = "notification"
  end

  vim.bo[rec.buf].modifiable = true
  api.nvim_buf_clear_namespace(rec.buf, ns, 0, -1)
  api.nvim_buf_set_lines(rec.buf, 0, -1, false, lines)
  vim.bo[rec.buf].modifiable = false

  for _, m in ipairs(marks) do
    local text = lines[m.row + 1] or ""
    pcall(api.nvim_buf_set_extmark, rec.buf, ns, m.row, 0, {
      end_row = m.row, end_col = #text, hl_group = m.hl,
    })
  end
end

local function relayout()
  local cfg = M.config
  local bottom = cfg.position:match("^bottom") ~= nil
  local left = cfg.position:match("left$") ~= nil
  local avail = usable_height()
  local cursor = bottom and (avail - cfg.margin.bottom) or top_offset()

  local order = {}
  for i, rec in ipairs(state.active) do order[i] = rec end
  if bottom then                                   -- newest nearest the corner
    local rev = {}
    for i = #order, 1, -1 do rev[#rev + 1] = order[i] end
    order = rev
  end

  for _, rec in ipairs(order) do
    if rec.win and api.nvim_win_is_valid(rec.win) then
      local h = rec.height + 2                      -- + border rows
      local row = bottom and (cursor - h) or cursor
      local col = left and cfg.margin.right
        or math.max(0, vim.o.columns - rec.width - 2 - cfg.margin.right)

      pcall(api.nvim_win_set_config, rec.win, {
        relative = "editor",
        row = math.max(0, row),
        col = col,
        width = rec.width,
        height = rec.height,
      })

      cursor = bottom and (row - cfg.gap) or (cursor + h + cfg.gap)
    end
  end
end

local function open_window(rec)
  local cfg = M.config
  rec.win = api.nvim_open_win(rec.buf, false, {
    relative = "editor",
    row = 1, col = 1,                               -- real position set by relayout()
    width = rec.width,
    height = rec.height,
    style = "minimal",
    border = cfg.border,
    focusable = false,
    noautocmd = true,
    zindex = 200,
  })
  api.nvim_win_set_var(rec.win, "is_notification", true)
  local opts = { win = rec.win }
  pcall(api.nvim_set_option_value, "winblend", cfg.winblend, opts)
  pcall(api.nvim_set_option_value, "wrap", false, opts)
  pcall(api.nvim_set_option_value, "winhighlight",
    "Normal:NotificationBody,FloatBorder:NotificationBorder" .. rec.level_name, opts)
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------
local function stop_timer(rec)
  if rec.timer then
    pcall(function() rec.timer:stop(); rec.timer:close() end)
    rec.timer = nil
  end
end

local function destroy(rec)
  stop_timer(rec)
  if rec.win and api.nvim_win_is_valid(rec.win) then
    pcall(api.nvim_win_close, rec.win, true)
  end
  if rec.buf and api.nvim_buf_is_valid(rec.buf) then
    pcall(api.nvim_buf_delete, rec.buf, { force = true })
  end
  rec.win, rec.buf = nil, nil
  for i, r in ipairs(state.active) do
    if r.id == rec.id then table.remove(state.active, i); break end
  end
end

local function fade_out(rec, done)
  local cfg = M.config
  if not cfg.fade or not (rec.win and api.nvim_win_is_valid(rec.win)) then
    return done()
  end
  rec.fading = true
  local steps, i = 6, 0
  local timer, finished = uv.new_timer(), false
  local function stop()
    if finished then return end
    finished = true
    pcall(function() timer:stop(); timer:close() end)
    done()
  end
  timer:start(0, 22, function()
    vim.schedule(function()
      i = i + 1
      if not (rec.win and api.nvim_win_is_valid(rec.win)) or i > steps then
        return stop()
      end
      local blend = math.floor(cfg.winblend + (100 - cfg.winblend) * (i / steps))
      pcall(api.nvim_set_option_value, "winblend", blend, { win = rec.win })
    end)
  end)
end

local function start_timer(rec)
  stop_timer(rec)
  if not rec.timeout or rec.timeout <= 0 then return end   -- sticky
  local timer = uv.new_timer()
  rec.timer = timer
  timer:start(rec.timeout, 0, function()
    vim.schedule(function() M.dismiss(rec.id) end)
  end)
end

local function find(id)
  for _, rec in ipairs(state.active) do
    if rec.id == id then return rec end
  end
end

-- Close oldest popups until `needed` extra rows fit on screen.
local function ensure_space(needed)
  local cfg = M.config
  local avail = usable_height() - top_offset() - cfg.margin.bottom
  local function used()
    local n = 0
    for _, rec in ipairs(state.active) do n = n + rec.height + 2 + cfg.gap end
    return n
  end
  while #state.active > 0 and used() + needed > avail do
    destroy(state.active[1])
  end
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function M.is_notification_win(win)
  local ok, val = pcall(api.nvim_win_get_var, win, "is_notification")
  return ok and val == true
end

function M.count() return #state.active end

function M.dismiss(id)
  local rec = find(id)
  if not rec or rec.fading then return end
  stop_timer(rec)
  fade_out(rec, function()
    destroy(rec)
    relayout()
  end)
end

function M.dismiss_all()
  for i = #state.active, 1, -1 do destroy(state.active[i]) end
  relayout()
end

function M.notify(msg, level, opts)
  opts = opts or {}
  local cfg = M.config

  if type(msg) == "table" then msg = table.concat(msg, "\n") end
  msg = tostring(msg or "")

  if type(level) == "string" then level = NAME_LEVEL[level:upper()] end
  level = level or opts.level or L.INFO
  local name = LEVEL_NAME[level] or "INFO"

  -- History always records, even below min_level and even without a UI.
  local entry = {
    time = os.date("%H:%M:%S"), level = level, level_name = name,
    message = msg, title = opts.title,
  }
  table.insert(state.history, entry)
  if #state.history > cfg.history_limit then table.remove(state.history, 1) end

  if level < cfg.min_level then return end
  if #api.nvim_list_uis() == 0 then                 -- headless: don't try to draw
    io.stderr:write(string.format("[%s] %s\n", name, msg))
    return
  end
  if vim.in_fast_event() then
    vim.schedule(function() M.notify(msg, level, opts) end)
    return
  end

  local timeout = cfg.timeout
  if cfg.level_timeout[name] then timeout = cfg.level_timeout[name] end
  if opts.timeout ~= nil then
    timeout = opts.timeout == false and 0 or opts.timeout
  end

  -- Replace an existing popup in place (used by progress handles).
  local rec = opts.replace and find(opts.replace) or nil

  -- Or merge an identical message that's still on screen.
  if not rec and cfg.merge_duplicates then
    for _, r in ipairs(state.active) do
      if not r.fading and r.message == msg and r.level == level and r.title == opts.title then
        rec = r
        rec.count = rec.count + 1
        break
      end
    end
  end

  if rec then
    rec.message = msg
    rec.level, rec.level_name = level, name
    rec.title = opts.title or rec.title
    rec.icon = opts.icon or rec.icon
    rec.timeout = timeout
    rec.fading = false
    render_buffer(rec)
    if rec.win and api.nvim_win_is_valid(rec.win) then
      pcall(api.nvim_set_option_value, "winblend", cfg.winblend, { win = rec.win })
      pcall(api.nvim_set_option_value, "winhighlight",
        "Normal:NotificationBody,FloatBorder:NotificationBorder" .. name, { win = rec.win })
    else
      open_window(rec)
    end
    relayout()
    start_timer(rec)
    return rec.id
  end

  state.seq = state.seq + 1
  rec = {
    id = state.seq, message = msg, level = level, level_name = name,
    title = opts.title, icon = opts.icon, count = 1, timeout = timeout,
  }
  render_buffer(rec)
  ensure_space(rec.height + 2 + cfg.gap)
  open_window(rec)
  table.insert(state.active, rec)
  relayout()
  start_timer(rec)
  return rec.id
end

function M.info(msg, opts)  return M.notify(msg, L.INFO,  opts) end
function M.warn(msg, opts)  return M.notify(msg, L.WARN,  opts) end
function M.error(msg, opts) return M.notify(msg, L.ERROR, opts) end
function M.debug(msg, opts) return M.notify(msg, L.DEBUG, opts) end

--------------------------------------------------------------------------
-- Progress handles: local p = notification.progress("Installing")
--                   p:report("step 2/5") ... p:finish("done")
--------------------------------------------------------------------------
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.progress(title, opts)
  opts = opts or {}
  local handle = { title = title, message = opts.message or "working...", frame = 1 }
  handle.id = M.notify(handle.message, opts.level or L.INFO, {
    title = title, icon = SPINNER[1], timeout = false,
  })

  local timer = uv.new_timer()
  handle._timer = timer
  timer:start(90, 90, function()
    vim.schedule(function()
      if not find(handle.id) then
        pcall(function() timer:stop(); timer:close() end)
        return
      end
      handle.frame = handle.frame % #SPINNER + 1
      M.notify(handle.message, L.INFO, {
        replace = handle.id, title = handle.title,
        icon = SPINNER[handle.frame], timeout = false,
      })
    end)
  end)

  function handle:report(message)
    self.message = message or self.message
  end

  function handle:finish(message, level)
    pcall(function() self._timer:stop(); self._timer:close() end)
    M.notify(message or "done", level or L.INFO, {
      replace = self.id, title = self.title, icon = nil,
    })
  end

  function handle:cancel()
    pcall(function() self._timer:stop(); self._timer:close() end)
    M.dismiss(self.id)
  end

  return handle
end

--------------------------------------------------------------------------
-- History
--------------------------------------------------------------------------
function M.history() return vim.deepcopy(state.history) end

function M.clear_history()
  state.history = {}
  M.info("Notification history cleared")
end

function M.show_history()
  if #state.history == 0 then
    return M.info("No notifications yet", { title = "History" })
  end

  local lines, marks = {}, {}
  for i = #state.history, 1, -1 do            -- newest first
    local e = state.history[i]
    local head = string.format(" %s  %-5s  ", e.time, e.level_name)
    local pad = string.rep(" ", #head)
    for j, l in ipairs(vim.split(e.message, "\n", { plain = true })) do
      table.insert(lines, (j == 1 and head or pad) .. l)
      if j == 1 then
        local col = #(" " .. e.time .. "  ")
        table.insert(marks, {
          row = #lines - 1, col = col, ecol = col + #e.level_name,
          hl = "NotificationTitle" .. e.level_name,
        })
      end
    end
  end

  local width = M.config.min_width
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
  end
  width = math.min(width, vim.o.columns - 8)
  local height = math.min(#lines, math.floor(vim.o.lines * 0.7))

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "notification-history"

  for _, m in ipairs(marks) do
    pcall(api.nvim_buf_set_extmark, buf, ns, m.row, m.col, {
      end_row = m.row, end_col = m.ecol, hl_group = m.hl,
    })
  end

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = M.config.border,
    title = " Notifications ",
    title_pos = "center",
  })
  pcall(api.nvim_set_option_value, "cursorline", true, { win = win })

  local function close()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true, silent = true })
  end
  vim.keymap.set("n", "C", function() close(); M.clear_history() end,
    { buffer = buf, nowait = true, silent = true, desc = "Clear history" })
end

--------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  if state.initialized then return M end
  state.initialized = true

  setup_highlights()

  local group = api.nvim_create_augroup("Notification", { clear = true })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = setup_highlights })
  api.nvim_create_autocmd({ "VimResized", "TabEnter" }, { group = group, callback = relayout })
  api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function() M.dismiss_all() end })

  api.nvim_create_user_command("Notifications", M.show_history, { desc = "Notification history" })
  api.nvim_create_user_command("NotificationsDismiss", M.dismiss_all, { desc = "Dismiss notifications" })
  api.nvim_create_user_command("NotificationsTest", function()
    M.debug("debug message (hidden unless min_level is lowered)")
    M.info("Saved init.lua")
    M.warn("prettier not found in node_modules, using global", { title = "prettier.nvim" })
    M.error("LSP client pyright exited with code 1\nCheck :LspLog for details", { title = "LSP" })
  end, { desc = "Preview every notification level" })

  if M.config.override_vim_notify then
    vim.notify = function(msg, level, o) return M.notify(msg, level, o) end
  end

  return M
end

return M
