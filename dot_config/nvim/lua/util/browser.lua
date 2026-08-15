-- Open URLs and paths in Google Chrome, never macOS's OS-level default
-- browser (this repo doesn't manage that setting) and never chawan.
--
-- vim.ui.open on Darwin is hardcoded to `open`, which ignores $BROWSER. gx,
-- :Open, Snacks.gitbrowse, markdown-preview, and <leader>Cb all go through
-- that, so the wrap has to live here.

local M = {}

function M.open(path)
  return vim.system({ 'open', '-a', 'Google Chrome', path }, { detach = true }), nil
end

function M.setup()
  vim.env.BROWSER = 'chrome-open'
  vim.g.netrw_browsex_viewer = 'chrome-open'
  vim.cmd [[
    function! OpenMarkdownPreview(url)
      call luaeval('require("util.browser").open(_A)', a:url)
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
