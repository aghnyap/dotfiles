-- ╭──────────────────────────────────────────────────────────────╮
-- │  OPEN SHELLS: a vertical list of open terminal buffers,       │
-- │  docked under OPEN EDITORS (util/bufferlist.lua), itself      │
-- │  docked under the explorer. Every buftype=='terminal' buffer  │
-- │  lands here -- toggleterm task runners, the ad hoc <D-`>/     │
-- │  <D-S-`> toggles, the vnew|terminal fallback, and the         │
-- │  snacks-backed agent terminals (Claude, cursor-agent, Codex,  │
-- │  aider) -- they're all just "a shell that's open".            │
-- │                                                                │
-- │  Inside the panel:                                            │
-- │    <CR>/l  focus the shell (or reopen it if hidden)           │
-- │    d       kill the job and close it                          │
-- ╰──────────────────────────────────────────────────────────────╯
local M = {}

local sidebar = require 'util.sidebar'

local NS = vim.api.nvim_create_namespace 'shelllist'

-- Inventories are global; window ownership, selection and focus are per tab.
local states = {}

local function state(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  if not states[tab] then
    states[tab] = { tab = tab, shown = {} }
  end
  return states[tab]
end

local function list_terminals()
  local bufs = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == 'terminal' then
      bufs[#bufs + 1] = b
    end
  end
  table.sort(bufs)
  return bufs
end

-- `term://~/dotfiles//12345:zsh` -> `zsh`; falls back to the raw name for
-- anything that doesn't match the usual toggleterm/builtin shape.
local function label(b)
  local name = vim.api.nvim_buf_get_name(b)
  return name:match '^term://.-//%d+:(.*)$' or name:match ':(.*)$' or name
end

local function win_showing(bufnr, tab)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab or 0)) do
    if vim.api.nvim_win_get_buf(w) == bufnr then
      return w
    end
  end
end

local function render(s)
  if not (s.buf and vim.api.nvim_buf_is_valid(s.buf)) then
    return
  end
  local lines, map = {}, {}
  for _, b in ipairs(list_terminals()) do
    local marker = win_showing(b, s.tab) and '\u{25cf} ' or '  '
    lines[#lines + 1] = marker .. label(b)
    map[#lines] = b
  end
  s.shown = map

  vim.bo[s.buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
  vim.bo[s.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(s.buf, NS, 0, -1)
  for ln, b in pairs(map) do
    if b == s.active then
      vim.api.nvim_buf_set_extmark(s.buf, NS, ln - 1, 0, { end_row = ln, hl_group = 'Title', hl_eol = true })
    end
  end

  sidebar.request_rows(s.tab, 'shelllist', #lines)
end

local function select(s)
  local b = s.shown[vim.api.nvim_win_get_cursor(0)[1]]
  if not b then
    return
  end
  local w = win_showing(b, s.tab)
  if w then
    vim.api.nvim_set_current_win(w)
  else
    -- Reopen ToggleTerm through its owner, including hidden task terminals,
    -- so future toggles still know which window belongs to the terminal.
    local terminals = package.loaded['toggleterm.terminal']
    local term = terminals and terminals.find(function(t)
      return t.bufnr == b
    end)
    if term then
      term:open()
    elseif vim.b[b].agent_terminal then
      vim.cmd(('vertical botright %dsplit'):format(math.floor(vim.o.columns * 0.35)))
      vim.api.nvim_win_set_buf(0, b)
      sidebar.layout()
    else
      vim.cmd 'botright 15split'
      vim.api.nvim_win_set_buf(0, b)
      sidebar.layout()
    end
  end
  local selected_win = vim.api.nvim_get_current_win()
  -- ToggleTerm restores its saved mode on the next tick. List selection
  -- means typing in the shell, so enter insert mode after that restoration.
  vim.schedule(function()
    if
      vim.api.nvim_get_current_tabpage() == s.tab
      and vim.api.nvim_get_current_win() == selected_win
      and vim.api.nvim_get_current_buf() == b
    then
      vim.cmd 'startinsert'
    end
  end)
end

local function close_shell(s)
  local b = s.shown[vim.api.nvim_win_get_cursor(0)[1]]
  if not b then
    return
  end
  pcall(vim.fn.jobstop, vim.bo[b].channel)
  local ok, err = pcall(vim.api.nvim_buf_delete, b, { force = true })
  if not ok then
    vim.notify('shelllist: ' .. tostring(err), vim.log.levels.WARN)
  end
end

local function create_buf(s)
  s.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[s.buf].buftype = 'nofile'
  vim.bo[s.buf].bufhidden = 'wipe'
  vim.bo[s.buf].swapfile = false
  vim.bo[s.buf].filetype = 'shelllist'
  vim.api.nvim_buf_set_name(s.buf, 'OPEN SHELLS [tab ' .. s.tab .. ']')

  local function nmap(lhs, fn, desc)
    vim.keymap.set('n', lhs, function()
      fn(s)
    end, { buffer = s.buf, nowait = true, desc = desc })
  end
  nmap('<CR>', select, 'Focus/open shell')
  nmap('l', select, 'Focus/open shell')
  nmap('d', close_shell, 'Close shell')
end

-- Dock directly under OPEN EDITORS when it's open, else straight under the
-- explorer -- self-heals either way since M.ensure() is idempotent and
-- re-run on the same triggers as util/bufferlist.lua.
local function anchor_win()
  return require('util.bufferlist').win() or sidebar.explorer_win()
end

-- Idempotent: safe to call any time the explorer (or OPEN EDITORS) might
-- have (re)opened.
function M.ensure()
  local s = state()
  local anchor = anchor_win()
  if not anchor then
    return
  end
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    render(s)
    sidebar.layout()
    return
  end

  if not (s.buf and vim.api.nvim_buf_is_valid(s.buf)) then
    create_buf(s)
  end

  -- Open the scratch buffer directly; briefly duplicating a Neo-tree buffer
  -- in a new split would trigger its window lifecycle handlers.
  vim.api.nvim_win_call(anchor, function()
    vim.cmd('noautocmd belowright sbuffer ' .. s.buf)
    s.win = vim.api.nvim_get_current_win()
  end)
  vim.wo[s.win].number = false
  vim.wo[s.win].relativenumber = false
  vim.wo[s.win].signcolumn = 'no'
  vim.wo[s.win].wrap = false
  vim.wo[s.win].cursorline = true
  vim.wo[s.win].winfixheight = true
  vim.wo[s.win].winbar = ' OPEN SHELLS'

  render(s)
  sidebar.layout()
end

function M.close(tab)
  local s = states[tab or vim.api.nvim_get_current_tabpage()]
  if not s then
    return
  end
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_close(s.win, true)
  end
  s.win = nil
end

function M.win(tab)
  local s = states[tab or vim.api.nvim_get_current_tabpage()]
  return s and s.win and vim.api.nvim_win_is_valid(s.win) and s.win or nil
end

-- Coalesce global inventory changes, retaining each originating tab's state.
local function refresh()
  for tab, s in pairs(states) do
    if not s.pending then
      s.pending = true
      vim.schedule(function()
        s.pending = false
        if vim.api.nvim_tabpage_is_valid(tab) and states[tab] == s then
          render(s)
        end
      end)
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('cursorlike_shelllist', { clear = true })

  vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
    group = group,
    callback = function(a)
      if vim.bo[a.buf].filetype == 'neo-tree' then
        sidebar.schedule(M.ensure)
      end
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function(a)
      local win = tonumber(a.match)
      local tab = vim.api.nvim_win_get_tabpage(win)
      local s = states[tab]
      if s and win == s.win then
        s.win = nil
      end
      sidebar.schedule(function()
        if not sidebar.explorer_win() then
          M.close(tab)
        end
      end, tab)
      refresh()
    end,
  })

  vim.api.nvim_create_autocmd('TabClosed', {
    group = group,
    callback = function()
      for tab, s in pairs(states) do
        if not vim.api.nvim_tabpage_is_valid(tab) then
          states[tab] = nil
          if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
            vim.api.nvim_buf_delete(s.buf, { force = true })
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'TermOpen', 'BufDelete', 'BufWipeout', 'BufWinEnter', 'WinEnter' }, {
    group = group,
    callback = refresh,
  })

  vim.api.nvim_create_autocmd({ 'TermEnter', 'BufEnter' }, {
    group = group,
    callback = function(a)
      if vim.bo[a.buf].buftype == 'terminal' then
        local s = state()
        s.active = a.buf
        render(s)
      end
    end,
  })
end

return M
