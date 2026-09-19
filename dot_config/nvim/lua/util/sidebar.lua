-- Window-finding and layout helpers shared by the sidebar panels docked under
-- the explorer: util/bufferlist.lua (OPEN EDITORS) and util/shelllist.lua
-- (OPEN SHELLS). Also owns the right-hand AI column (agent_terminal buffers).
local M = {}

local SIDEBAR_FILETYPES = { ['neo-tree'] = true, bufferlist = true, shelllist = true }
local LISTS = { 'bufferlist', 'shelllist' }
local MIN_ROWS, MAX_ROWS = 2, 12

local function is_float(win)
  local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
  return not ok or cfg.relative ~= ''
end

-- Is this window one of the three sidebar panels (explorer, OPEN EDITORS,
-- OPEN SHELLS)? Used to auto-quit when a real editor window closes and only
-- the sidebar is left -- see config/autocmds.lua.
function M.is_sidebar_win(win)
  return SIDEBAR_FILETYPES[vim.bo[vim.api.nvim_win_get_buf(win)].filetype] == true
end

function M.is_ai_win(win)
  return not is_float(win) and vim.b[vim.api.nvim_win_get_buf(win)].agent_terminal == true
end

-- The docked, real (non-float) neo-tree window at the left edge -- as
-- opposed to a `position=float`/`position=current` instance.
function M.explorer_win(tab)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab or 0)) do
    if not is_float(w) then
      local _, col = unpack(vim.api.nvim_win_get_position(w))
      if col == 0 and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then
        return w
      end
    end
  end
end

local function list_wins(tab)
  local found = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if not is_float(w) then
      found[vim.bo[vim.api.nvim_win_get_buf(w)].filetype] = w
    end
  end
  local wins = {}
  for _, ft in ipairs(LISTS) do
    if found[ft] then
      wins[#wins + 1] = { ft = ft, win = found[ft] }
    end
  end
  return wins
end

-- Deferred window work belongs to the tab that requested it, even if the
-- user switches tabs before it runs. win_call restores the caller's focus.
function M.schedule(callback, tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  vim.schedule(function()
    if vim.api.nvim_tabpage_is_valid(tab) then
      vim.api.nvim_win_call(vim.api.nvim_tabpage_get_win(tab), callback)
    end
  end)
end

-- ── List sizing ──────────────────────────────────────────────────
-- Requested content rows per tab and list. Window heights are only ever an
-- output: a pass that runs while the layout is squeezed must not shrink what
-- the next, roomier pass restores.
local requested = {}
local pending = {}

local function winbar_rows(win)
  return vim.fn.getwininfo(win)[1].winbar
end

-- nvim_win_get_height counts the winbar row; content rows exclude it.
-- Separators sit outside every window, so summing heights conserves them.
local function apply_heights(tab)
  local explorer = M.explorer_win(tab)
  local lists = list_wins(tab)
  if not explorer or #lists == 0 then
    return
  end
  local want = requested[tab] or {}
  local column = { explorer }
  local total = vim.api.nvim_win_get_height(explorer)
  local targets = {}
  for i, item in ipairs(lists) do
    column[i + 1] = item.win
    total = total + vim.api.nvim_win_get_height(item.win)
    targets[i] = (want[item.ft] or MIN_ROWS) + winbar_rows(item.win)
  end
  local fixed = {}
  for _, item in ipairs(lists) do
    fixed[item.win] = vim.wo[item.win].winfixheight
    vim.wo[item.win].winfixheight = false
  end
  -- Top-down: each resize is absorbed by the window below it, so the last
  -- list receives exactly what is left once the others are sized.
  local rest = total
  for _, height in ipairs(targets) do
    rest = rest - height
  end
  local ok, err = pcall(function()
    vim.api.nvim_win_set_height(explorer, math.max(1, rest))
    for i = 1, #lists - 1 do
      vim.api.nvim_win_set_height(lists[i].win, targets[i])
    end
  end)
  for win, value in pairs(fixed) do
    vim.wo[win].winfixheight = value
  end
  if not ok then
    error(err, 0)
  end
end

function M.resize_panels(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  if pending[tab] then
    return
  end
  pending[tab] = true
  vim.schedule(function()
    pending[tab] = nil
    if not vim.api.nvim_tabpage_is_valid(tab) then
      requested[tab] = nil
      return
    end
    local ok, err = xpcall(apply_heights, debug.traceback, tab)
    if not ok then
      vim.notify('sidebar: list resize failed: ' .. err, vim.log.levels.ERROR)
    end
  end)
end

function M.request_rows(tab, ft, entries)
  requested[tab] = requested[tab] or {}
  requested[tab][ft] = math.max(MIN_ROWS, math.min(MAX_ROWS, entries))
  M.resize_panels(tab)
end

function M.resize_all()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    M.resize_panels(tab)
  end
end

-- ── Layout ───────────────────────────────────────────────────────
-- Target: explorer column full height at the left, AI terminals full height
-- at the right, editors and horizontal ToggleTerm in between.

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

-- Which windows may have their height/width restored without resizing the
-- whole screen: height needs a column ancestor, width a row ancestor.
local function resizable(node, in_row, in_col, out)
  if node[1] == 'leaf' then
    out[node[2]] = { width = in_row, height = in_col }
  else
    for _, child in ipairs(node[2]) do
      resizable(child, in_row or node[1] == 'row', in_col or node[1] == 'col', out)
    end
  end
  return out
end

local function expected_column(column)
  if #column == 1 then
    return { 'leaf', column[1] }
  end
  local nodes = {}
  for _, win in ipairs(column) do
    nodes[#nodes + 1] = { 'leaf', win }
  end
  return { 'col', nodes }
end

local function arranged(layout, column, ai)
  local children = layout[1] == 'row' and layout[2] or { layout }
  local first = 1
  if #column > 0 then
    if not vim.deep_equal(children[1], expected_column(column)) then
      return false
    end
    first = 2
  end
  local is_ai = {}
  for _, w in ipairs(ai) do
    is_ai[w] = true
  end
  local found = 0
  for i = #children, first, -1 do
    local wins = leaves(children[i], {})
    for _, w in ipairs(wins) do
      if not is_ai[w] then
        return found == #ai
      end
    end
    found = found + #wins
  end
  return found == #ai
end

local arranging = false

-- Keep one full-height column at each edge without recreating any window:
-- ToggleTerm and the agent terminals must keep owning their windows and jobs.
function M.layout()
  if arranging then
    return
  end
  local tab = vim.api.nvim_get_current_tabpage()
  local explorer = M.explorer_win(tab)
  local column = {}
  if explorer then
    column[1] = explorer
    for _, item in ipairs(list_wins(tab)) do
      column[#column + 1] = item.win
    end
  end
  local ai, content = {}, {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if not is_float(win) and not M.is_sidebar_win(win) then
      content[#content + 1] = win
      if M.is_ai_win(win) then
        ai[#ai + 1] = win
      end
    end
  end
  if #column == 0 and #ai == 0 then
    return
  end
  if arranged(vim.fn.winlayout(), column, ai) then
    return
  end

  local focus = vim.api.nvim_get_current_win()
  local width = explorer and vim.api.nvim_win_get_width(explorer)
  local sizes, pos = {}, {}
  for _, win in ipairs(content) do
    sizes[win] = { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win) }
    pos[win] = vim.api.nvim_win_get_position(win)
  end
  table.sort(ai, function(a, b)
    if pos[a][2] ~= pos[b][2] then
      return pos[a][2] < pos[b][2]
    end
    return pos[a][1] < pos[b][1]
  end)
  local equalalways = vim.o.equalalways
  local eventignore = vim.o.eventignore
  arranging = true
  vim.o.equalalways = false
  -- These are temporary focus changes, not user navigation. Neo-tree and
  -- ToggleTerm otherwise schedule focus/mode work for the intermediate panes.
  vim.o.eventignore = 'all'
  local ok, err = pcall(function()
    if explorer then
      vim.api.nvim_set_current_win(explorer)
      vim.cmd 'noautocmd wincmd H'
      for i = 2, #column do
        assert(vim.fn.win_splitmove(column[i], column[i - 1], { vertical = false, rightbelow = true }) == 0)
      end
    end
    for i, win in ipairs(ai) do
      if i == 1 then
        vim.api.nvim_set_current_win(win)
        vim.cmd 'noautocmd wincmd L'
      else
        local prev = ai[i - 1]
        local side_by_side = pos[win][2] ~= pos[prev][2]
        assert(vim.fn.win_splitmove(win, prev, { vertical = side_by_side, rightbelow = true }) == 0)
      end
    end
    -- Re-enabling equalalways itself equalizes windows. Restore it before
    -- restoring dimensions: middle windows first, then the edge columns.
    vim.o.equalalways = equalalways
    local can = resizable(vim.fn.winlayout(), false, false, {})
    for _, win in ipairs(content) do
      if can[win].height and not M.is_ai_win(win) then
        vim.api.nvim_win_set_height(win, sizes[win][2])
      end
      if can[win].width and not M.is_ai_win(win) then
        vim.api.nvim_win_set_width(win, sizes[win][1])
      end
    end
    if explorer then
      vim.api.nvim_win_set_width(explorer, width)
    end
    for _, win in ipairs(ai) do
      vim.api.nvim_win_set_width(win, sizes[win][1])
    end
    -- Stacked AI panes were squeezed by whatever spanned beneath them, so
    -- restore their split ratio rather than their absolute heights.
    local stacks = {}
    for _, win in ipairs(ai) do
      local col = pos[win][2]
      stacks[col] = stacks[col] or {}
      table.insert(stacks[col], win)
    end
    for _, stack in pairs(stacks) do
      local before, after = 0, 0
      for _, win in ipairs(stack) do
        before = before + sizes[win][2]
        after = after + vim.api.nvim_win_get_height(win)
      end
      for i = 1, #stack - 1 do
        vim.api.nvim_win_set_height(stack[i], math.floor(sizes[stack[i]][2] * after / before + 0.5))
      end
    end
  end)
  if vim.api.nvim_win_is_valid(focus) then
    vim.api.nvim_set_current_win(focus)
  end
  vim.o.equalalways = equalalways
  vim.o.eventignore = eventignore
  arranging = false
  if not ok then
    error(err)
  end
  M.resize_panels(tab)
end

-- Real editor windows: not the explorer, not any window id in `exclude`,
-- not a terminal/quickfix/nofile split (aerial, trouble, toggleterm all use
-- buftype ~= '').
function M.editor_wins(exclude)
  local skip = {}
  for _, w in ipairs(exclude or {}) do
    skip[w] = true
  end
  local wins = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not skip[w] then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].buftype == '' and vim.bo[b].filetype ~= 'neo-tree' then
        wins[#wins + 1] = w
      end
    end
  end
  return wins
end

return M
