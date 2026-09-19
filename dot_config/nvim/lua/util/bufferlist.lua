-- ╭──────────────────────────────────────────────────────────────╮
-- │  OPEN EDITORS: a vertical list of open file buffers, docked   │
-- │  under the explorer -- replaces bufferline's horizontal       │
-- │  tabline (see plugins/ui.lua, which hides it for good and     │
-- │  keeps bufferline only for the Tab/Shift-Tab cycle commands). │
-- │                                                                │
-- │  Inside the panel:                                            │
-- │    <CR>/l  open buffer in the editor window                   │
-- │    d       close buffer                                       │
-- ╰──────────────────────────────────────────────────────────────╯
local M = {}

local NS = vim.api.nvim_create_namespace 'bufferlist'
local MIN_HEIGHT, MAX_HEIGHT = 2, 12

-- Inventories are global; window ownership, selection and focus are per tab.
local states = {}

local function state(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  if not states[tab] then
    states[tab] = { tab = tab, shown = {} }
  end
  return states[tab]
end

local sidebar = require 'util.sidebar'

local function devicons()
  local ok, mod = pcall(require, 'nvim-web-devicons')
  return ok and mod or nil
end

local function list_buffers()
  local bufs = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].buftype == '' and vim.api.nvim_buf_get_name(b) ~= '' then
      bufs[#bufs + 1] = b
    end
  end
  table.sort(bufs)
  return bufs
end

local function render(s)
  if not (s.buf and vim.api.nvim_buf_is_valid(s.buf)) then
    return
  end
  local icons = devicons()
  local lines, map = {}, {}
  for _, b in ipairs(list_buffers()) do
    local tail = vim.fs.basename(vim.api.nvim_buf_get_name(b))
    local modified = vim.bo[b].modified and '\u{25cf} ' or '  '
    local icon = ''
    if icons then
      local ic = icons.get_icon(tail, tail:match '%.(%a+)$', { default = true })
      icon = ic and (ic .. ' ') or ''
    end
    lines[#lines + 1] = modified .. icon .. tail
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

  if s.win and vim.api.nvim_win_is_valid(s.win) then
    pcall(sidebar.set_panel_height, s.win, math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, #lines)))
  end
end

local function open_in_editor(s, bufnr)
  local wins = sidebar.editor_wins { s.win }
  if wins[1] then
    vim.api.nvim_set_current_win(wins[1])
  else
    vim.api.nvim_set_current_win(s.win)
    vim.cmd 'botright vsplit'
  end
  vim.api.nvim_win_set_buf(0, bufnr)
end

local function select(s)
  local b = s.shown[vim.api.nvim_win_get_cursor(0)[1]]
  if b then
    open_in_editor(s, b)
  end
end

local function close_buffer(s)
  local b = s.shown[vim.api.nvim_win_get_cursor(0)[1]]
  if not b then
    return
  end
  local ok, err = pcall(vim.api.nvim_buf_delete, b, { force = false })
  if not ok then
    vim.notify('bufferlist: ' .. tostring(err), vim.log.levels.WARN)
  end
end

local function create_buf(s)
  s.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[s.buf].buftype = 'nofile'
  vim.bo[s.buf].bufhidden = 'wipe'
  vim.bo[s.buf].swapfile = false
  vim.bo[s.buf].filetype = 'bufferlist'
  vim.api.nvim_buf_set_name(s.buf, 'OPEN EDITORS [tab ' .. s.tab .. ']')

  local function nmap(lhs, fn, desc)
    vim.keymap.set('n', lhs, function()
      fn(s)
    end, { buffer = s.buf, nowait = true, desc = desc })
  end
  nmap('<CR>', select, 'Open buffer')
  nmap('l', select, 'Open buffer')
  nmap('d', close_buffer, 'Close buffer')
end

-- Idempotent: safe to call any time the explorer might have (re)opened.
function M.ensure()
  local s = state()
  local explorer = sidebar.explorer_win()
  if not explorer then
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
  vim.api.nvim_win_call(explorer, function()
    vim.cmd('noautocmd belowright sbuffer ' .. s.buf)
    s.win = vim.api.nvim_get_current_win()
  end)
  vim.wo[s.win].number = false
  vim.wo[s.win].relativenumber = false
  vim.wo[s.win].signcolumn = 'no'
  vim.wo[s.win].wrap = false
  vim.wo[s.win].cursorline = true
  vim.wo[s.win].winfixheight = true
  vim.wo[s.win].winbar = ' OPEN EDITORS'

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

-- Exposed so util/shelllist.lua can dock the OPEN SHELLS panel directly
-- under this one when it's open.
function M.win(tab)
  local s = states[tab or vim.api.nvim_get_current_tabpage()]
  if not s then
    return
  end
  return s.win and vim.api.nvim_win_is_valid(s.win) and s.win or nil
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
  local group = vim.api.nvim_create_augroup('cursorlike_bufferlist', { clear = true })

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

  vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufWipeout', 'BufModifiedSet', 'BufWritePost' }, {
    group = group,
    callback = refresh,
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(a)
      if vim.bo[a.buf].buftype == '' and vim.api.nvim_buf_get_name(a.buf) ~= '' then
        local s = state()
        s.active = a.buf
        render(s)
      end
    end,
  })
end

return M
