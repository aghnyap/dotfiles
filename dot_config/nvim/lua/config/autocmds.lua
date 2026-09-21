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

local sidebar = require 'util.sidebar'

-- neo-tree's own `close_if_last_window` (plugins/ui.lua) just closes the
-- tree when it is the last window; it doesn't give Cursor-style behavior for
-- the editor windows next to it, nor account for the AI column (agent
-- terminal windows) as non-editor panes. Replace it with a general check.
--
-- Closing the last editor window (`<C-w>q`, `:q`, `:wq`) closes that one
-- file, as in Cursor: its buffer is dropped (unless it has unsaved changes)
-- and the most recently used remaining file reopens in a fresh editor pane.
-- Quitting outright here took every other open file with it, or -- when one
-- of them was modified -- `qa` failed and left the sidebar with no editor
-- pane to open anything into.
--
-- Closing the last file leaves an empty editor pane, not an exit -- Cursor
-- keeps its window up with no editors open. Closing that empty pane (nothing
-- left to close but the workbench) is what quits, once only the sidebar and
-- AI column remain.
--
-- The buffer-drop happens any time its window closes and no other window
-- still shows it, whether or not sidebar-only quit follows.
local function file_buffers()
  local bufs = {}
  for _, info in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
    if vim.bo[info.bufnr].buftype == '' and info.name ~= '' then
      bufs[#bufs + 1] = info
    end
  end
  table.sort(bufs, function(x, y)
    return x.lastused > y.lastused
  end)
  return bufs
end

-- `buf` nil opens an empty, unnamed buffer instead. `width` is the explorer's
-- width from before the editor closed: by the time this runs, Neovim has
-- handed the closed pane's columns to the explorer, so reading it here would
-- restore the expanded width and leave the new pane a sliver at the edge.
local function reopen_editor(buf, width)
  local explorer = sidebar.explorer_win()
  vim.cmd(buf and ('botright vertical sbuffer ' .. buf) or 'botright vnew')
  if explorer and width then
    vim.api.nvim_win_set_width(explorer, width)
  end
  sidebar.layout()
end

vim.api.nvim_create_autocmd('WinClosed', {
  group = augroup 'quit_on_sidebar_only',
  callback = function(a)
    -- WinClosed's buffer can be the current buffer (e.g. the Open list),
    -- not the buffer in the window being closed by a terminal's handler.
    local closing_win = tonumber(a.match)
    local closed = vim.api.nvim_win_get_buf(closing_win)
    -- Terminal windows sit outside this file-vs-sidebar logic entirely: a
    -- closed terminal must never be replaced by a file buffer, and closing
    -- the last one should just close its area, not fall through to `qa`.
    -- Plain vim window-close semantics (focus another terminal if one is
    -- left in that split, otherwise the split disappears) already do that.
    if vim.bo[closed].buftype == 'terminal' then
      return
    end
    local tab = vim.api.nvim_win_get_tabpage(closing_win)
    local was_file = vim.bo[closed].buftype == '' and vim.api.nvim_buf_get_name(closed) ~= ''
    -- The closing window still holds its columns here; after it closes they
    -- belong to the explorer.
    local explorer = sidebar.explorer_win(tab)
    local width = explorer and vim.api.nvim_win_get_width(explorer)
    sidebar.schedule(function()
      if
        was_file
        and vim.api.nvim_buf_is_valid(closed)
        and vim.bo[closed].buflisted
        and not vim.bo[closed].modified
        and vim.fn.bufwinid(closed) == -1
      then
        pcall(vim.cmd, 'bdelete ' .. closed)
      end
      if #vim.api.nvim_list_tabpages() > 1 then
        return
      end
      local real, saw_sidebar = 0, false
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        -- Ignore floats (notifications, popups, completion menus, ...):
        -- none of them are "a real window to edit in" either.
        local ok, cfg = pcall(vim.api.nvim_win_get_config, w)
        if ok and cfg.relative == '' then
          real = real + 1
          if sidebar.is_sidebar_win(w) then
            saw_sidebar = true
          else
            return
          end
        end
      end
      if not (real > 0 and saw_sidebar) then
        return
      end
      local remaining = file_buffers()
      if #remaining > 0 then
        reopen_editor(remaining[1].bufnr, width)
      elseif was_file then
        reopen_editor(nil, width)
      elseif vim.api.nvim_buf_is_valid(closed) and vim.bo[closed].modified then
        -- Unsaved scratch text: `qa` would fail on it, so show it again.
        reopen_editor(closed, width)
      else
        vim.cmd 'qa'
      end
    end, tab)
  end,
})

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
end

if vim.v.vim_did_enter == 1 then
  sidebar.schedule(open_explorer)
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

-- Neo-tree's Open list labels a terminal entry with `b:term_title`, falling
-- back to the directory chunk of the buffer name
-- (neo-tree/sources/buffers/lib/items.lua), and Neovim seeds term_title with
-- the entire `term://<cwd>//<pid>:<cmd>` name -- so every entry reads as that
-- rather than as the command it is running. Shorten it to toggleterm's own
-- `<id>:<cmd>` convention (its config.lua name_formatter default), dropping
-- the id for terminals toggleterm does not own.
--
-- Renaming the buffer instead would be the wrong fix twice over: buffer names
-- must be unique, which several terminals running one agent would collide on,
-- and toggleterm's identify() parses the `;#toggleterm#<id>` suffix back out
-- of the name to find which terminal a buffer belongs to.
--
-- A program that emits an OSC 0/2 title still overrides this afterwards, as
-- it would in any terminal.
local function terminal_title(buf)
  local cmd = vim.api.nvim_buf_get_name(buf):match '//%d+:(.*)$'
  if not cmd then
    return nil
  end
  cmd = cmd:gsub(';#toggleterm#%d+$', '')
  local argv0 = vim.fn.fnamemodify(cmd:match '^%S+' or cmd, ':t')
  if argv0 == '' then
    return nil
  end
  local id = vim.b[buf].toggle_number
  return id and (id .. ':' .. argv0) or argv0
end

-- Terminal buffers: no gutter. Agent terminals opt in to single Escape so it
-- returns to Neovim Normal mode without sending an interrupt/cancel to the
-- agent. Other terminal buffers deliberately receive Escape unchanged.
vim.api.nvim_create_autocmd('TermOpen', {
  group = augroup 'terminal',
  callback = function(ev)
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
    vim.opt_local.cursorline = false

    local title = terminal_title(ev.buf)
    if title then
      vim.b[ev.buf].term_title = title
    end

    if vim.b[ev.buf].agent_terminal then
      vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', {
        buffer = ev.buf,
        silent = true,
        nowait = true,
        desc = 'Exit agent terminal mode',
      })
    end
  end,
})

-- Agent terminals own the full-height right column; see util/sidebar.lua.
-- TermOpen covers the first open, BufWinEnter every later reopen.
vim.api.nvim_create_autocmd({ 'TermOpen', 'BufWinEnter' }, {
  group = augroup 'agent_column',
  callback = function(ev)
    if vim.b[ev.buf].agent_terminal then
      sidebar.schedule(sidebar.layout)
    end
  end,
})

-- Neo-tree delays file events twice and filters out terminal events. Refresh
-- the Open source after buffer mutations settle, using its own coalescing and
-- per-tab updates. Do not load the explorer just because a buffer changed.
vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufFilePost', 'TermOpen', 'TermClose' }, {
  group = augroup 'open_list_refresh',
  callback = function()
    vim.schedule(function()
      local buffers = package.loaded['neo-tree.sources.buffers']
      if buffers then
        buffers.buffers_changed()
      end
    end)
  end,
})
