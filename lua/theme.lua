-- Ocean Theme Configuration (Refined)
local M = {}

-- Color palette (deep ocean vibes)
local colors = {
  bg        = "#0f172a", -- abyss navy
  fg        = "#e2e8f0", -- moonlight silver
  bg_dark   = "#0a0f1e",
  bg_light  = "#1e293b",
  
  black     = "#1e293b",
  red       = "#f87171", -- coral red
  green     = "#34d399", -- aqua green
  yellow    = "#fde047", -- brighter golden sand
  blue      = "#38bdf8", -- pure ocean blue
  magenta   = "#c084fc", -- glowing violet
  cyan      = "#22d3ee", -- electric cyan
  white     = "#f8fafc",

  gray      = "#94a3b8", -- softer bluish gray
  accent    = "#60a5fa", -- luminous sky blue
  border    = "#334155",

  visual    = "#2563eb", -- strong blue for selection
  subtle    = "#1e40af", -- deep indigo for subtle bg
}

function M.setup()
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end

  vim.o.background = "dark"
  vim.g.colors_name = "ocean_custom"

  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- Editor UI
  hl("Normal", { fg = colors.fg, bg = colors.bg })
  hl("NormalFloat", { fg = colors.fg, bg = colors.bg_dark })
  hl("CursorLine", { bg = colors.subtle })
  hl("LineNr", { fg = colors.gray })
  hl("CursorLineNr", { fg = colors.accent, bold = true })
  hl("SignColumn", { bg = colors.bg })
  hl("VertSplit", { fg = colors.border })
  hl("StatusLine", { fg = colors.white, bg = colors.bg_light, bold = true })
  hl("StatusLineNC", { fg = colors.gray, bg = colors.bg_dark })

  -- Tabline
  hl("TabLine", { fg = colors.gray, bg = colors.bg_dark })
  hl("TabLineSel", { fg = colors.bg, bg = colors.accent, bold = true })
  hl("TabLineFill", { bg = colors.bg_dark })

  -- Syntax highlighting
  hl("Comment", { fg = "#64748b", italic = true }) -- muted gray-blue
  hl("Constant", { fg = colors.yellow, bold = true })
  hl("String", { fg = colors.green })
  hl("Character", { fg = colors.green })
  hl("Number", { fg = colors.yellow })
  hl("Boolean", { fg = colors.yellow })
  hl("Function", { fg = colors.blue, bold = true })
  hl("Identifier", { fg = colors.cyan })
  hl("Statement", { fg = colors.magenta, bold = true })
  hl("Keyword", { fg = colors.accent, bold = true })
  hl("PreProc", { fg = colors.cyan })
  hl("Type", { fg = "#93c5fd", bold = true }) -- soft blue type hint
  hl("Special", { fg = colors.magenta })

  -- Search
  hl("Search", { fg = colors.bg, bg = colors.yellow, bold = true })
  hl("IncSearch", { fg = colors.bg, bg = colors.red, bold = true })

  -- Popup menu
  hl("Pmenu", { fg = colors.fg, bg = colors.bg_light })
  hl("PmenuSel", { fg = colors.bg, bg = colors.accent, bold = true })
  hl("PmenuSbar", { bg = colors.bg_light })
  hl("PmenuThumb", { bg = colors.accent })

  -- Visual mode
  hl("Visual", { bg = colors.visual })

  -- Errors/Warnings
  hl("Error", { fg = colors.red, bold = true })
  hl("ErrorMsg", { fg = colors.red, bold = true })
  hl("WarningMsg", { fg = colors.yellow, bold = true })
  hl("DiagnosticInfo", { fg = colors.cyan })
  hl("DiagnosticHint", { fg = colors.blue })
  hl("DiagnosticWarn", { fg = colors.yellow })
  hl("DiagnosticError", { fg = colors.red })

  -- Git signs
  hl("DiffAdd", { fg = colors.green, bg = colors.bg_dark })
  hl("DiffChange", { fg = colors.yellow, bg = colors.bg_dark })
  hl("DiffDelete", { fg = colors.red, bg = colors.bg_dark })
  hl("DiffText", { fg = colors.blue, bg = colors.bg_dark })

  -- Terminal colors
  vim.g.terminal_color_0  = colors.black
  vim.g.terminal_color_1  = colors.red
  vim.g.terminal_color_2  = colors.green
  vim.g.terminal_color_3  = colors.yellow
  vim.g.terminal_color_4  = colors.blue
  vim.g.terminal_color_5  = colors.magenta
  vim.g.terminal_color_6  = colors.cyan
  vim.g.terminal_color_7  = colors.white
  vim.g.terminal_color_8  = colors.gray
  vim.g.terminal_color_9  = colors.red
  vim.g.terminal_color_10 = colors.green
  vim.g.terminal_color_11 = colors.yellow
  vim.g.terminal_color_12 = colors.blue
  vim.g.terminal_color_13 = colors.magenta
  vim.g.terminal_color_14 = colors.cyan
  vim.g.terminal_color_15 = colors.white
end

return M
