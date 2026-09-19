-- Run from the chezmoi source root with `just nvim-sidebar-test`.
-- Uses installed plugins, but only the source configuration and scratch files.
local api = vim.api
local source = vim.fn.getcwd() .. '/dot_config/nvim'
vim.opt.rtp:prepend(source)
for _, name in ipairs {
  'bufferline.nvim',
  'toggleterm.nvim',
  'neo-tree.nvim',
  'nui.nvim',
  'plenary.nvim',
  'nvim-web-devicons',
} do
  local path = vim.fn.stdpath 'data' .. '/lazy/' .. name
  assert(vim.fn.isdirectory(path) == 1, 'Missing installed test dependency: ' .. name)
  vim.opt.rtp:append(path)
end
vim.o.columns, vim.o.lines = 180, 60
vim.o.splitbelow, vim.o.splitright = true, true
vim.o.hidden = true
vim.o.swapfile = false
vim.o.laststatus = 3
vim.o.shell = '/bin/sh'
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
temp = assert(vim.uv.fs_realpath(temp))
vim.cmd.cd(temp)
vim.cmd.argadd(temp .. '/A') -- suppress the no-argument startup explorer
local errors = {}
vim.notify = function(msg, level)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(msg)
  end
end
local function flush()
  vim.wait(250, function()
    return false
  end)
  assert(#errors == 0, table.concat(errors, '\n'))
  assert(vim.v.errmsg == '', vim.v.errmsg)
end
local function eq(actual, expected, message)
  assert(
    vim.deep_equal(actual, expected),
    message .. '\nactual: ' .. vim.inspect(actual) .. '\nexpected: ' .. vim.inspect(expected)
  )
end
local function spec(module, name)
  for _, item in ipairs(require(module)) do
    if item[1] == name then
      return item
    end
  end
  error('Missing spec: ' .. name)
end
require('bufferline').setup(spec('plugins.ui', 'akinsho/bufferline.nvim').opts(nil, {
  options = { diagnostics = false, show_buffer_icons = false },
}))
require('toggleterm').setup(spec('plugins.editor', 'akinsho/toggleterm.nvim').opts)
local tree_opts = vim.deepcopy(spec('plugins.ui', 'nvim-neo-tree/neo-tree.nvim').opts)
tree_opts.enable_git_status = false
tree_opts.enable_diagnostics = false
tree_opts.filesystem.use_libuv_file_watcher = false
api.nvim_create_augroup('FileExplorer', {}) -- netrw is absent under -u NONE
require('neo-tree').setup(tree_opts)
vim.cmd 'runtime plugin/neo-tree.lua'
dofile(source .. '/lua/config/autocmds.lua')
local sidebar = require 'util.sidebar'
local buffers = require 'util.bufferlist'
local shells = require 'util.shelllist'
local Terminal = require('toggleterm.terminal').Terminal
local function file(name)
  local buf = api.nvim_create_buf(true, false)
  api.nvim_buf_set_name(buf, temp .. '/' .. name)
  return buf
end
local function panel_buf(win)
  assert(win and api.nvim_win_is_valid(win), 'Missing list window')
  return api.nvim_win_get_buf(win)
end
local function rows(win)
  return vim.fn.getwininfo(win)[1].height
end
local function lines(win)
  return api.nvim_buf_get_lines(panel_buf(win), 0, -1, false)
end
local function mapped(win, label, key)
  api.nvim_set_current_win(win)
  for row, line in ipairs(lines(win)) do
    if line:find(label, 1, true) then
      api.nvim_win_set_cursor(win, { row, 0 })
      local mapping = vim.fn.maparg(key, 'n', false, true)
      assert(mapping.callback, 'Missing panel mapping: ' .. key)
      mapping.callback()
      flush()
      return
    end
  end
  error('Missing panel entry: ' .. label)
end
local function column()
  return { 'col', { { 'leaf', sidebar.explorer_win() }, { 'leaf', buffers.win() }, { 'leaf', shells.win() } } }
end
local function check_layout(term)
  local layout = vim.fn.winlayout()
  eq(layout[1], 'row', 'Sidebar must span the full height')
  eq(layout[2][1], column(), 'Explorer/editors/shells must form one ordered column')
  if term then
    assert(
      api.nvim_win_get_position(term.window)[2] >= api.nvim_win_get_width(sidebar.explorer_win()) + 1,
      'Terminal overlaps sidebar'
    )
    eq(api.nvim_win_get_buf(term.window), term.bufnr, 'Terminal window identity lost')
  end
end
local escape_case
local function run()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    vim.bo[buf].buflisted = false
  end
  local a, b, c = file 'A', file 'B', file 'C'
  api.nvim_set_current_buf(c)
  flush()
  api.nvim_buf_delete(b, {})
  flush()
  vim.cmd 'BufferLineCyclePrev'
  eq(api.nvim_get_current_buf(), a, 'Previous after deleting hidden B must select A')
  flush()
  vim.cmd 'BufferLineCycleNext'
  eq(api.nvim_get_current_buf(), c, 'Next must return to C')
  flush()
  vim.cmd 'BufferLineCycleNext'
  eq(api.nvim_get_current_buf(), a, 'Next must wrap to A')
  flush()
  vim.cmd 'BufferLineCyclePrev'
  eq(api.nvim_get_current_buf(), c, 'Previous must wrap to C')
  eq(vim.o.showtabline, 0, 'Horizontal tabline must stay hidden')

  local editor = api.nvim_get_current_win()
  vim.cmd 'Neotree show'
  flush()
  eq(api.nvim_get_current_win(), editor, 'Sidebar creation must preserve editor focus')
  check_layout()
  local original = { sidebar.explorer_win(), buffers.win(), shells.win() }
  local width = api.nvim_win_get_width(original[1])
  eq(rows(original[2]), 2, 'Editor list must fit its inventory')
  eq(rows(original[3]), 2, 'Empty shell list must keep its minimum height')
  local term = Terminal:new { cmd = 'cat', direction = 'horizontal' }
  for _, origin in ipairs { editor, original[1], original[2], original[3] } do
    api.nvim_set_current_win(origin)
    term:toggle()
    flush()
    check_layout(term)
    eq(api.nvim_get_current_win(), term.window, 'Terminal opening must retain focus')
    eq(api.nvim_win_get_width(original[1]), width, 'Sidebar width changed')
    eq(api.nvim_win_get_height(term.window), 15, 'Horizontal terminal height changed')
    eq(rows(original[2]), 2, 'Opening a terminal must preserve editor-list height')
    eq(rows(original[3]), 2, 'Opening a terminal must preserve shell-list height')
    eq({ sidebar.explorer_win(), buffers.win(), shells.win() }, original, 'Sidebar window identities changed')
    local layout = vim.fn.winlayout()
    local dimensions = vim.fn.winrestcmd()
    sidebar.layout()
    eq(vim.fn.winlayout(), layout, 'Repeated layout must be idempotent')
    eq(vim.fn.winrestcmd(), dimensions, 'Repeated layout must preserve sizes')
    term:toggle()
    flush()
    check_layout()
  end
  -- User resizing survives opening the bottom terminal and repeated layout.
  api.nvim_win_set_width(original[1], 36)
  api.nvim_set_current_win(editor)
  term:open()
  flush()
  eq(api.nvim_win_get_width(original[1]), 36, 'Resized sidebar width must survive terminal opening')
  api.nvim_win_set_height(term.window, 10)
  sidebar.layout()
  eq(api.nvim_win_get_height(term.window), 10, 'Layout must preserve terminal resizing')
  term:close()
  flush()
  local term_buf = term.bufnr
  mapped(shells.win(), '#toggleterm#' .. term.id, '<CR>')
  check_layout(term)
  eq(term.bufnr, term_buf, 'Reopening must retain terminal buffer/job')
  assert(term:is_open(), 'Reopened ToggleTerm must know it is open')
  api.nvim_set_current_win(editor)
  api.nvim_set_current_buf(c)
  flush()
  vim.cmd 'BufferLineCycleNext'
  eq(api.nvim_get_current_buf(), a, 'Buffer cycling must exclude terminals')
  flush()
  api.nvim_set_current_buf(c)
  flush()
  term:toggle()
  flush()
  assert(not term:is_open(), 'Toggle must hide a shell selected from the list')

  api.nvim_set_current_win(editor)
  vim.cmd 'vsplit'
  local editor2 = api.nvim_get_current_win()
  api.nvim_set_current_buf(a)
  vim.cmd 'split'
  local editor3 = api.nvim_get_current_win()
  local editor_ids = { [editor] = true, [editor2] = true, [editor3] = true }
  local function editors_only(node)
    if node[1] == 'leaf' then
      return editor_ids[node[2]] and node or nil
    end
    local children = {}
    for _, child in ipairs(node[2]) do
      local kept = editors_only(child)
      if kept then
        children[#children + 1] = kept
      end
    end
    if #children == 0 then
      return nil
    end
    return #children == 1 and children[1] or { node[1], children }
  end
  local editor_layout = editors_only(vim.fn.winlayout())
  term:open()
  local task = Terminal:new { cmd = 'cat', direction = 'horizontal', hidden = true }
  task:open()
  flush()
  check_layout(task)
  check_layout(term)
  local task_window, task_buf = task.window, task.bufnr
  eq(editors_only(vim.fn.winlayout()), editor_layout, 'Multiple editor splits must retain their arrangement')
  for _, win in ipairs { editor, editor2, editor3 } do
    assert(api.nvim_win_is_valid(win))
  end
  eq(task.window, task_window, 'Task terminal window must survive layout')
  task:close()
  flush()
  mapped(shells.win(), '#toggleterm#' .. task.id, 'l')
  eq(task.bufnr, task_buf, 'Hidden task must retain its terminal buffer')
  assert(task:is_open(), 'Hidden task must reopen through its Terminal object')
  check_layout(task)
  task:shutdown()
  term:close()
  flush()

  api.nvim_set_current_win(editor)
  vim.cmd 'botright new'
  local plain_win = api.nvim_get_current_win()
  local job = vim.fn.jobstart({ 'cat', '-u' }, { term = true })
  local plain_buf = api.nvim_get_current_buf()
  vim.bo[plain_buf].bufhidden = 'hide'
  api.nvim_win_close(plain_win, true)
  flush()
  mapped(shells.win(), vim.fn.exepath 'cat', '<CR>')
  eq(api.nvim_get_current_buf(), plain_buf, 'Plain terminal must reopen in a split')
  check_layout { window = api.nvim_get_current_win(), bufnr = plain_buf }
  mapped(shells.win(), vim.fn.exepath 'cat', 'd')
  assert(not api.nvim_buf_is_valid(plain_buf), 'Shell deletion must remove terminal buffer')
  eq(vim.fn.jobwait({ job }, 0)[1], -3, 'Shell deletion must stop the job')

  -- Float/vertical opens retain ToggleTerm's existing behavior.
  for _, direction in ipairs { 'float', 'vertical' } do
    api.nvim_set_current_win(editor)
    local before = vim.fn.winlayout()
    local other = Terminal:new { cmd = 'cat', direction = direction }
    other:open()
    flush()
    eq(other.direction, direction, 'Terminal direction changed')
    if direction == 'float' then
      eq(vim.fn.winlayout(), before, 'Floating terminal must not rearrange splits')
    end
    eq(api.nvim_win_get_buf(other.window), other.bufnr, 'Terminal must own its window')
    other:shutdown()
    flush()
  end

  -- All file/shell inventories stay global, with independent local panels.
  api.nvim_set_current_win(editor)
  term:open()
  flush()
  local tab1 = api.nvim_get_current_tabpage()
  local buf1, shell1 = panel_buf(buffers.win()), panel_buf(shells.win())
  vim.cmd 'tabnew'
  local tab2 = api.nvim_get_current_tabpage()
  api.nvim_set_current_buf(a)
  vim.cmd 'Neotree show'
  flush() -- let Neo-tree's own asynchronous navigation finish
  buffers.close()
  shells.close()
  local tree_buf = panel_buf(sidebar.explorer_win())
  for _, group in ipairs { 'cursorlike_bufferlist', 'cursorlike_shelllist' } do
    api.nvim_exec_autocmds('BufWinEnter', { buffer = tree_buf, group = group })
  end
  -- Switch before the scheduled panel creation runs.
  api.nvim_set_current_tabpage(tab1)
  flush()
  eq(api.nvim_get_current_tabpage(), tab1, 'Deferred creation must not steal tab focus')
  local buf2, shell2 = panel_buf(buffers.win(tab2)), panel_buf(shells.win(tab2))
  assert(buf1 ~= buf2 and shell1 ~= shell2, 'Each tab must own distinct scratch buffers')
  assert(api.nvim_buf_get_name(buf1) ~= api.nvim_buf_get_name(buf2), 'Scratch names must be unique')
  eq(lines(buffers.win(tab1)), lines(buffers.win(tab2)), 'File inventories must be global')
  local shell_line1 = table.concat(lines(shells.win(tab1)), '\n')
  local shell_line2 = table.concat(lines(shells.win(tab2)), '\n')
  assert(shell_line1:find('●', 1, true) and not shell_line2:find('●', 1, true), 'Shell dots must be tab-local')
  api.nvim_set_current_tabpage(tab2)
  check_layout()
  mapped(buffers.win(), 'A', 'l')
  eq(api.nvim_get_current_buf(), a, 'Buffer selection must focus an editor')
  local d = file 'D'
  flush()
  mapped(buffers.win(), 'D', 'd')
  assert(not api.nvim_buf_is_valid(d), 'Buffer deletion mapping must delete the selected buffer')
  eq(lines(buffers.win(tab1)), lines(buffers.win(tab2)), 'Global inventory must refresh in inactive tabs')
  local ns = api.nvim_create_namespace 'bufferlist'
  local function highlighted(win)
    local buf = panel_buf(win)
    local marks = api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    assert(#marks == 1, 'Expected one active editor per tab')
    return api.nvim_buf_get_lines(buf, marks[1][2], marks[1][2] + 1, false)[1]
  end
  assert(highlighted(buffers.win(tab2)):find('A', 1, true), 'Tab 2 active file must be A')
  local active2 = highlighted(buffers.win(tab2))
  api.nvim_set_current_tabpage(tab1)
  api.nvim_set_current_win(editor)
  api.nvim_set_current_buf(c)
  flush()
  assert(highlighted(buffers.win(tab1)):find('C', 1, true), 'Tab 1 active file must be C')
  eq(highlighted(buffers.win(tab2)), active2, 'Focus in tab 1 must not change tab 2 active file')
  api.nvim_set_current_tabpage(tab2)
  local tab2_windows = { sidebar.explorer_win(), buffers.win(), shells.win() }
  api.nvim_set_current_tabpage(tab1)
  vim.cmd 'Neotree toggle'
  api.nvim_set_current_tabpage(tab2)
  flush()
  assert(not buffers.win(tab1) and not shells.win(tab1), 'Closing Explorer must close only its own lists')
  eq({ sidebar.explorer_win(), buffers.win(), shells.win() }, tab2_windows, 'Other tab sidebar must survive toggle')
  api.nvim_set_current_tabpage(tab1)
  vim.cmd 'Neotree show'
  flush()
  api.nvim_set_current_tabpage(tab2)
  flush()
  assert(buffers.win(tab1) and shells.win(tab1), 'Explorer reopening must recreate both lists')
  api.nvim_set_current_tabpage(tab1)
  local doomed = { panel_buf(buffers.win()), panel_buf(shells.win()) }
  -- Queue work immediately before its tab is destroyed.
  sidebar.schedule(buffers.ensure)
  sidebar.schedule(shells.ensure)
  vim.cmd 'tabclose'
  flush()
  eq(api.nvim_get_current_tabpage(), tab2, 'Closing a tab must retain the surviving tab')
  for _, buf in ipairs(doomed) do
    assert(not api.nvim_buf_is_valid(buf), 'Closed tab scratch buffer leaked')
  end
  assert(not buffers.win(tab1) and not shells.win(tab1), 'Closed tab state must be cleared')
  eq({ sidebar.explorer_win(), buffers.win(), shells.win() }, tab2_windows, 'Surviving sidebar windows changed')
  check_layout()
  mapped(shells.win(), '#toggleterm#' .. term.id, 'd')
  assert(not api.nvim_buf_is_valid(term_buf), 'ToggleTerm deletion must remove its buffer')
  eq(vim.o.showtabline, 0, 'Terminals/tabpages must not expose the horizontal tabline')

  for _, case in ipairs { 'quit', 'close-editor', 'layout', 'sizes', 'tree-open' } do
    local child = vim
      .system(
        { vim.v.progpath, '--headless', '-u', 'NONE', '-i', 'NONE', '-l', source .. '/scripts/sidebar-regression.lua' },
        {
          cwd = vim.fs.dirname(vim.fs.dirname(source)),
          env = { NVIM_SIDEBAR_CASE = case },
          text = true,
        }
      )
      :wait(30000)
    eq(child.code, 0, 'Child case ' .. case .. ': ' .. (child.stderr or ''))
  end
  escape_case()
end

-- ── Full-height AI column ─────────────────────────────────────────
-- A stand-in for the snacks-backed agent panes: a right vertical split whose
-- terminal buffer carries the agent_terminal marker before TermOpen.
local function open_ai(anchor)
  if anchor then
    api.nvim_set_current_win(anchor)
    vim.cmd 'rightbelow new'
  else
    vim.cmd(('vertical botright %dnew'):format(math.floor(vim.o.columns * 0.35)))
  end
  local buf = api.nvim_get_current_buf()
  vim.b[buf].agent_terminal = true
  vim.bo[buf].bufhidden = 'hide'
  local job = vim.fn.jobstart({ 'cat' }, { term = true })
  flush()
  return { window = api.nvim_get_current_win(), bufnr = buf, job = job }
end
local function full_height()
  return vim.o.lines - vim.o.cmdheight - 1
end
local function leaves(node, out)
  if node[1] == 'leaf' then
    out[#out + 1] = node[2]
  else
    for _, child in ipairs(node[2]) do
      leaves(child, out)
    end
  end
  return out
end
local function check_ai(ais, term)
  local layout = vim.fn.winlayout()
  eq(layout[1], 'row', 'AI column needs a top-level row')
  local want, trailing = {}, {}
  for _, ai in ipairs(ais) do
    want[ai.window] = true
    eq(api.nvim_win_get_buf(ai.window), ai.bufnr, 'AI window identity lost')
    eq(vim.fn.jobwait({ ai.job }, 0)[1], -1, 'AI job must keep running')
  end
  for i = #layout[2], 1, -1 do
    local wins = leaves(layout[2][i], {})
    if not want[wins[1]] then
      break
    end
    for _, w in ipairs(wins) do
      assert(want[w], 'AI column mixes in a non-AI window')
      trailing[#trailing + 1] = w
    end
  end
  eq(#trailing, #ais, 'Every AI pane must sit in the right-hand column')
  local total = 0
  local seen_cols = {}
  for _, w in ipairs(trailing) do
    local col = api.nvim_win_get_position(w)[2]
    if not seen_cols[col] then
      seen_cols[col] = true
    end
    total = total + api.nvim_win_get_height(w)
  end
  if #ais == 1 then
    eq(api.nvim_win_get_height(ais[1].window), full_height(), 'AI pane must span the full height')
  end
  if term then
    local left = math.huge
    for _, w in ipairs(trailing) do
      left = math.min(left, api.nvim_win_get_position(w)[2])
    end
    local tcol = api.nvim_win_get_position(term.window)[2]
    assert(tcol + api.nvim_win_get_width(term.window) < left, 'ToggleTerm extends under the AI column')
    eq(api.nvim_win_get_buf(term.window), term.bufnr, 'Terminal window identity lost')
  end
end
local function stable()
  local layout, dims = vim.fn.winlayout(), vim.fn.winrestcmd()
  sidebar.layout()
  flush()
  eq(vim.fn.winlayout(), layout, 'Repeated layout must not rearrange')
  eq(vim.fn.winrestcmd(), dims, 'Repeated layout must not resize')
end

local function layout_case()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    vim.bo[buf].buflisted = false
  end
  api.nvim_set_current_buf(file 'A')
  local editor = api.nvim_get_current_win()
  vim.cmd 'Neotree show'
  flush()
  local width = api.nvim_win_get_width(sidebar.explorer_win())

  -- AI first, then ToggleTerm.
  local ai = open_ai()
  local ai_width = api.nvim_win_get_width(ai.window)
  check_ai { ai }
  check_layout()
  api.nvim_set_current_win(editor)
  local term = Terminal:new { cmd = 'cat', direction = 'horizontal' }
  term:open()
  flush()
  check_layout(term)
  check_ai({ ai }, term)
  eq(api.nvim_get_current_win(), term.window, 'ToggleTerm must keep focus')
  eq(api.nvim_win_get_height(term.window), 15, 'ToggleTerm height changed')
  eq(api.nvim_win_get_width(ai.window), ai_width, 'AI width changed')
  eq(api.nvim_win_get_width(sidebar.explorer_win()), width, 'Sidebar width changed')
  stable()

  -- ToggleTerm first, then AI reopened from OPEN SHELLS.
  api.nvim_win_close(ai.window, true)
  flush()
  mapped(shells.win(), vim.fn.exepath 'cat', '<CR>') -- first cat entry is the AI buffer
  ai.window = api.nvim_get_current_win()
  eq(api.nvim_win_get_buf(ai.window), ai.bufnr, 'List must reopen the AI buffer')
  check_layout(term)
  check_ai({ ai }, term)
  stable()
  -- ToggleTerm reopened from OPEN SHELLS while the AI pane is visible.
  term:close()
  flush()
  mapped(shells.win(), '#toggleterm#' .. term.id, '<CR>')
  check_layout(term)
  check_ai({ ai }, term)
  -- ToggleTerm first, then a brand-new AI pane.
  term:close()
  api.nvim_win_close(ai.window, true)
  flush()
  api.nvim_set_current_win(editor)
  term:open()
  flush()
  local fresh = open_ai()
  check_layout(term)
  check_ai({ fresh }, term)
  vim.fn.jobstop(fresh.job)
  api.nvim_buf_delete(fresh.bufnr, { force = true })
  flush()

  -- Multiple AI panes stay stacked together; multiple editor splits survive.
  term:close()
  flush()
  api.nvim_set_current_win(editor)
  vim.cmd 'vsplit'
  local editor2 = api.nvim_get_current_win()
  vim.cmd 'split'
  local editor3 = api.nvim_get_current_win()
  vim.cmd(('vertical botright %dsplit'):format(math.floor(vim.o.columns * 0.35)))
  api.nvim_win_set_buf(0, ai.bufnr)
  ai.window = api.nvim_get_current_win()
  flush()
  local ai2 = open_ai(ai.window)
  eq(api.nvim_win_get_position(ai2.window)[2], api.nvim_win_get_position(ai.window)[2], 'Stacked AI setup')
  local ai_heights = { api.nvim_win_get_height(ai.window), api.nvim_win_get_height(ai2.window) }
  api.nvim_set_current_win(editor3)
  term:open()
  flush()
  check_layout(term)
  check_ai({ ai, ai2 }, term)
  eq(api.nvim_win_get_position(ai2.window)[2], api.nvim_win_get_position(ai.window)[2], 'AI panes must stay stacked')
  assert(api.nvim_win_get_position(ai2.window)[1] > api.nvim_win_get_position(ai.window)[1], 'AI order changed')
  for i, win in ipairs { ai.window, ai2.window } do
    assert(math.abs(api.nvim_win_get_height(win) - ai_heights[i]) <= 1, 'Stacked AI split ratio must survive')
  end
  eq(api.nvim_get_current_win(), term.window, 'Focus moved')
  for _, win in ipairs { editor, editor2, editor3 } do
    assert(api.nvim_win_is_valid(win), 'Editor split lost')
    assert(api.nvim_win_get_position(win)[1] < api.nvim_win_get_position(term.window)[1], 'Editor below ToggleTerm')
  end
  eq(
    api.nvim_win_get_position(editor3)[2],
    api.nvim_win_get_position(editor2)[2],
    'Horizontal editor split arrangement changed'
  )
  assert(api.nvim_win_get_position(editor2)[2] > api.nvim_win_get_position(editor)[2], 'Vertical editor split changed')
  stable()

  -- Explorer hidden: the AI boundary still holds.
  term:close()
  api.nvim_win_close(ai2.window, true)
  vim.cmd 'Neotree close'
  flush()
  assert(not sidebar.explorer_win(), 'Explorer should be hidden')
  api.nvim_set_current_win(editor)
  term:open()
  flush()
  check_ai({ ai }, term)
  assert(api.nvim_win_get_position(term.window)[2] == 0, 'ToggleTerm should start at the left edge')
  stable()
  -- Floating terminals never rearrange splits.
  local before = vim.fn.winlayout()
  local float = Terminal:new { cmd = 'cat', direction = 'float' }
  float:open()
  flush()
  eq(vim.fn.winlayout(), before, 'Floating terminal must not rearrange splits')
  float:shutdown()
  flush()
end

-- ── List heights ──────────────────────────────────────────────────
local function sizes_case()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    vim.bo[buf].buflisted = false
  end
  local files = { file 'F1' }
  api.nvim_set_current_buf(files[1])
  local editor = api.nvim_get_current_win()
  vim.cmd 'Neotree show'
  flush()
  local explorer = sidebar.explorer_win()
  local function column_total(tab)
    local total = 0
    for _, w in ipairs { sidebar.explorer_win(tab), buffers.win(tab), shells.win(tab) } do
      total = total + api.nvim_win_get_height(w)
    end
    return total
  end
  local total = column_total()
  local function clamp(n)
    return math.max(2, math.min(12, n))
  end
  local function expect(nfiles, nshells, tab, message)
    eq(rows(buffers.win(tab)), clamp(nfiles), message .. ': OPEN EDITORS rows')
    eq(rows(shells.win(tab)), clamp(nshells), message .. ': OPEN SHELLS rows')
    eq(column_total(tab), total, message .. ': column height')
  end
  local shells_open = {}
  local function set_files(n)
    while #files < n do
      files[#files + 1] = file('F' .. (#files + 1))
    end
    while #files > n do
      api.nvim_buf_delete(table.remove(files), { force = true })
    end
  end
  local function set_shells(n)
    while #shells_open < n do
      local t = Terminal:new { cmd = 'cat', direction = 'horizontal', hidden = true }
      t:spawn()
      shells_open[#shells_open + 1] = t
    end
    while #shells_open > n do
      table.remove(shells_open):shutdown()
    end
  end
  local steps = { 2, 3, 5, 12, 13, 12, 5, 3, 2 }
  for _, n in ipairs(steps) do
    set_files(n)
    flush()
    expect(n, 0, nil, n .. ' files')
  end
  for _, n in ipairs(steps) do
    set_shells(n)
    flush()
    expect(2, n, nil, n .. ' shells')
  end
  -- Both inventories change in the same tick.
  set_files(5)
  set_shells(4)
  flush()
  expect(5, 4, nil, 'simultaneous')
  set_files(13)
  set_shells(1)
  flush()
  expect(13, 1, nil, 'simultaneous swap')
  eq(explorer, sidebar.explorer_win(), 'Explorer window replaced')

  -- An inactive tab follows the global inventory without taking focus.
  local tab1 = api.nvim_get_current_tabpage()
  vim.cmd 'tabnew'
  local tab2 = api.nvim_get_current_tabpage()
  vim.cmd 'Neotree show'
  flush()
  api.nvim_set_current_tabpage(tab1)
  api.nvim_set_current_win(editor)
  set_files(3)
  set_shells(6)
  flush()
  eq(api.nvim_get_current_tabpage(), tab1, 'Resizing must not switch tabs')
  eq(api.nvim_get_current_win(), editor, 'Resizing must not move focus')
  expect(3, 6, tab1, 'active tab')
  api.nvim_set_current_tabpage(tab2)
  expect(3, 6, tab2, 'inactive tab')
  vim.cmd 'tabclose'
  flush()

  -- Squeezed screens keep every pane valid, then regain the requested sizes.
  set_files(12)
  set_shells(12)
  vim.o.lines = 20
  flush()
  for _, w in ipairs { sidebar.explorer_win(), buffers.win(), shells.win() } do
    assert(api.nvim_win_is_valid(w) and api.nvim_win_get_height(w) >= 1, 'Pane lost on a small screen')
  end
  vim.o.lines = 60
  flush()
  total = column_total()
  expect(12, 12, nil, 'after regaining space')
end

-- ── Escape in terminals ───────────────────────────────────────────
-- Real key input needs a separate UI-less Neovim driven over RPC: typeahead
-- is not processed while this script is running.
escape_case = function()
  local chan = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE' }, {
    rpc = true,
    cwd = vim.fs.dirname(vim.fs.dirname(source)),
    env = { NVIM_SIDEBAR_CASE = 'embed' },
  })
  local function lua(code, ...)
    return vim.rpcrequest(chan, 'nvim_exec_lua', code, { ... })
  end
  local function mode()
    return vim.rpcrequest(chan, 'nvim_get_mode').mode
  end
  local function wait_mode(want)
    vim.wait(3000, function()
      return mode() == want
    end, 20)
    return mode()
  end
  lua('dofile(...)', source .. '/scripts/sidebar-regression.lua')
  local open = {
    toggleterm = [[
      _G.t = require('toggleterm.terminal').Terminal:new { cmd = 'cat', direction = 'horizontal' }
      _G.t:open()
    ]],
    task = [[
      _G.t = require('toggleterm.terminal').Terminal:new {
        cmd = 'cat', direction = 'horizontal', close_on_exit = false, hidden = true,
      }
      _G.t:open()
    ]],
    agent = [[
      vim.cmd 'vertical botright new'
      vim.b.agent_terminal = true
      vim.fn.jobstart({ 'cat' }, { term = true })
      vim.cmd 'startinsert'
    ]],
    plain = [[
      vim.cmd 'botright new'
      vim.fn.jobstart({ 'cat' }, { term = true })
      vim.cmd 'startinsert'
    ]],
  }
  for _, kind in ipairs { 'toggleterm', 'task', 'agent', 'plain' } do
    lua(open[kind])
    eq(wait_mode 't', 't', kind .. ' must start in terminal mode')
    vim.rpcrequest(chan, 'nvim_input', '<Esc>')
    if kind == 'plain' then
      vim.wait(300)
      eq(mode(), 't', 'Plain terminals must keep sending Escape to the job')
      vim.rpcrequest(chan, 'nvim_input', [[<C-\><C-n>]])
      eq(wait_mode 'nt', 'nt', 'plain: leave terminal mode')
    else
      eq(wait_mode 'nt', 'nt', kind .. ': one Escape must enter Normal mode')
      vim.rpcrequest(chan, 'nvim_input', ':let g:esc_ok = "' .. kind .. '"<CR>')
      vim.wait(3000, function()
        return lua 'return vim.g.esc_ok' == kind
      end, 20)
      eq(lua 'return vim.g.esc_ok', kind, kind .. ': :commands must run after Escape')
      local before = lua 'return vim.api.nvim_get_current_win()'
      vim.rpcrequest(chan, 'nvim_input', '<C-w>p')
      vim.wait(3000, function()
        return lua 'return vim.api.nvim_get_current_win()' ~= before
      end, 20)
      assert(lua 'return vim.api.nvim_get_current_win()' ~= before, kind .. ': window navigation after Escape')
    end
    if kind == 'toggleterm' then
      -- ToggleTerm's mode persistence still restores Normal mode on reopen.
      lua 'vim.api.nvim_set_current_win(_G.t.window); _G.t:close(); _G.t:open()'
      vim.wait(300)
      eq(wait_mode 'nt', 'nt', 'ToggleTerm must restore the persisted mode')
    end
    if _G.t then
      lua 'if _G.t then _G.t:close() end _G.t = nil'
    end
    lua 'vim.cmd "stopinsert"; vim.cmd "only!"'
  end
  vim.fn.jobstop(chan)
end

local case = vim.env.NVIM_SIDEBAR_CASE
if case ~= 'embed' then
  local ok, err = xpcall(function()
    if case == 'quit' then
      api.nvim_set_current_buf(file 'last-editor')
      -- The argument buffer counts as an open file; it must not keep Neovim up.
      vim.cmd('bwipeout ' .. vim.fn.bufnr(temp .. '/A'))
      local editor = api.nvim_get_current_win()
      vim.cmd 'Neotree show'
      flush()
      check_layout()
      -- Closing the last file leaves an empty pane, as Cursor does.
      local last = api.nvim_get_current_buf()
      local width = api.nvim_win_get_width(sidebar.explorer_win())
      api.nvim_win_close(editor, false)
      flush()
      eq(api.nvim_win_get_width(sidebar.explorer_win()), width, 'Explorer must not keep the closed pane\'s columns')
      assert(not vim.bo[last].buflisted, 'Closed file must leave OPEN EDITORS')
      local wins = sidebar.editor_wins { buffers.win(), shells.win() }
      eq(#wins, 1, 'Closing the last file must leave an empty editor pane')
      eq(api.nvim_buf_get_name(api.nvim_win_get_buf(wins[1])), '', 'The pane left behind must be empty')
      -- Closing that empty pane is what quits.
      api.nvim_win_close(wins[1], false)
      flush()
      error 'Closing the empty editor pane did not quit Neovim'
    elseif case == 'close-editor' then
      -- Closing the last editor pane closes that file, not Neovim, while
      -- OPEN EDITORS still lists others; the next file gets a fresh pane.
      local kept, dirty = file 'kept', file 'dirty'
      vim.bo[dirty].modified = true
      local first = file 'first'
      api.nvim_set_current_buf(first)
      vim.cmd('bwipeout ' .. vim.fn.bufnr(temp .. '/A'))
      local editor = api.nvim_get_current_win()
      vim.cmd 'Neotree show'
      flush()
      check_layout()
      local width = api.nvim_win_get_width(sidebar.explorer_win())
      api.nvim_win_close(editor, false)
      flush()
      eq(api.nvim_win_get_width(sidebar.explorer_win()), width, 'Explorer must not keep the closed pane\'s columns')
      assert(not vim.bo[first].buflisted, 'Closed file must leave OPEN EDITORS')
      local wins = sidebar.editor_wins { buffers.win(), shells.win() }
      eq(#wins, 1, 'A fresh editor pane must replace the closed one')
      local shown = api.nvim_win_get_buf(wins[1])
      assert(shown == kept or shown == dirty, 'Fresh pane must show a remaining file')
      check_layout()
      api.nvim_win_close(wins[1], false)
      flush()
      wins = sidebar.editor_wins { buffers.win(), shells.win() }
      eq(#wins, 1, 'Closing again must reopen the other file')
      -- The modified file is never dropped, so closing it just reshows it.
      eq(vim.bo[dirty].buflisted, true, 'Modified file must stay listed')
    elseif case == 'layout' then
      layout_case()
    elseif case == 'sizes' then
      sizes_case()
    elseif case == 'tree-open' then
      -- Neo-tree opens into the last window entered; the lists must never be it.
      vim.fn.writefile({ 'opened' }, temp .. '/opened.txt')
      api.nvim_set_current_buf(file 'placeholder')
      local editor = api.nvim_get_current_win()
      vim.cmd 'Neotree show'
      flush()
      check_layout()
      for _, panel in ipairs { buffers.win(), shells.win() } do
        local ft = vim.bo[panel_buf(panel)].filetype
        api.nvim_win_set_buf(editor, file('placeholder-' .. ft))
        api.nvim_set_current_win(panel)
        api.nvim_set_current_win(sidebar.explorer_win())
        local row
        for i, line in ipairs(api.nvim_buf_get_lines(0, 0, -1, false)) do
          row = row or (line:find('opened.txt', 1, true) and i)
        end
        assert(row, 'Explorer must list opened.txt')
        api.nvim_win_set_cursor(0, { row, 0 })
        api.nvim_feedkeys(api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)
        flush()
        eq(vim.bo[panel_buf(panel)].filetype, ft, 'Opening from the tree replaced the ' .. ft .. ' panel')
        eq(api.nvim_buf_get_name(api.nvim_win_get_buf(editor)), temp .. '/opened.txt', 'File must open in the editor')
      end
    else
      run()
    end
  end, debug.traceback)
  if not ok then
    io.stderr:write(err .. '\n')
    vim.cmd 'cquit 1'
  end
  if not case then
    print 'sidebar regressions: PASS'
  end
  vim.cmd 'qa!'
end
