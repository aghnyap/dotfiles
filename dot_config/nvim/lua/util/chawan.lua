-- Open URLs and paths in chawan (`cha`), never macOS `open` (Chrome/Arc).
--
-- vim.ui.open on Darwin is hardcoded to `open`, which ignores $BROWSER. gx,
-- :Open, Snacks.gitbrowse, markdown-preview, and <leader>Cb all go through
-- that, so the wrap has to live here.

local M = {}

local function cha_path()
  local cha = vim.fn.exepath 'cha'
  if cha ~= '' then
    return cha
  end
  local brew = '/opt/homebrew/bin/cha'
  if vim.uv.fs_stat(brew) then
    return brew
  end
  return nil
end

function M.open(path)
  local cha = cha_path()
  if not cha then
    return nil, 'cha (chawan) not on PATH'
  end
  if vim.env.TMUX and vim.env.TMUX ~= '' then
    return vim.system({ 'tmux', 'new-window', '-n', 'cha', cha, path }, { detach = true }), nil
  end
  vim.cmd 'botright 20split'
  vim.fn.termopen { cha, path }
  vim.cmd 'startinsert'
  return nil, nil
end

function M.setup()
  vim.env.BROWSER = 'cha'
  vim.g.netrw_browsex_viewer = 'cha'
  vim.cmd [[
    function! OpenMarkdownPreview(url)
      call luaeval('require("util.chawan").open(_A)', a:url)
    endfunction
  ]]
  vim.g.mkdp_browserfunc = 'OpenMarkdownPreview'

  local orig = vim.ui.open
  vim.ui.open = function(path, opt)
    opt = opt or {}
    if opt.cmd then
      return orig(path, opt)
    end
    return M.open(path)
  end
end

return M
