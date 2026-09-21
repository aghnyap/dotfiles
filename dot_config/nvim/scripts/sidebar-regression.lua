-- Run from the chezmoi source root with `just nvim-sidebar-test`.
-- Uses installed plugins, but only the source configuration and scratch files.
local api = vim.api
local source = vim.fn.getcwd() .. '/dot_config/nvim'
vim.opt.rtp:prepend(source)
-- Neovim seeds the default runtimepath with the live, applied config even
-- under `-u NONE` (`-u` only skips sourcing it). Left in, a module deleted
-- from source but still deployed to $HOME silently falls back to the live
-- copy instead of failing, defeating the "only the source configuration"
-- guarantee above.
for _, dir in ipairs { vim.fn.stdpath 'config', vim.fn.stdpath 'config' .. '/after' } do
  vim.opt.rtp:remove(dir)
end
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
vim.g.mapleader = ' '
-- LazyVim's global buffer-delete action: Open-list mappings must override it.
vim.keymap.set('n', '<leader>bd', function()
  dofile(vim.fn.stdpath 'data' .. '/lazy/snacks.nvim/lua/snacks/bufdelete.lua').delete()
end)
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
local function column()
  return { 'leaf', sidebar.explorer_win() }
end
local function check_layout(term)
  local layout = vim.fn.winlayout()
  eq(layout[1], 'row', 'Sidebar must span the full height')
  eq(layout[2][1], column(), 'Explorer must anchor the left edge')
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
  local explorer = sidebar.explorer_win()
  local width = api.nvim_win_get_width(explorer)
  local term = Terminal:new { cmd = 'cat', direction = 'horizontal' }
  for _, origin in ipairs { editor, explorer } do
    api.nvim_set_current_win(origin)
    term:toggle()
    flush()
    check_layout(term)
    eq(api.nvim_get_current_win(), term.window, 'Terminal opening must retain focus')
    eq(api.nvim_win_get_width(explorer), width, 'Sidebar width changed')
    eq(api.nvim_win_get_height(term.window), 15, 'Horizontal terminal height changed')
    eq(sidebar.explorer_win(), explorer, 'Sidebar window identity changed')
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
  api.nvim_win_set_width(explorer, 36)
  api.nvim_set_current_win(editor)
  term:open()
  flush()
  eq(api.nvim_win_get_width(explorer), 36, 'Resized sidebar width must survive terminal opening')
  api.nvim_win_set_height(term.window, 10)
  sidebar.layout()
  eq(api.nvim_win_get_height(term.window), 10, 'Layout must preserve terminal resizing')
  term:close()
  flush()
  local term_buf = term.bufnr
  term:open()
  flush()
  check_layout(term)
  eq(term.bufnr, term_buf, 'Reopening must retain terminal buffer/job')
  assert(term:is_open(), 'Reopened ToggleTerm must know it is open')
  -- The Open list labels a terminal with its command rather than the whole
  -- term://<cwd>//<pid>:<cmd> buffer name -- toggleterm's own <id>:<cmd> for
  -- the terminals it owns, a bare command for the ones it does not (the agent
  -- panes). See terminal_title in config/autocmds.lua.
  do
    vim.cmd 'Neotree buffers focus'
    flush()
    local state = require('neo-tree.sources.manager').get_state 'buffers'
    require('neo-tree.ui.renderer').focus_node(state, api.nvim_buf_get_name(term.bufnr))
    eq(state.tree:get_node().name, term.id .. ':cat', 'Open list must label a toggleterm entry <id>:<cmd>')
    -- A throwaway split, not the editor window: deleting a terminal buffer
    -- closes whatever window is showing it, and `editor` is needed below.
    vim.cmd 'botright vnew'
    local bare_win = api.nvim_get_current_win()
    local bare = api.nvim_get_current_buf()
    local bare_job = vim.fn.jobstart({ 'cat' }, { term = true })
    flush()
    eq(vim.b[bare].term_title, 'cat', 'A terminal toggleterm does not own must be labelled by command alone')
    vim.fn.jobstop(bare_job)
    api.nvim_buf_delete(bare, { force = true })
    if api.nvim_win_is_valid(bare_win) then
      api.nvim_win_close(bare_win, true)
    end
    flush()
  end
  -- Exercise the installed buffer-local handlers, including mouse activation.
  for _, key in ipairs { '<2-LeftMouse>', '<CR>', 'l' } do
    vim.cmd 'Neotree buffers focus'
    flush()
    local state = require('neo-tree.sources.manager').get_state 'buffers'
    require('neo-tree.ui.renderer').focus_node(state, api.nvim_buf_get_name(term.bufnr))
    eq(state.tree:get_node().extra.bufnr, term.bufnr, 'Select the terminal entry')
    local wins = vim.fn.win_findbuf(term.bufnr)
    local layout = vim.fn.winlayout()
    local mapping = vim.fn.maparg(key, 'n', false, true)
    assert(type(mapping.callback) == 'function', 'Missing tree handler: ' .. key)
    mapping.callback()
    flush()
    eq(api.nvim_get_current_win(), term.window, key .. ' must focus the existing terminal pane')
    eq(vim.fn.win_findbuf(term.bufnr), wins, key .. ' must not duplicate the terminal buffer')
    eq(vim.fn.winlayout(), layout, key .. ' must preserve the pane layout')
  end
  vim.cmd 'Neotree filesystem show'
  flush()
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
  assert(not term:is_open(), 'Toggle must hide an open terminal')

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
  task:open()
  flush()
  eq(task.bufnr, task_buf, 'Hidden task must retain its terminal buffer')
  assert(task:is_open(), 'Hidden task must reopen through its Terminal object')
  check_layout(task)
  task:shutdown()
  term:close()
  flush()

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

  -- Explorer state is per-tab, independent of other tabs.
  api.nvim_set_current_win(editor)
  term:open()
  flush()
  local tab1 = api.nvim_get_current_tabpage()
  vim.cmd 'tabnew'
  local tab2 = api.nvim_get_current_tabpage()
  api.nvim_set_current_buf(a)
  vim.cmd 'Neotree show'
  flush()
  local tab2_explorer = sidebar.explorer_win(tab2)
  assert(tab2_explorer, 'tab2 explorer must open independently')
  api.nvim_set_current_tabpage(tab1)
  check_layout(term)
  vim.cmd 'Neotree toggle'
  flush()
  assert(not sidebar.explorer_win(tab1), 'Explorer must close in tab1')
  eq(sidebar.explorer_win(tab2), tab2_explorer, 'Other tab explorer must survive toggle in tab1')
  vim.cmd 'Neotree show'
  flush()
  check_layout(term)
  vim.cmd 'tabclose'
  flush()
  eq(api.nvim_get_current_tabpage(), tab2, 'Closing a tab must retain the surviving tab')
  eq(sidebar.explorer_win(tab2), tab2_explorer, 'Surviving tab explorer window changed')

  term:shutdown()
  flush()
  eq(vim.o.showtabline, 0, 'Terminals/tabpages must not expose the horizontal tabline')

  for _, case in ipairs { 'quit', 'close-editor', 'layout', 'refresh', 'delete-terminal', 'delete-agent', 'last-terminal' } do
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
    if case == 'refresh' or case == 'delete-terminal' or case == 'delete-agent' or case == 'last-terminal' then
      assert((child.stdout or ''):find('case completed', 1, true), case .. ' exited before completing its checks')
    end
  end
  escape_case()
end

local function refresh_case()
  api.nvim_set_current_buf(file 'base-file')
  local editor = api.nvim_get_current_win()
  vim.cmd 'Neotree buffers show'
  flush()
  local state = require('neo-tree.sources.manager').get_state 'buffers'
  local function listed(buf)
    for _, node in pairs(state.tree.nodes.by_id) do
      if node.extra and node.extra.bufnr == buf then
        return true
      end
    end
    return false
  end
  api.nvim_set_current_win(editor)
  vim.cmd.edit(temp .. '/new-file')
  local buf = api.nvim_get_current_buf()
  flush()
  assert(listed(buf), 'New files must appear without manually refreshing the Open list')
  eq(state.tree:get_node().extra.bufnr, buf, 'Open list must follow the active file')
  api.nvim_buf_delete(buf, { force = true })
  flush()
  assert(not listed(buf), 'Deleted files must disappear without manually refreshing the Open list')
  local term = Terminal:new { cmd = 'cat', direction = 'horizontal' }
  term:open()
  flush()
  assert(listed(term.bufnr), 'New terminals must appear without manually refreshing the Open list')
  local terminal_buf = term.bufnr
  term:shutdown()
  flush()
  assert(not listed(terminal_buf), 'Deleted terminals must disappear from the Open list')
end

local function delete_terminal_case(last, agent)
  local kept = file 'kept-file'
  local editor = api.nvim_get_current_win()
  api.nvim_set_current_buf(kept)
  local other = Terminal:new { cmd = 'cat', direction = 'horizontal', hidden = true }
  other:open()
  if last then
    other:close()
  end
  local target_buf, target_job
  if agent then
    vim.cmd 'botright vnew'
    vim.b.agent_terminal = true
    target_buf = api.nvim_get_current_buf()
    target_job = vim.fn.jobstart({ 'cat' }, { term = true })
  else
    local target = Terminal:new { cmd = 'cat', direction = 'horizontal' }
    target:open()
    target_buf, target_job = target.bufnr, target.job_id
  end
  if last then
    -- Leave a hidden file and terminal, with only the target and tree visible.
    api.nvim_win_set_buf(editor, api.nvim_create_buf(false, true))
    api.nvim_win_close(editor, true)
  end
  vim.cmd 'Neotree buffers focus'
  flush()
  local explorer = api.nvim_get_current_win()
  local state = require('neo-tree.sources.manager').get_state 'buffers'
  require('neo-tree.ui.renderer').focus_node(state, api.nvim_buf_get_name(target_buf))
  eq(state.tree:get_node().extra.bufnr, target_buf, 'Select only the target terminal')
  vim.fn.maparg('<leader>bd', 'n', false, true).callback()
  flush()
  assert(api.nvim_win_is_valid(explorer), 'Deleting a terminal must preserve Neo-tree')
  assert(api.nvim_buf_is_valid(kept) and vim.bo[kept].buflisted, 'Deleting a terminal must preserve open files')
  assert(api.nvim_buf_is_valid(other.bufnr), 'Deleting a terminal must preserve other terminals')
  eq(vim.fn.jobwait({ other.job_id }, 0), { -1 }, 'Other terminal jobs must keep running')
  assert(not api.nvim_buf_is_valid(target_buf), 'Only the selected terminal buffer must be deleted')
  assert(vim.fn.jobwait({ target_job }, 0)[1] ~= -1, 'The selected terminal job must stop')
  if not last then
    eq(api.nvim_win_get_buf(editor), kept, 'The file pane must remain open')
    assert(other:is_open(), 'The other terminal pane must remain open')
  end
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

  -- ToggleTerm first, then the AI pane reopened by hand into a fresh split.
  api.nvim_win_close(ai.window, true)
  flush()
  vim.cmd(('vertical botright %dsplit'):format(math.floor(vim.o.columns * 0.35)))
  api.nvim_win_set_buf(0, ai.bufnr)
  sidebar.layout()
  flush()
  ai.window = api.nvim_get_current_win()
  eq(api.nvim_win_get_buf(ai.window), ai.bufnr, 'Reopened split must show the AI buffer')
  check_layout(term)
  check_ai({ ai }, term)
  stable()
  -- ToggleTerm reopened directly while the AI pane is visible.
  term:close()
  flush()
  term:open()
  flush()
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
      assert(not vim.bo[last].buflisted, 'Closed file must be unlisted')
      local wins = sidebar.editor_wins {}
      eq(#wins, 1, 'Closing the last file must leave an empty editor pane')
      eq(api.nvim_buf_get_name(api.nvim_win_get_buf(wins[1])), '', 'The pane left behind must be empty')
      -- Closing that empty pane is what quits.
      api.nvim_win_close(wins[1], false)
      flush()
      error 'Closing the empty editor pane did not quit Neovim'
    elseif case == 'close-editor' then
      -- Closing the last editor pane closes that file, not Neovim; the next
      -- file gets a fresh pane.
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
      assert(not vim.bo[first].buflisted, 'Closed file must be unlisted')
      local wins = sidebar.editor_wins {}
      eq(#wins, 1, 'A fresh editor pane must replace the closed one')
      local shown = api.nvim_win_get_buf(wins[1])
      assert(shown == kept or shown == dirty, 'Fresh pane must show a remaining file')
      check_layout()
      api.nvim_win_close(wins[1], false)
      flush()
      wins = sidebar.editor_wins {}
      eq(#wins, 1, 'Closing again must reopen the other file')
      -- The modified file is never dropped, so closing it just reshows it.
      eq(vim.bo[dirty].buflisted, true, 'Modified file must stay listed')
    elseif case == 'refresh' then
      refresh_case()
      io.stdout:write('case completed\n')
    elseif case == 'delete-terminal' or case == 'delete-agent' or case == 'last-terminal' then
      delete_terminal_case(case == 'last-terminal', case == 'delete-agent')
      io.stdout:write('case completed\n')
    elseif case == 'layout' then
      layout_case()
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
