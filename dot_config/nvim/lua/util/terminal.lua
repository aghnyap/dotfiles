local M = {}

-- Delete the job and its pane together. Buffer-only deletion can leave a
-- file or a new [No Name] buffer occupying the terminal's split.
function M.delete(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= 'terminal' then
    return
  end
  local ok, terminal = pcall(require, 'toggleterm.terminal')
  local term = ok and terminal.find(function(t)
    return t.bufnr == buf
  end)
  if term then
    term:shutdown()
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_close(win, true)
  end
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.fn.jobstop, vim.bo[buf].channel)
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

return M
