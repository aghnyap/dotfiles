-- Open URLs and paths in chawan (`cha`) in a Ghostty tab, never macOS `open`
-- (Chrome/Arc) and never a new Ghostty window.
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

local function term_tab_path()
  local bin = vim.fn.exepath 'term-tab'
  if bin ~= '' then
    return bin
  end
  local home = vim.uv.os_homedir() .. '/.local/bin/term-tab'
  if vim.uv.fs_stat(home) then
    return home
  end
  return nil
end

function M.open(path)
  local cha = cha_path()
  if not cha then
    return nil, 'cha (chawan) not on PATH'
  end
  local term_tab = term_tab_path()
  if term_tab then
    return vim.system({ term_tab, cha, path }, { detach = true }), nil
  end
  vim.cmd 'botright 20split'
  vim.fn.termopen { cha, path }
  vim.cmd 'startinsert'
  return nil, nil
end

function M.setup()
  vim.env.BROWSER = 'cha-tab'
  vim.g.netrw_browsex_viewer = 'cha-tab'
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
