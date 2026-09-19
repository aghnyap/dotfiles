-- Window-finding helpers shared by the sidebar panels docked under the
-- explorer: util/bufferlist.lua (OPEN EDITORS) and util/shelllist.lua
-- (OPEN SHELLS).
local M = {}

local SIDEBAR_FILETYPES = { ['neo-tree'] = true, bufferlist = true, shelllist = true }

-- Is this window one of the three sidebar panels (explorer, OPEN EDITORS,
-- OPEN SHELLS)? Used to auto-quit when a real editor window closes and only
-- the sidebar is left -- see config/autocmds.lua.
function M.is_sidebar_win(win)
  return SIDEBAR_FILETYPES[vim.bo[vim.api.nvim_win_get_buf(win)].filetype] == true
end

-- The docked, real (non-float) neo-tree window at the left edge -- as
-- opposed to a `position=float`/`position=current` instance.
function M.explorer_win(tab)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab or 0)) do
    local ok, cfg = pcall(vim.api.nvim_win_get_config, w)
    if ok and cfg.relative == '' then
      local _, col = unpack(vim.api.nvim_win_get_position(w))
      if col == 0 and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then
        return w
      end
    end
  end
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

local arranging = false

-- Resizing a middle/bottom split alone gives its spare space to its nearest
-- neighbour. Give that space to Explorer first, then restore both list sizes.
local function panel_heights(explorer, heights)
  local height = vim.api.nvim_win_get_height(explorer)
  for win, wanted in pairs(heights) do
    height = height + vim.api.nvim_win_get_height(win) - wanted
  end
  vim.api.nvim_win_set_height(explorer, math.max(1, height))
  for win, wanted in pairs(heights) do
    vim.api.nvim_win_set_height(win, wanted)
  end
end

function M.set_panel_height(win, height)
  local tab = vim.api.nvim_win_get_tabpage(win)
  local explorer = M.explorer_win(tab)
  if not explorer then
    return
  end
  local heights = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if w ~= explorer and M.is_sidebar_win(w) and vim.api.nvim_win_get_config(w).relative == '' then
      heights[w] = w == win and height or vim.api.nvim_win_get_height(w)
    end
  end
  panel_heights(explorer, heights)
end

-- Keep one full-height left column without recreating any windows (in
-- particular, ToggleTerm must keep owning the same terminal window).
function M.layout()
  if arranging then
    return
  end
  local explorer = M.explorer_win()
  if not explorer then
    return
  end
  local panels = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      panels[vim.bo[vim.api.nvim_win_get_buf(win)].filetype] = win
    end
  end
  local column = { explorer }
  for _, ft in ipairs { 'bufferlist', 'shelllist' } do
    if panels[ft] then
      column[#column + 1] = panels[ft]
    end
  end
  local expected = #column == 1 and { 'leaf', explorer } or { 'col', {} }
  if #column > 1 then
    for _, win in ipairs(column) do
      table.insert(expected[2], { 'leaf', win })
    end
  end
  local layout = vim.fn.winlayout()
  if vim.deep_equal(layout[1] == 'row' and layout[2][1] or layout, expected) then
    return
  end

  local focus = vim.api.nvim_get_current_win()
  local width = vim.api.nvim_win_get_width(explorer)
  local heights = {}
  local content_heights = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == '' and not M.is_sidebar_win(win) then
      content_heights[win] = vim.api.nvim_win_get_height(win)
    end
  end
  for i = 2, #column do
    heights[column[i]] = vim.api.nvim_win_get_height(column[i])
  end
  local equalalways = vim.o.equalalways
  local eventignore = vim.o.eventignore
  arranging = true
  vim.o.equalalways = false
  -- These are temporary focus changes, not user navigation. Neo-tree and
  -- ToggleTerm otherwise schedule focus/mode work for the intermediate panes.
  vim.o.eventignore = 'all'
  local ok, err = pcall(function()
    vim.api.nvim_set_current_win(explorer)
    vim.cmd 'noautocmd wincmd H'
    for i = 2, #column do
      assert(vim.fn.win_splitmove(column[i], column[i - 1], { vertical = false, rightbelow = true }) == 0)
    end
    -- Re-enabling equalalways itself equalizes windows. Restore it before
    -- restoring dimensions, including the editor/terminal split heights.
    vim.o.equalalways = equalalways
    vim.api.nvim_win_set_width(explorer, width)
    for win, height in pairs(content_heights) do
      vim.api.nvim_win_set_height(win, height)
    end
    panel_heights(explorer, heights)
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
