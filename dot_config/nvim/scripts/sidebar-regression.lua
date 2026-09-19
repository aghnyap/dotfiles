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
  eq(api.nvim_win_get_height(original[2]), 2, 'Editor list must fit its inventory')
  eq(api.nvim_win_get_height(original[3]), 2, 'Empty shell list must keep its minimum height')
  local term = Terminal:new { cmd = 'cat', direction = 'horizontal' }
  for _, origin in ipairs { editor, original[1], original[2], original[3] } do
    api.nvim_set_current_win(origin)
    term:toggle()
    flush()
    check_layout(term)
    eq(api.nvim_get_current_win(), term.window, 'Terminal opening must retain focus')
    eq(api.nvim_win_get_width(original[1]), width, 'Sidebar width changed')
    eq(api.nvim_win_get_height(term.window), 15, 'Horizontal terminal height changed')
    eq(api.nvim_win_get_height(original[2]), 2, 'Opening a terminal must preserve editor-list height')
    eq(api.nvim_win_get_height(original[3]), 2, 'Opening a terminal must preserve shell-list height')
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

  local child = vim
    .system({ vim.v.progpath, '--headless', '-u', 'NONE', '-i', 'NONE', '-l', source .. '/scripts/sidebar-regression.lua' }, {
      cwd = vim.fs.dirname(vim.fs.dirname(source)),
      env = { NVIM_SIDEBAR_QUIT_TEST = '1' },
      text = true,
    })
    :wait(10000)
  eq(child.code, 0, 'Last-editor quit regression: ' .. (child.stderr or ''))
end
local ok, err = xpcall(function()
  if vim.env.NVIM_SIDEBAR_QUIT_TEST == '1' then
    api.nvim_set_current_buf(file 'last-editor')
    local editor = api.nvim_get_current_win()
    vim.cmd 'Neotree show'
    flush()
    check_layout()
    api.nvim_win_close(editor, false)
    flush()
    error 'Closing the last editor did not quit Neovim'
  end
  run()
end, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd 'cquit 1'
end
print 'sidebar regressions: PASS'
vim.cmd 'qa!'
