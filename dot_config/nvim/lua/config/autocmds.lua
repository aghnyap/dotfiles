-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Only the DELTAS from LazyVim's defaults live here.
--
-- LazyVim already provides: highlight-on-yank, last-cursor-position restore,
-- `q`-to-close for transient filetypes, wrap+spell in prose buffers, checktime
-- on FocusGained, mkdir-parents on write, and resize-splits. Those were all in
-- the previous from-scratch config and are dropped here rather than duplicated.

local augroup = function(name)
  return vim.api.nvim_create_augroup('cursorlike_' .. name, { clear = true })
end

-- Open the explorer on startup when nvim is launched with no file, so the
-- session looks like Cursor opening a folder.
--
-- This must NOT be a plain VimEnter autocmd -- as one, it could never fire,
-- in either direction. lazyvim/config/init.lua sets
--   local lazy_autocmds = vim.fn.argc(-1) == 0
-- and defers loading THIS FILE to VeryLazy when that is true. So:
--   * launched bare (argc 0) -- the file loads at VeryLazy, long after
--     VimEnter has already fired, so the autocmd registers too late to run;
--   * launched with a file  -- the file loads early and VimEnter does fire,
--     but then `argc() == 0` is false and the callback returns immediately.
-- Dead both ways, which is why `nvim` in a project came up as a blank buffer.
--
-- `v:vim_did_enter` is the supported way to ask which side of startup we are
-- on, so the same code path works whenever the file happens to be loaded.
local function open_explorer()
  if vim.fn.argc() > 0 then
    return
  end
  vim.cmd 'Neotree show'
  -- keep the cursor in the editor pane, not the tree
  vim.schedule(function()
    pcall(vim.cmd, 'wincmd l')
  end)
end

if vim.v.vim_did_enter == 1 then
  vim.schedule(open_explorer)
else
  vim.api.nvim_create_autocmd('VimEnter', {
    group = augroup 'explorer_on_start',
    callback = open_explorer,
  })
end

-- Per-language indentation, matching common VS Code language defaults.
-- LazyVim leaves indentation to editorconfig / the filetype plugins, which do
-- not cover all of these consistently.
--
-- ~/.editorconfig now carries the same rules, so that Android Studio, Xcode and
-- Cursor agree with Neovim on the same repository. This table is still the one
-- that applies to buffers with no matching extension, and to projects that ship
-- their own .editorconfig without covering a language. KEEP THE TWO IN SYNC --
-- Go and Make are the ones that bite, because both require literal tabs.
local indents = {
  go = { sw = 4, expandtab = false },
  make = { sw = 4, expandtab = false },
  python = { sw = 4 },
  java = { sw = 4 },
  kotlin = { sw = 4 },
  swift = { sw = 4 },
  php = { sw = 4 },
  rust = { sw = 4 },
  c = { sw = 4 },
  cpp = { sw = 4 },
  sh = { sw = 2 },
  markdown = { sw = 2 },
}
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'indent',
  callback = function(ev)
    local cfg = indents[vim.bo[ev.buf].filetype]
    if not cfg then
      return
    end
    vim.bo[ev.buf].shiftwidth = cfg.sw
    vim.bo[ev.buf].tabstop = cfg.sw
    vim.bo[ev.buf].softtabstop = cfg.sw
    if cfg.expandtab == false then
      vim.bo[ev.buf].expandtab = false
    end
  end,
})

-- ── Force vim.ui through snacks ────────────────────────────────────────────
-- `:checkhealth snacks` reports
--   `vim.ui.select` is not set to `Snacks.picker.select`
--   `vim.ui.input` is not set to `Snacks.input`
-- even with picker.ui_select and input.enabled both true, because snacks
-- installs those overrides at a point that depends on plugin load order --
-- and something later in the chain (noice loads at VeryLazy) puts the builtin
-- back. This was already broken in the pre-LazyVim config and did NOT get
-- fixed by the migration, so it is pinned down explicitly here.
--
-- It matters concretely: tasks.lua drives the Flutter flavour picker, the
-- Android app-id prompt, the melos script picker and the gradle prompt
-- entirely through vim.ui.select / vim.ui.input.
-- Note: this file is itself loaded BY LazyVim on VeryLazy, so registering a
-- VeryLazy autocmd here would never fire -- the event has already passed.
-- A plain vim.schedule() is the correct hook: it runs on the next event-loop
-- tick, after every other VeryLazy handler (noice included) has had its say.
--
-- Note the asymmetry in what gets assigned. `Snacks.picker.select` is the
-- function itself, but `Snacks.input` is a callable proxy table from the
-- Snacks metatable -- NOT the function that snacks/input.lua:314 compares
-- against. Assigning the proxy leaves :checkhealth reporting the error, so
-- the input side has to reach into the module for `.input`.
vim.schedule(function()
  local ok_p, Picker = pcall(require, 'snacks.picker')
  if ok_p then
    vim.ui.select = Picker.select
  end
  local ok_i, Input = pcall(require, 'snacks.input')
  if ok_i then
    vim.ui.input = Input.input
  end
end)

-- Terminal buffers: no gutter.
vim.api.nvim_create_autocmd('TermOpen', {
  group = augroup 'terminal',
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
    vim.opt_local.cursorline = false
  end,
})
