-- ~/.config/nvim/init.lua
-- "Space Neovim" — merged config
-- Base: lazy.nvim-managed LSP/completion/treesitter-free dashboard
-- Plus: your custom modules (theme, autopairs, hop, testcase, keymap_finder,
--       buffer_mask) from ~/.config/nvim/lua/
--
-- v2 CHANGELOG (this rewrite):
--   * file_finder.lua REMOVED — Telescope now covers that job (<leader>ff / <leader>fp).
--     -> delete lua/file_finder.lua from your config, it's no longer required anywhere.
--   * toggleterm.nvim REMOVED — your own terminal toggle functions are kept and
--     upgraded with a new "terminal scoped to current file's folder" mode, so
--     <C-t>, <leader>tt and <leader>tf still work exactly like before, just
--     powered by your own code instead of the plugin.
--   * De-duplicated a bunch of copy-pasted keymaps (<C-t>, <C-s>, insert-mode
--     bracket keys, <leader>q had two competing implementations — kept one).
--   * Removed dead/vestigial globals (vim.g.ts_compiler — no treesitter is used
--     in this config at all, mini_syntax.lua replaces it).
--   * NEW: <leader>x — universal "close whatever is on screen" key. Closes
--     floating windows (Telescope, testcase panel, keymap finder, LSP hover...),
--     then nvim-tree, then the current split, then the current tab — one layer
--     per press — but will NEVER close Neovim's very last window/tab. Use
--     <leader>q for that (it asks to save first).
--
-- SETUP:
--   1. Back up any existing config:  mv ~/.config/nvim ~/.config/nvim.bak
--   2. Copy BOTH init.lua and the lua/ folder to ~/.config/nvim/
--      (final layout: ~/.config/nvim/init.lua and ~/.config/nvim/lua/*.lua)
--   3. Delete lua/file_finder.lua — it's unused now.
--   4. Open nvim. Plugins + language servers + formatters install automatically.
--   5. Run :checkhealth afterwards to confirm everything's fine.

-------------------------------------------------------------------
-- 1. LEADER KEY (must be set before plugins/modules load)
-------------------------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-------------------------------------------------------------------
-- 2. YOUR CUSTOM MODULES (lua/*.lua)
-------------------------------------------------------------------
require('autopairs').setup()   -- bracket/quote pairing + smart <CR>/<BS>/<Space>
require('mini_syntax').setup() -- homemade pattern-based syntax highlighting
                                -- (lua, python, js/ts, c/cpp, java) — no
                                -- treesitter, no C compiler, no parser downloads
local keymap_finder = require('keymap_finder')
local testcase = require('testcase')
local hop = require('hop')
local buffer_mask = require('buffer_mask')
-- file_finder.lua is gone — Telescope replaces it (see plugins section, <leader>ff/fp)

-------------------------------------------------------------------
-- 3. BASIC OPTIONS
-------------------------------------------------------------------
local opt = vim.opt

opt.expandtab = true
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.autoindent = true

opt.encoding = "UTF-8"
opt.fileencoding = "utf-8"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.number = true          -- hybrid line numbers (see note below)
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.timeoutlen = 500
opt.cmdheight = 1
opt.autoread = true
opt.wrap = false
opt.mouse = "a"
opt.splitbelow = true
opt.splitright = true
opt.completeopt = { "menuone", "noselect" }
opt.termguicolors = true
opt.list = false
opt.listchars = { space = "·", tab = "··" }
opt.wildmenu = true
opt.shortmess:append("c")
opt.pumheight = 10
opt.showtabline = 2         -- always show the custom tabline
opt.showmode = false
opt.clipboard = "unnamedplus"
opt.laststatus = 3           -- one global statusline (used by lualine)
opt.undofile = true
opt.autowrite = true

require("theme").setup()

-- NOTE: your original file had `number = false` (relative-only). This merge
-- uses hybrid numbers (both absolute + relative) since that's this config's
-- default — flip `opt.number = false` above if you want your original look back.

-------------------------------------------------------------------
-- 4. AUTOCOMMANDS
-------------------------------------------------------------------
-- Restore cursor to last position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Flash highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-------------------------------------------------------------------
-- 5. CUSTOM TABLINE (buffer_mask.lua hooks into this)
-------------------------------------------------------------------
-- PERF NOTE: this function is Neovim's default tabline renderer, so it runs
-- on every tabline redraw — far more often than "when a buffer changes".
-- It used to re-run vim.fn.fnamemodify() and vim.fn.getbufvar() (both VimL
-- round-trips) for every open buffer on every one of those redraws. Cached
-- the display name per buffer (same approach as buffer_mask.lua) and moved
-- the listed/modified checks to the direct vim.bo[] API.
local tabline_name_cache = {}
local function tabline_display_name(buf)
  local raw = vim.api.nvim_buf_get_name(buf)
  local cached = tabline_name_cache[buf]
  if cached and cached.raw == raw then
    return cached.display
  end
  local display = vim.fn.fnamemodify(raw, ':t')
  if display == '' then display = '[No Name]' end
  tabline_name_cache[buf] = { raw = raw, display = display }
  return display
end
vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
  callback = function(args) tabline_name_cache[args.buf] = nil end,
})

function _G.custom_bufferline()
  local buffers = {}
  local current = vim.api.nvim_get_current_buf()

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then
      table.insert(buffers, buf)
    end
  end

  local line = ""
  for _, buf in ipairs(buffers) do
    local name = tabline_display_name(buf)
    local modified = vim.bo[buf].modified and ' [+]' or ''

    if buf == current then
      line = line .. '%#TabLineSel# ' .. name .. modified .. ' %#TabLine#'
    else
      line = line .. ' ' .. buf .. ':' .. name .. modified .. ' '
    end

    line = line .. '│'
  end

  return line .. '%#TabLineFill#'
end

vim.opt.tabline = '%!v:lua.custom_bufferline()'

-------------------------------------------------------------------
-- 6. KEYMAP HELPER + MISC FUNCTIONS
-------------------------------------------------------------------
local map = function(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then options = vim.tbl_extend("force", options, opts) end
  vim.keymap.set(mode, lhs, rhs, options)
end

-- Confirm on unsaved quit (single implementation — your file used to have
-- two competing versions of this, quit_with_check() was dead code because
-- <leader>q got remapped over it further down; merged into one here)
local function quit_with_confirmation()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      local choice = vim.fn.confirm(
        "Unsaved changes. Save before quit?",
        "&Save\n&Quit\n&Cancel"
      )
      if choice == 1 then
        vim.cmd("wa | qa")
      elseif choice == 2 then
        vim.cmd("qa!")
      end
      return
    end
  end
  vim.cmd("qa")
end

-------------------------------------------------------------------
-- 6b. TERMINAL MANAGEMENT (your own system — replaces toggleterm.nvim)
--     Three independent persistent terminals:
--       H = horizontal toggle      (<F7>, <C-t>, <leader>tt)
--       V = vertical toggle        (<C-7>)
--       F = scoped to current file's folder (<leader>tf) — NEW, replaces
--           what toggleterm used to do with `ToggleTerm dir=...`
-------------------------------------------------------------------
vim.g.TermBuf_H = nil
vim.g.TermWin_H = nil
vim.g.TermBuf_V = nil
vim.g.TermWin_V = nil
vim.g.TermBuf_F = nil
vim.g.TermWin_F = nil

function ToggleTerminalHorizontal()
  if vim.g.TermWin_H and vim.api.nvim_win_is_valid(vim.g.TermWin_H) then
    vim.api.nvim_win_hide(vim.g.TermWin_H)
    vim.g.TermWin_H = nil
    return
  end
  if vim.g.TermBuf_H and vim.api.nvim_buf_is_valid(vim.g.TermBuf_H) then
    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, vim.g.TermBuf_H)
    vim.cmd("resize 15")
    vim.cmd("startinsert")
    vim.g.TermWin_H = vim.api.nvim_get_current_win()
    return
  end
  vim.cmd("botright split | term")
  vim.cmd("resize 15")
  vim.cmd("startinsert")
  vim.g.TermBuf_H = vim.api.nvim_get_current_buf()
  vim.g.TermWin_H = vim.api.nvim_get_current_win()
end

function ToggleTerminalVertical()
  if vim.g.TermWin_V and vim.api.nvim_win_is_valid(vim.g.TermWin_V) then
    vim.api.nvim_win_hide(vim.g.TermWin_V)
    vim.g.TermWin_V = nil
    return
  end
  if vim.g.TermBuf_V and vim.api.nvim_buf_is_valid(vim.g.TermBuf_V) then
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, vim.g.TermBuf_V)
    vim.cmd("vertical resize 60")
    vim.cmd("startinsert")
    vim.g.TermWin_V = vim.api.nvim_get_current_win()
    return
  end
  vim.cmd("vsplit | term")
  vim.cmd("vertical resize 60")
  vim.cmd("startinsert")
  vim.g.TermBuf_V = vim.api.nvim_get_current_buf()
  vim.g.TermWin_V = vim.api.nvim_get_current_win()
end

-- NEW: terminal that starts (or, once created, jumps back into) a shell
-- rooted in the directory of the file you currently have open — this is
-- the replacement for toggleterm's `<leader>tf` / `dir=...` behaviour.
function ToggleTerminalAtFileDir()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end

  if vim.g.TermWin_F and vim.api.nvim_win_is_valid(vim.g.TermWin_F) then
    vim.api.nvim_win_hide(vim.g.TermWin_F)
    vim.g.TermWin_F = nil
    return
  end
  if vim.g.TermBuf_F and vim.api.nvim_buf_is_valid(vim.g.TermBuf_F) then
    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, vim.g.TermBuf_F)
    vim.cmd("resize 15")
    vim.cmd("startinsert")
    vim.g.TermWin_F = vim.api.nvim_get_current_win()
    return
  end
  vim.cmd("botright split")
  vim.fn.termopen(vim.o.shell, { cwd = dir })
  vim.cmd("resize 15")
  vim.cmd("startinsert")
  vim.g.TermBuf_F = vim.api.nvim_get_current_buf()
  vim.g.TermWin_F = vim.api.nvim_get_current_win()
end

-------------------------------------------------------------------
-- 6c. UNIVERSAL "CLOSE WHATEVER IS ON SCREEN" (<leader>x)
--     Peels off one layer per press: floating windows first (Telescope,
--     testcase panel, keymap finder, LSP hover/signature help, etc.),
--     then nvim-tree, then the current split, then the current tab.
--     It will NEVER close Neovim's last remaining window — that's what
--     <leader>q is for, and that one asks you to save first.
-------------------------------------------------------------------
local function smart_close_all()
  -- 1. Close every floating window currently open.
  local closed_float = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
    if ok and cfg.relative ~= "" then
      pcall(vim.api.nvim_win_close, win, true)
      closed_float = true
    end
  end
  if closed_float then return end

  -- 2. nvim-tree open? Close it.
  local ok_api, tree_api = pcall(require, "nvim-tree.api")
  if ok_api then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "NvimTree" then
        tree_api.tree.close()
        return
      end
    end
  end

  -- 3. More than one window in this tab? Close just the current split.
  if #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.cmd("close")
    return
  end

  -- 4. More than one tab? Close the current tab.
  if vim.fn.tabpagenr("$") > 1 then
    vim.cmd("tabclose")
    return
  end

  -- 5. Nothing left that wouldn't quit Neovim — refuse, point at <leader>q.
  print("Nothing left to close without quitting — use <leader>q to quit Neovim")
end

-------------------------------------------------------------------
-- 7. KEYMAPS
-------------------------------------------------------------------

-- Quit / universal close
map("n", "<leader>q", quit_with_confirmation, { desc = "Quit Neovim (confirm unsaved)" })
map("n", "<leader>x", smart_close_all, { desc = "Close whatever is on screen (never quits Neovim)" })

-- Terminal toggles
map("n", "<C-t>", ToggleTerminalHorizontal, { desc = "Toggle terminal" })
map("t", "<C-t>", function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
  ToggleTerminalHorizontal()
end, { desc = "Toggle terminal (from terminal mode)" })
vim.keymap.set({ "n", "i", "t" }, "<F7>", ToggleTerminalHorizontal, { noremap = true, silent = true, desc = "Toggle horizontal terminal" })
vim.keymap.set({ "n", "i", "t" }, "<C-7>", ToggleTerminalVertical, { noremap = true, silent = true, desc = "Toggle vertical terminal" })
map("n", "<leader>tt", ToggleTerminalHorizontal, { desc = "Terminal" })
map("n", "<leader>tf", ToggleTerminalAtFileDir, { desc = "Terminal (current folder)" })

-- Terminal navigation / escape
map("t", "<C-h>", [[<C-\><C-n><C-w>h]])
map("t", "<C-j>", [[<C-\><C-n><C-w>j]])
map("t", "<C-l>", [[<C-\><C-n><C-w>l]])
map("t", "<Esc>", [[<C-\><C-n>]])
map("t", "jk", "<C-\\><C-n>")

-- Insert mode
map("i", "<C-BS>", "<C-w>")
map("i", "<C-h>", "<C-w>")
map("i", "<S-Tab>", "<C-d>")
map("i", "<Tab>", "<C-t>")
map("i", "jk", "<Esc>")
-- (bracket pairs + smart <CR>/<BS>/<Space> come from autopairs.lua — not
-- re-mapped here, so the brace-expand-on-Enter feature stays intact)

-- Save
map("n", "<C-s>", "<cmd>w<CR>")
map("i", "<C-s>", "<Esc><cmd>w<CR>a")
map("v", "<C-s>", "<Esc><cmd>w<CR>")
map("n", "<leader>w", ":w<CR>", { desc = "Save file" })

-- File explorer / recent files
map("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
map("n", "<leader>r", ":browse oldfiles<CR>", { desc = "Recent files (native)" })

-- Buffer/file open helpers
map("n", "<leader>oj", ":edit<Space>")
map("n", "<leader>ok", ":split<CR>:edit<Space>")
map("n", "<leader>oo", ":split<CR>:buffer<Space>")
map("n", "<leader>ol", ":vsplit<CR>:buffer<Space>")

-- Buffer navigation (custom tabline, since bufferline.nvim isn't used)
map("n", "<Tab>", ":bnext<CR>")
map("n", "<S-Tab>", ":bprevious<CR>")

-- Window navigation
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Window splits
map("n", "<C-[>", ":split<CR>")
map("n", "<C-]>", ":vsplit<CR>")

-- Misc
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "Clear search highlight" })
-- NOTE: your original config used <leader>h for clear-highlight. That key now
-- opens the dashboard (see plugins section below), so clear-highlight moved to <leader>nh.

-- Finder popup (your custom one)
map("n", "<leader>fk", ':lua require("keymap_finder").show()<CR>', { desc = "Keymap finder" })
-- NOTE: <leader>fp used to open your old custom file_finder.lua popup. That
-- module is removed now — <leader>fp is remapped to Telescope's find_files
-- below (see plugins section) so the muscle memory still works.

-- Homemade syntax highlighter (mini_syntax.lua) — manual refresh
map("n", "<leader>sr", function() require("mini_syntax").refresh() end, { desc = "Refresh mini_syntax highlighting" })

-- Testcase manager
map("n", "<C-g><C-g>", function() require("testcase").toggle() end, { desc = "Toggle testcase runner" })
map("n", "<C-g>s", function() require("testcase").start() end, { desc = "Run testcase" })
map("n", "<C-g>e", function() require("testcase").exit() end, { desc = "Exit testcase runner" })

-- Hop plugin — jump to words
map("n", "<C-o><C-o>", function() require("hop").hop_line() end, { desc = "Hop within line" })
map("v", "<C-o><C-o>", function() require("hop").hop_visual() end, { desc = "Hop within selection" })

-- Buffer mask (numbered quick switch/close)
map("n", "<leader>bd", function() require("buffer_mask").close_buffer() end, { desc = "Close buffer (masked)" })
map("n", "<leader>bb", function() require("buffer_mask").switch_buffer() end, { desc = "Switch buffer (masked)" })

-- Visual mode: keep selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-------------------------------------------------------------------
-- 8. BOOTSTRAP lazy.nvim (plugin manager)
-------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-------------------------------------------------------------------
-- 9. PLUGINS
-- (no colorscheme plugin — your theme.lua handles that; no bufferline.nvim —
--  custom_bufferline + buffer_mask.lua handle that; no nvim-autopairs and no
--  toggleterm.nvim — your own modules replace both; no file_finder plugin —
--  Telescope handles that now)
-------------------------------------------------------------------
require("lazy").setup({

  -------------------------------------------------------------------
  -- Start screen / dashboard
  -------------------------------------------------------------------
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "                                        ",
        "     ____  ____   __      ___ ____         ",
        "    / ___|| _ \\  / _\\   / __| ___|        ",
        "    \\___ \\|  _/ / _ \\ | |  |  _|        ",
        "     ___) | |  / ___ \\| |__| |___       ",
        "    |____/|_| /_/   \\_\\____|_____|      ",
        "                                        ",
        "           N E O V I M                 ",
        "                                        ",
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", "<cmd>Telescope find_files<CR>"),
        dashboard.button("r", "  Recent files", "<cmd>Telescope oldfiles<CR>"),
        dashboard.button("g", "  Live grep", "<cmd>Telescope live_grep<CR>"),
        dashboard.button("n", "  New file", "<cmd>enew<CR>"),
        dashboard.button("e", "  File explorer", "<cmd>NvimTreeToggle<CR>"),
        dashboard.button("q", "  Quit", "<cmd>qa<CR>"),
      }

      alpha.setup(dashboard.config)
      map("n", "<leader>h", "<cmd>Alpha<CR>", { desc = "Home / dashboard" })
    end,
  },

  -- Fuzzy finder: files, text search, buffers — replaces file_finder.lua
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      map("n", "<leader>ff", builtin.find_files, { desc = "Find files (project-wide)" })
      map("n", "<leader>fp", builtin.find_files, { desc = "Find files (popup — replaces old file_finder.lua)" })
      map("n", "<leader>fg", builtin.live_grep, { desc = "Search text (grep)" })
      map("n", "<leader>fb", builtin.buffers, { desc = "List open buffers" })
      map("n", "<leader>fo", builtin.oldfiles, { desc = "Recent files (fuzzy)" })
    end,
  },

  -- File explorer sidebar
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- PERF NOTE: this was require("nvim-tree").setup({}) — every default
      -- on. The two defaults that actually cost time when a tree has a lot
      -- of folders:
      --   1. git.enable defaults to true, which shells out to `git status`
      --      across the whole repo synchronously before nvim-tree can paint
      --      the modified/untracked markers. More directories = longer
      --      blocking call, felt as a freeze the moment the tree opens.
      --   2. filesystem_watchers sets up a libuv watcher per rendered
      --      directory with no scoping, so heavy folders like node_modules
      --      or .git get watched (and their git status computed) right
      --      alongside everything else.
      -- Fix: keep git status (still useful) but give it a timeout so a slow
      -- repo can't block indefinitely, and scope both the watchers and the
      -- tree itself away from directories that are big but rarely useful
      -- to browse.
      require("nvim-tree").setup({
        git = {
          enable = true,
          timeout = 400,   -- ms — bail out of a slow `git status` instead of hanging the tree open
        },
        filesystem_watchers = {
          enable = true,
          ignore_dirs = { "node_modules", "%.git$", "dist", "build", "vendor", "target" },
        },
        filters = {
          custom = { "node_modules", "^\\.git$", "dist", "build", "vendor", "target" },
        },
        renderer = {
          group_empty = true,   -- collapse chains of empty folders into one line instead of rendering each
        },
      })

      map("n", "<leader>rr", function()
          local files = {}

          for _, f in ipairs(vim.v.oldfiles) do
              if vim.fn.filereadable(f) == 1 then
                  table.insert(files, f)
              end
          end

          if #files == 0 then
              print("No recent file history yet")
              return
          end

          vim.ui.select(files, {
              prompt = "Set root from recent file:",
              format_item = function(f)
                  return vim.fn.fnamemodify(f, ":~:.")
              end,
          }, function(choice)
              if not choice then
                  return
              end

              local dir = vim.fn.fnamemodify(choice, ":p:h")

              vim.cmd("cd " .. vim.fn.fnameescape(dir))

              local api = require("nvim-tree.api")
              api.tree.change_root(dir)
              api.tree.open()

              print("Root set to: " .. dir)
          end)
      end, { desc = "Explorer root from recent file" })
  end,
  },

  -- Indent guide lines
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup({
          indent = {
              char = "│",
          },

          scope = {
              enabled = false,
          },
      })
    end,
  },
  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      require("lualine").setup({
        options = {
          theme = require("theme").lualine_theme(),   -- thay cho theme = "auto"
        },
      })
    end,
  },

  -- Git signs in the gutter
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({

        -- NOTE: was `true` (always on). This spawns a `git blame` process
        -- every time you stop moving the cursor, which stutters noticeably
        -- in bigger repos or slow filesystems (WSL, network drives...).
        -- Off by default now — toggle it on demand with <leader>gb instead.
        current_line_blame = false,
        current_line_blame_opts = {
          delay = 500,
        },

        signs = {

            add = {
                text = "│",
            },

            change = {
                text = "│",
            },

            delete = {
                text = "_",
            },

            topdelete = {
                text = "‾",
            },

            changedelete = {
                text = "~",
            },

        },

    })

      map("n", "<leader>gb", function()
        require("gitsigns").toggle_current_line_blame()
      end, { desc = "Toggle git blame on current line" })
    end,
  },

  -- Comment lines with gcc / gc in visual mode
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

  -------------------------------------------------------------------
  -- LSP + autocompletion — scoped to HTML / CSS / JS / Python
  -------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      require("mason").setup()

      require("mason-lspconfig").setup({
        ensure_installed = { "html", "cssls", "ts_ls", "pyright" },
      })

      require("mason-tool-installer").setup({
        ensure_installed = { "prettier", "black" },
      })

      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        -- <CR> is intentionally NOT mapped here — autopairs.lua's smart_enter
        -- already does pumvisible() -> <C-y> (confirms the cmp selection) plus
        -- brace-expansion, so mapping it again here would just overwrite that.
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<C-k>"] = cmp.mapping.select_prev_item(),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
        },
      })

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local servers = { "html", "cssls", "ts_ls", "pyright" }
      for _, server in ipairs(servers) do
        vim.lsp.config(server, { capabilities = capabilities })
      end
      vim.lsp.enable(servers)

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
        end,
      })
    end,
  },

  -- Auto-format on save (prettier for html/css/js, black for python)
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          html = { "prettier" },
          css = { "prettier" },
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          json = { "prettier" },
          python = { "black" },
        },
        format_on_save = {
          timeout_ms = 1000,
          lsp_fallback = true,
        },
      })

      vim.keymap.set({ "n", "v" }, "<leader>mf", function()
        require("conform").format({ lsp_fallback = true })
      end, { desc = "Format file/selection" })
    end,
  },
})