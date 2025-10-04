-- Theme configuration
local M = {}

-- Color palette
local colors = {
  bg = "#1e1e2e",
  fg = "#cdd6f4",
  bg_dark = "#11111b",
  bg_light = "#313244",
  
  black = "#45475a",
  red = "#f38ba8",
  green = "#a6e3a1",
  yellow = "#f9e2af",
  blue = "#89b4fa",
  magenta = "#cba6f7",
  cyan = "#94e2d5",
  white = "#bac2de",
  
  gray = "#6c7086",
  accent = "#89b4fa",
  border = "#45475a",
}

function M.setup()
  -- Reset existing highlights
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  
  vim.o.background = "dark"
  vim.g.colors_name = "custom"
  
  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end
  
  -- Editor
  hl("Normal", { fg = colors.fg, bg = colors.bg })
  hl("NormalFloat", { fg = colors.fg, bg = colors.bg_dark })
  hl("CursorLine", { bg = colors.bg_light })
  hl("LineNr", { fg = colors.gray })
  hl("CursorLineNr", { fg = colors.accent, bold = true })
  hl("SignColumn", { bg = colors.bg })
  hl("VertSplit", { fg = colors.border })
  hl("StatusLine", { fg = colors.fg, bg = colors.bg_light })
  hl("StatusLineNC", { fg = colors.gray, bg = colors.bg_dark })
  
  -- Tabline (bufferline)
  hl("TabLine", { fg = colors.white, bg = colors.bg_dark })
  hl("TabLineSel", { fg = colors.bg, bg = colors.accent, bold = true })
  hl("TabLineFill", { bg = colors.bg_dark })
  
  -- Syntax
  hl("Comment", { fg = colors.gray, italic = true })
  hl("Constant", { fg = colors.yellow })
  hl("String", { fg = colors.green })
  hl("Character", { fg = colors.green })
  hl("Number", { fg = colors.yellow })
  hl("Boolean", { fg = colors.yellow })
  hl("Function", { fg = colors.blue })
  hl("Identifier", { fg = colors.magenta })
  hl("Statement", { fg = colors.magenta })
  hl("Keyword", { fg = colors.red })
  hl("PreProc", { fg = colors.cyan })
  hl("Type", { fg = colors.yellow })
  hl("Special", { fg = colors.cyan })
  
  -- Search
  hl("Search", { fg = colors.bg, bg = colors.yellow })
  hl("IncSearch", { fg = colors.bg, bg = colors.red })
  
  -- Popup menu
  hl("Pmenu", { fg = colors.fg, bg = colors.bg_light })
  hl("PmenuSel", { fg = colors.bg, bg = colors.accent, bold = true })
  hl("PmenuSbar", { bg = colors.bg_light })
  hl("PmenuThumb", { bg = colors.accent })
  
  -- Visual
  hl("Visual", { bg = colors.bg_light })
  
  -- Errors/Warnings
  hl("Error", { fg = colors.red })
  hl("ErrorMsg", { fg = colors.red, bold = true })
  hl("WarningMsg", { fg = colors.yellow })
  
  -- Terminal
  vim.g.terminal_color_0 = colors.black
  vim.g.terminal_color_1 = colors.red
  vim.g.terminal_color_2 = colors.green
  vim.g.terminal_color_3 = colors.yellow
  vim.g.terminal_color_4 = colors.blue
  vim.g.terminal_color_5 = colors.magenta
  vim.g.terminal_color_6 = colors.cyan
  vim.g.terminal_color_7 = colors.white
  vim.g.terminal_color_8 = colors.gray
  vim.g.terminal_color_9 = colors.red
  vim.g.terminal_color_10 = colors.green
  vim.g.terminal_color_11 = colors.yellow
  vim.g.terminal_color_12 = colors.blue
  vim.g.terminal_color_13 = colors.magenta
  vim.g.terminal_color_14 = colors.cyan
  vim.g.terminal_color_15 = colors.white
end

return M