-- lua/theme.lua  —  "Solarized Osaka" port (palette lấy thẳng từ craftzdog/solarized-osaka.nvim)
-- Giữ nguyên API cũ: require('theme').setup()  +  thêm require('theme').lualine_theme()
local M = {}

-- Bật =true nếu terminal của bạn trong suốt + có ảnh nền → ra đúng kiểu "xuyên thấu" như ảnh.
-- Để false = nền teal đặc (vẫn đúng màu, chỉ không thấy xuyên qua).
local TRANSPARENT = true

-- Palette (HSL→hex đã chuyển từ colors.lua của solarized-osaka, branch osaka)
local colors = {
  none      = "NONE",
  -- nền / chữ (base tones)
  base04 = "#07141a",  -- bg chính (đen teal)
  base03 = "#0b1d24",  -- bg highlight / float / cursorline
  base02    = "#073541",  -- popup / selection / separator
  base01 = "#6b7682",  -- comment / muted
  base00    = "#647a82",  -- line số mờ / separator
  base0 = "#b8c2c8",  -- chữ thường
  base1 = "#d0d8dc",  -- chữ nhấn
  base2     = "#ede7d4",  -- sáng
  base3     = "#fdf6e2",  -- sáng nhất
  base4     = "#ffffff",
  -- accent
  yellow    = "#b38600",  yellow300 = "#ffbf00",  yellow700 = "#664d00",  yellow900 = "#332700",
  orange = "#d19a66",  orange300 = "#f84f0d",
  red = "#e06c75",  red300    = "#f65351",  red100    = "#ff9b99",  red900    = "#57100f",
  magenta   = "#d33682",  magenta900 = "#541232",
  violet    = "#6d72c5",  violet700 = "#494eb6",  violet900 = "#25285b",
  blue = "#5ea1ff",  blue = "#5ea1ff",  blue900   = "#103956",
  cyan = "#56b6c2",  cyan300 = "#7fd6df",  cyan900   = "#103a3c",
  green = "#98c379",  green300 = "#b6d99b",  green900  = "#2c3300",
  -- vai trò
  black     = "#000305",
  border    = "#000305",
  bg        = "#00141a",
  bg_popup  = "#00141a",
  bg_status = "#002d38",
  fg        = "#9fabad",
  error     = "#dc312e",  warning = "#b38600",  info = "#278bd3",  hint = "#2aa298",
}
M.colors = colors

local BG = TRANSPARENT and "NONE" or colors.base04

function M.setup()
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") then vim.cmd("syntax reset") end
  vim.o.background = "dark"
  vim.g.colors_name = "solarized_osaka_custom"

  local c = colors
  local hl = function(g, o) vim.api.nvim_set_hl(0, g, o) end

  -- ===== Editor UI =====
  hl("CursorLineNr", {
    fg = "#ff9e64",  bg = BG })
  hl("NormalNC",     { fg = c.base00, bg = BG })
  hl("NormalFloat",  { fg = c.base0,  bg = c.base03 })
  hl("FloatBorder",  { fg = c.yellow700, bg = c.base03 })
  hl("CursorLine",   { bg = c.base03 })
  hl("CursorColumn", { bg = c.base03 })
  hl("ColorColumn",  { bg = c.base02 })
  hl("LineNr", {fg = "#9d8b49",  bg = BG })          -- số dòng vàng (như ảnh)
  hl("CursorLineNr", { fg = c.orange,  bg = BG, bold = true }) -- số dòng hiện tại cam đậm
  hl("SignColumn",   { fg = c.base0,  bg = BG })
  hl("VertSplit",    { fg = c.base02 })
  hl("WinSeparator", { fg = c.base02, bold = true })
  hl("EndOfBuffer",  { fg = c.base01 })
  hl("NonText",      { fg = c.base00 })
  hl("Whitespace",   { fg = c.base01 })
  hl("MatchParen",   { fg = c.red100, bg = c.red, bold = true })
  hl("Title",        { fg = c.orange, bold = true })

  -- ===== Statusline / Tabline =====
  hl("StatusLine",   { fg = c.base1, bg = c.base03 })
  hl("StatusLineNC", { fg = c.base00, bg = c.base04 })
  hl("TabLine",      { fg = c.base00, bg = c.base04 })     -- tab không active (chìm vào nền)
  hl("TabLineSel",   { fg = c.base3,  bg = c.base02, bold = true }) -- tab active = chip sáng
  hl("TabLineFill",  { bg = c.base04 })

  -- ===== Syntax (ánh xạ y như theme.lua của osaka) =====
  hl("Comment",    { fg = c.base01, italic = true })
  hl("Constant",   { fg = c.cyan })
  hl("String", {fg = "#9ece6a"})
  hl("Character",  { fg = c.cyan })
  hl("Number",     { fg = c.cyan })
  hl("Boolean",    { fg = c.cyan })
  hl("Identifier", {fg = "#c0caf5",})
  hl("Function", {fg = "#7aa2f7",bold = false,})
  hl("Statement",  { fg = c.green })
  hl("Keyword", {fg = "#bb9af7",italic = false,})
  hl("Operator",   { fg = c.green })
  hl("PreProc",    { fg = c.red })
  hl("Type",       { fg = c.yellow })
  hl("Special",    { fg = c.orange })
  hl("Delimiter",  { fg = c.orange })
  hl("Todo",       { fg = c.magenta, bold = true })
  hl("Error",      { fg = c.red, bold = true })
  hl("ErrorMsg",   { fg = c.red, reverse = true })
  hl("WarningMsg", { fg = c.orange, bold = true })

  -- ===== Search / Visual =====
  hl("Search",    { fg = c.base04, bg = c.yellow, bold = true })
  hl("IncSearch", { fg = c.base04, bg = c.orange, bold = true })
  hl("CurSearch", { link = "IncSearch" })
  hl("Visual",    { bg = c.base02 })
  hl("VisualNOS", { bg = c.base02 })

  -- ===== Popup menu (completion) =====
  hl("Pmenu",      { fg = c.base0,  bg = c.base02 })
  hl("PmenuSel",   { fg = c.base01, bg = c.base2 })
  hl("PmenuSbar",  { bg = c.base02 })
  hl("PmenuThumb", { bg = c.base0 })
  hl("WildMenu",   { fg = c.base2, bg = c.base02, reverse = true })

  -- ===== Diagnostics =====
  hl("DiagnosticError", { fg = c.error })
  hl("DiagnosticWarn",  { fg = c.warning })
  hl("DiagnosticInfo",  { fg = c.info })
  hl("DiagnosticHint",  { fg = c.hint })
  hl("DiagnosticVirtualTextError", { fg = c.red,    bg = c.red900 })
  hl("DiagnosticVirtualTextWarn",  { fg = c.yellow, bg = c.yellow900 })
  hl("DiagnosticVirtualTextInfo",  { fg = c.blue,   bg = c.blue900 })
  hl("DiagnosticVirtualTextHint",  { fg = c.cyan,   bg = c.cyan900 })
  hl("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
  hl("DiagnosticUnderlineWarn",  { undercurl = true, sp = c.warning })
  hl("DiagnosticUnderlineInfo",  { undercurl = true, sp = c.info })
  hl("DiagnosticUnderlineHint",  { undercurl = true, sp = c.hint })

  -- ===== Diff / Git =====
  hl("DiffAdd",    { fg = c.green,  bg = c.base02, bold = true })
  hl("DiffChange", { fg = c.yellow, bg = c.base02, bold = true })
  hl("DiffDelete", { fg = c.red,    bg = c.base02, bold = true })
  hl("DiffText",   { fg = c.blue,   bg = c.base02, bold = true })
  hl("GitSignsAdd",    { fg = c.green })
  hl("GitSignsChange", { fg = c.yellow })
  hl("GitSignsDelete", { fg = c.red })

  -- ===== indent-blankline (vạch scope vàng như ảnh) =====
  hl("IblIndent",                 { fg = c.base03, nocombine = true }) -- vạch thường chìm
  hl("IblScope",                  { fg = c.yellow, nocombine = true }) -- vạch scope = vàng
  hl("IndentBlanklineChar",       { fg = c.base03, nocombine = true })
  hl("IndentBlanklineContextChar",{ fg = c.yellow, nocombine = true })

  -- ===== Treesitter (vô hại nếu bạn chưa bật; đúng màu nếu bật sau) =====
  hl("@comment",            { link = "Comment" })
  hl("@string",             { link = "String" })
  hl("@function",           { link = "Function" })
  hl("@function.builtin",   { fg = c.orange })   -- require / print ... ra cam như ảnh
  hl("@variable.builtin",   { fg = c.orange })   -- vim / self / this ra cam
  hl("@keyword",            { link = "Keyword" })
  hl("@operator",           { link = "Operator" })
  hl("@type",               { link = "Type" })
  hl("@variable",           { link = "Identifier" })
  hl("@parameter",          { fg = c.orange })
  hl("@punctuation.bracket",{ fg = c.orange })
  hl("@punctuation.delimiter",{ fg = c.green })
  hl("@tag",                { fg = c.green })
  hl("@tag.delimiter",      { fg = c.orange })

  -- ===== nvim-cmp (cột kind nhiều màu bên phải popup) =====
  hl("CmpItemAbbr",        { fg = c.fg })
  hl("CmpItemAbbrMatch",   { fg = c.violet, bold = true })
  hl("CmpItemMenu",        { fg = c.base01 })
  hl("CmpItemKindKeyword", { fg = c.cyan })
  hl("CmpItemKindVariable",{ fg = c.magenta })
  hl("CmpItemKindConstant",{ fg = c.magenta })
  hl("CmpItemKindFunction",{ fg = c.blue })
  hl("CmpItemKindMethod",  { fg = c.blue })
  hl("CmpItemKindClass",   { fg = c.orange })
  hl("CmpItemKindInterface",{ fg = c.orange })
  hl("CmpItemKindModule",  { fg = c.yellow })
  hl("CmpItemKindProperty",{ fg = c.cyan })
  hl("CmpItemKindField",   { fg = c.cyan })
  hl("CmpItemKindSnippet", { fg = c.violet })

  -- ===== Hop (nhảy từ) =====
  hl("HopNextKey",  { fg = c.magenta, bold = true })
  hl("HopNextKey1", { fg = c.violet, bold = true })
  hl("HopNextKey2", { fg = c.violet700 })
  hl("HopUnmatched",{ fg = c.base01 })

  -- ===== Telescope / NvimTree / Alpha (cơ bản) =====
  hl("TelescopeBorder", { fg = c.base02, bg = c.base03 })
  hl("TelescopeNormal", { fg = c.base0,  bg = c.base03 })
  hl("NvimTreeNormal",  { fg = c.base00, bg = BG })
  hl("NvimTreeRootFolder", { fg = c.blue, bold = true })
  hl("AlphaHeader",   { fg = c.blue })
  hl("AlphaButtons",  { fg = c.cyan })
  hl("AlphaFooter",   { fg = c.cyan })

  -- ===== Terminal 16 màu =====
  vim.g.terminal_color_0  = c.black
  vim.g.terminal_color_1  = c.red
  vim.g.terminal_color_2  = c.green
  vim.g.terminal_color_3  = c.yellow
  vim.g.terminal_color_4  = c.blue
  vim.g.terminal_color_5  = c.magenta
  vim.g.terminal_color_6  = c.cyan
  vim.g.terminal_color_7  = c.base2
  vim.g.terminal_color_8  = c.base01
  vim.g.terminal_color_9  = c.red300
  vim.g.terminal_color_10 = c.green300
  vim.g.terminal_color_11 = c.yellow300
  vim.g.terminal_color_12 = c.blue300
  vim.g.terminal_color_13 = c.magenta
  vim.g.terminal_color_14 = c.cyan300
  vim.g.terminal_color_15 = c.base3
end

-- ===== Lualine theme (bắt chước solarized-osaka: INSERT = lime, NORMAL = xanh dương ...) =====
function M.lualine_theme()
  local c = M.colors
  local function mode(accent, accent300)
    return {
      a = { bg = accent,    fg = c.base04, gui = "bold" },
      b = { bg = c.base02,  fg = accent300 },
      c = { bg = c.base03,  fg = c.base1 },
    }
  end
  return {
    normal   = mode(c.blue,    c.blue300),
    insert   = mode(c.green,   c.green300),   -- lime như trong ảnh
    visual   = mode(c.magenta, c.magenta),
    replace  = mode(c.red,     c.red300),
    command  = mode(c.yellow,  c.yellow300),
    terminal = mode(c.cyan,    c.cyan300),
    inactive = { c = { bg = c.base03, fg = c.base01 } },
  }
end

return M