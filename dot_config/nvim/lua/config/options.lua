-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
--
-- Only the DELTAS from LazyVim's defaults live here.
--
-- LazyVim already sets the bulk of what the previous from-scratch config
-- declared: number, signcolumn, cursorline, termguicolors, laststatus=3,
-- expandtab/shiftwidth=2, wrap=false, splitright/splitbelow, ignorecase +
-- smartcase, undofile, clipboard=unnamedplus, list, and treesitter folding.
-- Keeping only the differences means upstream improvements are not shadowed.

local opt = vim.opt

-- Initialise the local Ollama model before plugin specs read it.
require 'util.ai_model'

-- Absolute line numbers only. LazyVim defaults to relativenumber; Cursor and
-- VS Code do not, and this config is deliberately shaped like them.
opt.relativenumber = false
opt.cursorlineopt = 'number,line'

-- A little more context around the cursor than LazyVim's scrolloff = 4.
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Live preview of :s in a split, rather than inline only.
opt.inccommand = 'split'

-- Slightly roomier completion popup.
opt.pumheight = 12

-- 400ms is a deliberate compromise: long enough that the leader (space) chords
-- in which-key stay reachable mid-typing, short enough not to feel stuck.
opt.timeoutlen = 400
opt.updatetime = 250
opt.ttimeoutlen = 10

opt.undolevels = 10000
opt.confirm = true -- prompt on unsaved changes instead of failing

opt.fillchars = {
  eob = ' ',
  fold = ' ',
  foldopen = '\u{25be}',
  foldclose = '\u{25b8}',
  foldsep = ' ',
  diff = '╱',
}
opt.listchars = { tab = '  ', trail = '·', nbsp = '␣' }

opt.mousemoveevent = true -- bufferline hover
opt.mousescroll = 'ver:2,hor:0'

opt.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help' }

-- Rounded borders on every float (nvim 0.11+).
opt.winborder = 'rounded'

-- No plugin here needs the remote-plugin hosts; skipping them removes four
-- `provider` warnings from :checkhealth and a little startup work.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

-- LazyVim reads these.
vim.g.lazyvim_picker = 'snacks'
-- ...and this one, which is why there were TWO file explorers.
--
-- LazyVim picks a default explorer the same way it picks a picker, from
-- `checks.explorer = { snacks, neo-tree }` in lazyvim/config/init.lua. snacks
-- is first, and the swap that used to put neo-tree first only applies to
-- installs older than version 8 -- lazyvim.json says 8. So LazyVim was
-- auto-enabling the `editor.snacks_explorer` extra and binding <leader>e to
-- Snacks.explorer, while plugins/ui.lua separately declared and configured
-- neo-tree on <D-b>. Two explorers, two sets of keys, one of them unstyled.
--
-- neo-tree is the one this config is actually built around: bufferline's
-- EXPLORER offset keys off `filetype = 'neo-tree'`, satellite excludes that
-- filetype, autocmds.lua opens it at startup, and keymaps.lua drives it. So
-- neo-tree wins and snacks_explorer is not loaded at all.
vim.g.lazyvim_explorer = 'neo-tree'
-- LazyVim's format-on-save gate, and the only one. auto-save.nvim flips it off
-- for the duration of its own writes (see the callbacks in plugins/editor.lua)
-- so formatting never fires mid-keystroke. `<leader>uf` toggles it by hand.
vim.g.autoformat = true
