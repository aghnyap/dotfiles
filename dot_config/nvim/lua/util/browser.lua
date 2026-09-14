-- Open URLs and paths in terminal-browser, never macOS's OS-level default
-- browser (this repo doesn't manage that setting).
--
-- vim.ui.open on Darwin is hardcoded to `open`, which ignores $BROWSER. gx,
-- :Open, Snacks.gitbrowse, markdown-preview, and <leader>Cb all go through
-- that, so the wrap has to live here.
--
-- terminal-browser needs a real terminal to draw into (Kitty graphics
-- protocol), unlike Arc before it, which `open -a` could hand a URL to from
-- anywhere. So this shells out to terminal-browser-open
-- (dot_local/bin/executable_terminal-browser-open) instead of `open` --
-- the SAME script the shell's own $BROWSER uses, not term-tab directly, so
-- the macOS/SSH/Linux fallback logic (new Ghostty tab vs. the current
-- terminal) lives in exactly one place rather than being duplicated here
-- and drifting from it.

local M = {}

function M.open(path)
  return vim.system({ 'terminal-browser-open', path }, { detach = true }), nil
end

function M.setup()
  vim.env.BROWSER = 'terminal-browser-open'
  vim.g.netrw_browsex_viewer = 'terminal-browser-open'
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
