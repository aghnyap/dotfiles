-- ╭──────────────────────────────────────────────────────────────╮
-- │  adb logcat as a navigable buffer, not a terminal            │
-- │                                                              │
-- │  `<leader>rl` streams logcat into a toggleterm, which is fine │
-- │  for watching and useless for reading: you cannot filter      │
-- │  without restarting it, and a stack frame is just text.       │
-- │  This keeps the raw stream in a ring buffer and re-renders    │
-- │  from it, so level and text filters are instant and           │
-- │  retroactive -- they apply to what already scrolled past.     │
-- │                                                              │
-- │  Inside the panel:                                           │
-- │    <CR>  jump to the source file under the cursor            │
-- │    l     cycle the minimum level (V D I W E F)               │
-- │    f     filter by text over tag + message                   │
-- │    p     pause/resume the stream (the ring keeps filling)     │
-- │    F     toggle follow (auto-scroll)                          │
-- │    c     clear    q  close                                    │
-- ╰──────────────────────────────────────────────────────────────╯
local M = {}

local ORDER = { 'V', 'D', 'I', 'W', 'E', 'F' }
local RANK = { V = 1, D = 2, I = 3, W = 4, E = 5, F = 6 }
local HL = {
  V = 'Comment',
  D = 'Comment',
  I = 'DiagnosticInfo',
  W = 'DiagnosticWarn',
  E = 'DiagnosticError',
  F = 'DiagnosticError',
}

local NS = vim.api.nvim_create_namespace 'logcat'
local MAX = 5000 -- ring capacity; a busy app emits thousands a minute

local s = {
  buf = nil,
  win = nil,
  job = nil,
  entries = {}, -- ring of { level, tag, msg, raw }
  shown = {}, -- entry index per rendered line, for <CR>
  level = 'V',
  filter = '',
  follow = true,
  paused = false,
  label = '',
}

local adb = vim.fn.expand '$HOME/Library/Android/sdk/platform-tools/adb'

local function root()
  return vim.fs.root(0, { 'melos.yaml', '.git' }) or vim.uv.cwd()
end

-- ── parsing ────────────────────────────────────────────────────
-- `-v threadtime` gives: MM-DD HH:MM:SS.mmm  PID  TID L TAG: message
local function parse(line)
  local lvl, tag, msg = line:match '^%d%d%-%d%d%s+[%d:%.]+%s+%d+%s+%d+%s+([VDIWEFS])%s+(.-):%s?(.*)$'
  if lvl then
    return { level = lvl == 'S' and 'F' or lvl, tag = tag, msg = msg, raw = line }
  end
  -- Anything unparseable (native crash dumps, `--------- beginning of`)
  -- is kept rather than dropped -- those lines are often the interesting ones.
  return { level = 'I', tag = '', msg = line, raw = line }
end

-- ── rendering ──────────────────────────────────────────────────
local function passes(e)
  if RANK[e.level] < RANK[s.level] then
    return false
  end
  if s.filter ~= '' then
    local hay = (e.tag .. ' ' .. e.msg):lower()
    if not hay:find(s.filter:lower(), 1, true) then
      return false
    end
  end
  return true
end

local function title()
  return ('logcat %s  [level %s%s]%s%s'):format(
    s.label,
    s.level,
    s.filter ~= '' and (' /' .. s.filter) or '',
    s.paused and '  PAUSED' or '',
    s.follow and '' or '  (no follow)'
  )
end

local function render()
  if not (s.buf and vim.api.nvim_buf_is_valid(s.buf)) then
    return
  end
  local lines, map = {}, {}
  for i, e in ipairs(s.entries) do
    if passes(e) then
      lines[#lines + 1] = ('%s %s%s%s'):format(e.level, e.tag ~= '' and (e.tag .. ': ') or '', '', e.msg)
      map[#lines] = i
    end
  end
  s.shown = map

  vim.bo[s.buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
  vim.bo[s.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(s.buf, NS, 0, -1)
  for ln, idx in pairs(map) do
    local hl = HL[s.entries[idx].level]
    if hl then
      vim.api.nvim_buf_set_extmark(s.buf, NS, ln - 1, 0, { end_row = ln, hl_group = hl, hl_eol = true })
    end
  end

  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.wo[s.win].winbar = title()
    if s.follow and #lines > 0 then
      pcall(vim.api.nvim_win_set_cursor, s.win, { #lines, 0 })
    end
  end
end

-- Coalesce redraws: adb can deliver hundreds of lines per chunk and
-- re-rendering per line is what makes naive log panels unusable.
local pending = false
local function schedule_render()
  if pending then
    return
  end
  pending = true
  vim.defer_fn(function()
    pending = false
    render()
  end, 60)
end

function M.push(line)
  if line == '' then
    return
  end
  s.entries[#s.entries + 1] = parse(line)
  if #s.entries > MAX then
    table.remove(s.entries, 1)
  end
  if not s.paused then
    schedule_render()
  end
end

-- ── jump to source ─────────────────────────────────────────────
--- Resolve `package:foo/bar/baz.dart` inside a melos workspace by finding the
--- pubspec that declares `name: foo`, then foo/lib/bar/baz.dart.
local function resolve_dart_package(pkg, rel)
  local hits = vim.fn.systemlist {
    'rg', '--files', '--glob', 'pubspec.yaml', '--glob', '!**/build/**', root(),
  }
  for _, ps in ipairs(hits) do
    for line in io.lines(ps) do
      local name = line:match '^name:%s*([%w_]+)'
      if name then
        if name == pkg then
          local cand = vim.fs.joinpath(vim.fs.dirname(ps), 'lib', rel)
          if vim.uv.fs_stat(cand) then
            return cand
          end
        end
        break -- `name:` is near the top; no need to read the whole file
      end
    end
  end
end

local function find_by_basename(base)
  local found = vim.fs.find(base, { path = root(), type = 'file', limit = 8 })
  for _, f in ipairs(found) do
    if not f:match '/build/' and not f:match '/%.dart_tool/' then
      return f
    end
  end
  return found[1]
end

--- Pull a file:line out of a log line. Handles the three shapes that actually
--- show up: Dart package URIs, JVM stack frames, and bare paths.
function M.locate(line)
  -- package:my_core/src/foo.dart:120:9
  local pkg, rel, l = line:match 'package:([%w_]+)/([%w_%-/%.]+%.dart):(%d+)'
  if pkg then
    local f = resolve_dart_package(pkg, rel)
    if f then
      return f, tonumber(l)
    end
    return find_by_basename(vim.fs.basename(rel)), tonumber(l)
  end
  -- at com.example.Foo.bar(Foo.kt:42)
  local base, jl = line:match '%(([%w_%$]+%.%a+):(%d+)%)'
  if base then
    return find_by_basename(base), tonumber(jl)
  end
  -- /abs/or/rel/path.dart:12  (also file:///... )
  local path, pl = line:match '([%w_%-%./]+%.%a+):(%d+)'
  if path then
    path = path:gsub('^file://', '')
    if vim.uv.fs_stat(path) then
      return path, tonumber(pl)
    end
    return find_by_basename(vim.fs.basename(path)), tonumber(pl)
  end
end

local function jump()
  local ln = vim.api.nvim_win_get_cursor(0)[1]
  local idx = s.shown[ln]
  if not idx then
    return
  end
  local file, lnum = M.locate(s.entries[idx].raw)
  if not file then
    vim.notify('logcat: no file reference on this line', vim.log.levels.WARN)
    return
  end
  -- Land in the editor window, not in the panel.
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype == '' and vim.bo[b].filetype ~= 'neo-tree' and w ~= s.win then
      vim.api.nvim_set_current_win(w)
      break
    end
  end
  vim.cmd('edit +' .. (lnum or 1) .. ' ' .. vim.fn.fnameescape(file))
end

-- ── panel ──────────────────────────────────────────────────────
local function open_panel()
  if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
    if not (s.win and vim.api.nvim_win_is_valid(s.win)) then
      vim.cmd 'botright 15split'
      s.win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(s.win, s.buf)
    end
    return
  end

  s.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[s.buf].buftype = 'nofile'
  vim.bo[s.buf].bufhidden = 'hide'
  vim.bo[s.buf].swapfile = false
  vim.bo[s.buf].filetype = 'logcat'
  vim.api.nvim_buf_set_name(s.buf, 'logcat')

  vim.cmd 'botright 15split'
  s.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(s.win, s.buf)
  vim.wo[s.win].number = false
  vim.wo[s.win].relativenumber = false
  vim.wo[s.win].signcolumn = 'no'
  vim.wo[s.win].wrap = false
  vim.wo[s.win].cursorline = true

  local function nmap(lhs, fn, desc)
    vim.keymap.set('n', lhs, fn, { buffer = s.buf, nowait = true, desc = desc })
  end
  nmap('q', function()
    M.close()
  end, 'Close logcat')
  nmap('<CR>', jump, 'Jump to source')
  nmap('c', function()
    s.entries = {}
    render()
  end, 'Clear')
  nmap('p', function()
    s.paused = not s.paused
    render()
  end, 'Pause/resume')
  nmap('F', function()
    s.follow = not s.follow
    render()
  end, 'Toggle follow')
  nmap('l', function()
    local i = 1
    for n, v in ipairs(ORDER) do
      if v == s.level then
        i = n
      end
    end
    s.level = ORDER[(i % #ORDER) + 1]
    render()
  end, 'Cycle minimum level')
  nmap('f', function()
    vim.ui.input({ prompt = 'logcat filter: ', default = s.filter }, function(v)
      if v ~= nil then
        s.filter = v
        render()
      end
    end)
  end, 'Filter text')
end

function M.close()
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_close(s.win, true)
  end
  s.win = nil
end

function M.stop()
  if s.job then
    pcall(function()
      s.job:kill 'sigterm'
    end)
    s.job = nil
  end
end

--- Start streaming. `pkg` is optional; when given and running, logcat is
--- scoped to that process, matching what `<leader>rl` already does.
function M.start(pkg)
  if vim.fn.executable(adb) == 0 and vim.fn.executable 'adb' == 0 then
    vim.notify('logcat: adb not found', vim.log.levels.ERROR)
    return
  end
  local exe = vim.fn.executable(adb) == 1 and adb or 'adb'

  M.stop()
  open_panel()

  local cmd = { exe, 'logcat', '-v', 'threadtime' }
  s.label = ''
  if pkg and pkg ~= '' then
    local ok, res = pcall(function()
      return vim.system({ exe, 'shell', 'pidof', '-s', pkg }, { text = true }):wait(5000)
    end)
    local pid = ok and res.code == 0 and vim.trim(res.stdout or '') or ''
    if pid ~= '' then
      vim.list_extend(cmd, { '--pid=' .. pid })
      s.label = pkg .. ' (pid ' .. pid .. ')'
    else
      -- Same rule as tasks.lua: an unfiltered stream is a conscious fallback,
      -- never a silent --pid=0 that shows nothing.
      vim.notify(pkg .. ' is not running — streaming unfiltered', vim.log.levels.WARN)
    end
  end

  s.job = vim.system(cmd, {
    text = true,
    stdout = function(_, data)
      if not data then
        return
      end
      vim.schedule(function()
        for line in data:gmatch '[^\r\n]+' do
          M.push(line)
        end
      end)
    end,
    stderr = function(_, data)
      if data and vim.trim(data) ~= '' then
        vim.schedule(function()
          vim.notify('logcat: ' .. data, vim.log.levels.ERROR)
        end)
      end
    end,
  }, function() end)

  render()
end

function M.toggle(pkg)
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    M.close()
  elseif s.job then
    open_panel()
    render()
  else
    M.start(pkg)
  end
end

-- Exposed for tests: open the panel without spawning adb, and feed it
-- synthetic lines, so the parse/filter/render path is testable with no
-- device attached.
function M._open()
  open_panel()
end

function M._feed(lines)
  for _, l in ipairs(lines) do
    M.push(l)
  end
  render()
end

function M._state()
  return s
end

return M
