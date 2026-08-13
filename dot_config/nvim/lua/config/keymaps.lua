-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
--
-- ╭──────────────────────────────────────────────────────────────╮
-- │  Cursor / VS Code keybindings                                │
-- │                                                              │
-- │  <D-...> is the Cmd (Super) key. Ghostty forwards these as   │
-- │  CSI-u sequences; see ~/.config/ghostty/config. If a Cmd      │
-- │  chord does nothing, check that both files agree on it.       │
-- │                                                              │
-- │  LazyVim's own <leader> groups (f find, g git, c code,        │
-- │  s search, u ui, x diagnostics, b buffer) are left alone.     │
-- │  Only groups LazyVim does not define are added: F flutter,    │
-- │  r run, h http, a ai (Claude), A agents (aider/cursor),       │
-- │  C c4, X xcode, D database, m overview.                       │
-- ╰──────────────────────────────────────────────────────────────╯

local map = vim.keymap.set

-- ╭──────────────────────────────────────────────────────────────╮
-- │  tmux-safe aliases for the Cmd chords                        │
-- │                                                              │
-- │  Ghostty no longer encodes these with the Super bit, because  │
-- │  Super does not survive tmux -- tmux has no Super modifier    │
-- │  and collapses it onto Meta, so a pane received a bare <M-p>  │
-- │  for Cmd+P and every <D-...> mapping below was dead in a      │
-- │  pane. Ctrl-bearing CSI-u does survive, so Ghostty now sends  │
-- │  Ctrl+Shift for Cmd and Ctrl+Alt+Shift for Cmd+Shift.         │
-- │  See ~/.config/ghostty/config for the full derivation.        │
-- │                                                              │
-- │  Rather than rewrite 30 mappings, this table points the key   │
-- │  that ACTUALLY arrives at the <D-...> name, with remap=true.  │
-- │  Everything below stays written once, as <D-...>, and keeps   │
-- │  working unchanged -- including the lazy-loaded `keys` specs   │
-- │  in plugins/ai.lua and the multicursor maps in editor.lua.    │
-- │                                                              │
-- │  The four odd ones out (Cmd+J, Cmd+`, Cmd+Shift+M,           │
-- │  Cmd+Shift+[) ride on spare letters because Ctrl+J/`/M/[      │
-- │  collapse to NL/NUL/CR/Esc before any modifier is reported.   │
-- │  The key you press is unchanged; only the wire encoding is.   │
-- │                                                              │
-- │  Key names here are exactly what nvim reports for the bytes   │
-- │  tmux delivers -- verified, not derived.                      │
-- ╰──────────────────────────────────────────────────────────────╯
local cmd_aliases = {
  -- Cmd+X  →  Ctrl+Shift+X
  ['<C-S-P>'] = '<D-p>',
  ['<C-S-F>'] = '<D-f>',
  ['<C-S-B>'] = '<D-b>',
  ['<C-S-S>'] = '<D-s>',
  -- No <C-S-W>: Cmd+W is Ghostty's close_surface and is never forwarded here.
  ['<C-S-Z>'] = '<D-z>',
  ['<C-S-A>'] = '<D-a>',
  ['<C-S-D>'] = '<D-d>',
  ['<C-S-L>'] = '<D-l>',
  ['<C-S-K>'] = '<D-k>',
  ['<C-S-,>'] = '<D-,>',
  ['<C-S-/>'] = '<D-/>',
  ['<C-S-.>'] = '<D-.>',
  ['<C-S-\\>'] = '<D-\\>',
  ['<C-S-N>'] = '<D-j>', -- Cmd+J   (Ctrl+J is NL)
  ['<C-S-Q>'] = '<D-`>', -- Cmd+`   (Ctrl+` is NUL)

  -- Cmd+Shift+X  →  Ctrl+Alt+Shift+X
  ['<M-C-S-P>'] = '<D-S-p>',
  ['<M-C-S-F>'] = '<D-S-f>',
  ['<M-C-S-O>'] = '<D-S-o>',
  ['<M-C-S-U>'] = '<D-S-u>',
  ['<M-C-S-E>'] = '<D-S-e>',
  ['<M-C-S-G>'] = '<D-S-g>',
  ['<M-C-S-Z>'] = '<D-S-z>',
  ['<M-C-S-K>'] = '<D-S-k>',
  ['<M-C-S-D>'] = '<D-S-d>',
  ['<M-C-S-L>'] = '<D-S-l>',
  ['<M-C-S-]>'] = '<D-S-]>',
  ['<M-C-S-R>'] = '<D-S-m>', -- Cmd+Shift+M  (Ctrl+M is CR)
  ['<M-C-S-T>'] = '<D-S-[>', -- Cmd+Shift+[  (Ctrl+[ is Esc)
}
for from, to in pairs(cmd_aliases) do
  map({ 'n', 'i', 'v', 't' }, from, to, { remap = true, desc = 'Cmd chord → ' .. to })
end

-- Cmd+Alt+Up/Down ride Ctrl+Alt+Arrow. Scoped to the modes multicursor
-- actually maps, so an unmapped alias cannot fire mid-insert.
map({ 'n', 'x' }, '<M-C-Up>', '<M-D-Up>', { remap = true, desc = 'Cmd chord → <M-D-Up>' })
map({ 'n', 'x' }, '<M-C-Down>', '<M-D-Down>', { remap = true, desc = 'Cmd chord → <M-D-Down>' })

-- ── Files & search (Cmd+P, Cmd+Shift+P, Cmd+Shift+F) ───────────
map({ 'n', 'i', 'v' }, '<D-p>', function()
  Snacks.picker.smart()
end, { desc = 'Quick open file' })

map({ 'n', 'i', 'v' }, '<D-S-p>', function()
  Snacks.picker.commands()
end, { desc = 'Command palette' })

map({ 'n', 'i', 'v' }, '<D-S-f>', function()
  Snacks.picker.grep()
end, { desc = 'Search across project' })

map({ 'n', 'i', 'v' }, '<D-S-o>', function()
  Snacks.picker.lsp_symbols()
end, { desc = 'Go to symbol in file' })

map({ 'n', 'i', 'v' }, '<D-S-m>', '<cmd>Trouble diagnostics toggle<cr>', { desc = 'Problems panel' })
map({ 'n', 'i', 'v' }, '<D-S-g>', function()
  Snacks.lazygit()
end, { desc = 'Source control (lazygit)' })

-- Find in current file
map('n', '<D-f>', '/', { desc = 'Find in file' })
map('i', '<D-f>', '<Esc>/', { desc = 'Find in file' })
map('v', '<D-f>', 'y/<C-r>"<CR>', { desc = 'Find selection' })

-- ── Sidebar & panels ───────────────────────────────────────────
map({ 'n', 'i', 'v' }, '<D-b>', '<cmd>Neotree toggle<cr>', { desc = 'Toggle sidebar' })
map({ 'n', 'i', 'v' }, '<D-S-e>', '<cmd>Neotree focus<cr>', { desc = 'Focus explorer' })
map({ 'n', 'i', 'v', 't' }, '<D-`>', '<cmd>ToggleTerm<cr>', { desc = 'Toggle terminal panel' })
map({ 'n', 'i', 'v', 't' }, '<D-j>', '<cmd>ToggleTerm<cr>', { desc = 'Toggle bottom panel' })

-- The outline gets a Cmd chord rather than a <leader> one because <leader> is
-- a space, and space is unreachable exactly where you tend to be sitting: in a
-- terminal buffer it goes to the shell, in neo-tree it is `toggle_node`.
-- aerial outlines whatever window is *focused*, so step into the code first.
map({ 'n', 'i', 'v', 't' }, '<D-S-u>', function()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == '' and vim.bo[buf].filetype ~= 'neo-tree' then
      vim.api.nvim_set_current_win(win)
      break
    end
  end
  vim.cmd 'AerialToggle!'
end, { desc = 'Toggle symbol outline' })

-- ── File operations ────────────────────────────────────────────
map({ 'n', 'i', 'v' }, '<D-s>', '<Cmd>silent! write<CR>', { desc = 'Save' })
-- No <D-w>: Cmd+W belongs to Ghostty (close_surface). Ghostty no longer forwards
-- it, so a mapping here would be dead code. Close a buffer with `<leader>bd`.
map({ 'n', 'i', 'v' }, '<D-,>', function()
  Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
end, { desc = 'Open settings (config files)' })

-- ── Editing ────────────────────────────────────────────────────
map({ 'n', 'i' }, '<D-z>', '<Cmd>undo<CR>', { desc = 'Undo' })
map({ 'n', 'i' }, '<D-S-z>', '<Cmd>redo<CR>', { desc = 'Redo' })
map('n', '<D-a>', 'ggVG', { desc = 'Select all' })
map({ 'i', 'v' }, '<D-a>', '<Esc>ggVG', { desc = 'Select all' })

-- Cmd+/ toggles comments (uses the built-in `gc` operator)
map('n', '<D-/>', 'gcc', { remap = true, desc = 'Toggle comment' })
map('v', '<D-/>', 'gc', { remap = true, desc = 'Toggle comment' })
map('i', '<D-/>', '<Esc>gcca', { remap = true, desc = 'Toggle comment' })

-- Cmd+Shift+K deletes the line, like VS Code
map('n', '<D-S-k>', 'dd', { desc = 'Delete line' })
map('i', '<D-S-k>', '<Esc>ddi', { desc = 'Delete line' })
map('v', '<D-S-k>', 'd', { desc = 'Delete selection' })

-- Cmd+. quick fix / code action
map({ 'n', 'v' }, '<D-.>', vim.lsp.buf.code_action, { desc = 'Quick fix' })
map('i', '<D-.>', '<Esc><Cmd>lua vim.lsp.buf.code_action()<CR>', { desc = 'Quick fix' })

-- Alt+Up/Down move lines; Alt+Shift+Up/Down duplicate them.
-- (Requires `macos-option-as-alt = true` in the Ghostty config.)
map('n', '<M-Up>', '<Cmd>execute "move .-2"<CR>==', { desc = 'Move line up' })
map('n', '<M-Down>', '<Cmd>execute "move .+1"<CR>==', { desc = 'Move line down' })
map('i', '<M-Up>', '<Esc><Cmd>execute "move .-2"<CR>==gi', { desc = 'Move line up' })
map('i', '<M-Down>', '<Esc><Cmd>execute "move .+1"<CR>==gi', { desc = 'Move line down' })
map('v', '<M-Up>', ":move '<-2<CR>gv=gv", { desc = 'Move selection up' })
map('v', '<M-Down>', ":move '>+1<CR>gv=gv", { desc = 'Move selection down' })
map('n', '<M-S-Up>', '<Cmd>copy .-1<CR>', { desc = 'Duplicate line up' })
map('n', '<M-S-Down>', '<Cmd>copy .<CR>', { desc = 'Duplicate line down' })
-- Both directions in visual mode. Only Down existed, while both docs listed
-- `Alt+Shift+Up` / `Alt+Shift+Down` as a pair -- so duplicate-upward was
-- documented and unmapped. `'<-1` puts the copy above the selection.
map('v', '<M-S-Up>', ":copy '<-1<CR>gv", { desc = 'Duplicate selection up' })
map('v', '<M-S-Down>', ":copy '><CR>gv", { desc = 'Duplicate selection down' })

-- Shift+Alt+F formats, as in VS Code
map({ 'n', 'v' }, '<M-S-f>', function()
  require('conform').format { async = true, lsp_format = 'fallback' }
end, { desc = 'Format document' })

-- Tab / Shift+Tab indent in visual mode, keeping the selection
map('v', '<Tab>', '>gv', { desc = 'Indent' })
map('v', '<S-Tab>', '<gv', { desc = 'Outdent' })

-- ── Buffer (tab) navigation ────────────────────────────────────
map({ 'n', 'i', 'v' }, '<D-S-]>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next editor' })
map({ 'n', 'i', 'v' }, '<D-S-[>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Previous editor' })
map('n', '<Tab>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next editor' })
map('n', '<S-Tab>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Previous editor' })

-- ── LSP navigation on the VS Code function keys ────────────────
-- gd / gr / gI / gy already come from LazyVim's LspAttach maps.
map('n', '<F12>', function()
  Snacks.picker.lsp_definitions()
end, { desc = 'Go to definition' })
map('n', '<S-F12>', function()
  Snacks.picker.lsp_references()
end, { desc = 'Find all references' })
map('n', '<F2>', vim.lsp.buf.rename, { desc = 'Rename symbol' })

-- ── Window splits ──────────────────────────────────────────────
-- C-hjkl is deliberately NOT mapped here: vim-tmux-navigator owns it so the
-- same chord crosses the Neovim/tmux boundary. See plugins/editor.lua.
map('n', '<D-\\>', '<cmd>vsplit<cr>', { desc = 'Split editor right' })

-- ── Quality-of-life ────────────────────────────────────────────
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- ── Overview / outline (<leader>m) ─────────────────────────────
-- satellite ships Enable/Disable/Refresh but no toggle, so track the state
-- here. It starts enabled, matching the plugin's own default.
local satellite_on = true
map('n', '<leader>mm', function()
  satellite_on = not satellite_on
  vim.cmd(satellite_on and 'SatelliteEnable' or 'SatelliteDisable')
end, { desc = 'Toggle overview scrollbar' })
map('n', '<leader>mr', '<cmd>SatelliteRefresh<cr>', { desc = 'Refresh overview scrollbar' })
map('n', '<leader>mo', '<cmd>AerialToggle!<cr>', { desc = 'Toggle symbol outline' })
map('n', '<leader>mf', '<cmd>AerialToggle<cr>', { desc = 'Focus symbol outline' })

-- ── Local AI (<leader>aM / <leader>aR) ─────────────────────────
map('n', '<leader>aM', function()
  require('util.ai_model').toggle()
end, { desc = 'Cycle local AI model' })
map('n', '<leader>aR', function()
  require('util.ai_memory').check()
end, { desc = 'AI memory check' })

-- Sticky scroll: jump up to the enclosing scope pinned at the top of the
-- window. `[c` is free here -- gitsigns uses `]h` / `[h` for hunks.
map('n', '[c', function()
  require('treesitter-context').go_to_context(vim.v.count1)
end, { desc = 'Jump to enclosing scope' })

-- ── Flagged comments ───────────────────────────────────────────
-- LazyVim already maps ]t / [t and <leader>st for todo-comments. This is the
-- extra one for the SECURITY/AUDIT taxonomy in plugins/security.lua.
map('n', '<leader>fs', '<cmd>TodoTrouble keywords=SECURITY,AUDIT<cr>', { desc = 'Security / audit flags' })

-- ── Flutter (<leader>F) ────────────────────────────────────────
--    flutter-tools drives the SDK through FVM; see plugins/lang-flutter.lua.
--    Hot reload is automatic on save, so these are the manual escapes.
map('n', '<leader>Fd', '<cmd>FlutterDevices<cr>', { desc = 'Pick device' })
map('n', '<leader>Fe', '<cmd>FlutterEmulators<cr>', { desc = 'Pick emulator' })
map('n', '<leader>Fr', '<cmd>FlutterReload<cr>', { desc = 'Hot reload' })
map('n', '<leader>FR', '<cmd>FlutterRestart<cr>', { desc = 'Hot restart' })
map('n', '<leader>Fq', '<cmd>FlutterQuit<cr>', { desc = 'Quit running app' })
map('n', '<leader>Fo', '<cmd>FlutterOutlineToggle<cr>', { desc = 'Widget outline' })
map('n', '<leader>Fl', '<cmd>FlutterLogToggle<cr>', { desc = 'Dev log' })
map('n', '<leader>FD', '<cmd>FlutterDevTools<cr>', { desc = 'Start DevTools' })
