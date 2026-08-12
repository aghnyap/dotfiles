-- ╭──────────────────────────────────────────────────────────────╮
-- │  Cursor-style inline edit (Cmd+K)                            │
-- │                                                              │
-- │  Cmd+K used to be `ClaudeCodeSend` + `ClaudeCodeFocus`: the   │
-- │  selection went over, then you were dropped into the Claude   │
-- │  terminal to type. That is two context switches for what is   │
-- │  one thought, and it leaves the editor.                       │
-- │                                                              │
-- │  This keeps you in the buffer: the selection is sent, you are │
-- │  asked for the instruction in a float, and the answer comes   │
-- │  back as an inline diff over the selection (diff_opts.layout  │
-- │  = 'unified' in plugins/ai.lua). Accept with <leader>ay,      │
-- │  reject with <leader>an, exactly as before.                    │
-- │                                                              │
-- │  Ordering matters and is the whole trick: `ClaudeCodeSend`     │
-- │  reads the CURRENT visual selection, so it has to run while   │
-- │  the selection is still live -- i.e. synchronously, before    │
-- │  vim.ui.input yields. Prompting first would lose it.          │
-- │                                                              │
-- │  Relies on `focus_after_send = false` (the plugin default):   │
-- │  the send must not steal focus, or the prompt would open over │
-- │  the terminal instead of the editor.                          │
-- ╰──────────────────────────────────────────────────────────────╯
local M = {}

--- Is the Claude websocket actually up? Sending into a dead server silently
--- does nothing, which is a miserable thing to debug from a keypress.
local function connected()
  local ok, claudecode = pcall(require, 'claudecode')
  if not ok then
    return false, 'claudecode.nvim is not loaded'
  end
  if not (claudecode.state and claudecode.state.server) then
    return false, 'Claude is not running — start it with <leader>ac (Cmd+L)'
  end
  return true
end

--- Ask for an instruction and submit it. `ctx` is only used for the prompt
--- label, so the float says what Claude is about to act on.
local function prompt_and_send(ctx)
  vim.ui.input({ prompt = ('Claude edit (%s): '):format(ctx) }, function(instruction)
    if not instruction or vim.trim(instruction) == '' then
      -- Cancelled. The selection has already been sent as context, which is
      -- harmless -- it just sits in the conversation unused.
      return
    end
    -- ClaudeCodeSendText submits by default; the ! variant would only insert.
    vim.cmd('ClaudeCodeSendText ' .. instruction)
  end)
end

--- Visual mode: send the selection, then ask what to do with it.
function M.selection()
  local ok, err = connected()
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  -- Synchronous, while the selection is still live.
  vim.cmd 'ClaudeCodeSend'
  prompt_and_send 'selection'
end

--- Normal mode: no selection to act on, so scope it to this file.
function M.buffer()
  local ok, err = connected()
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    vim.notify('Claude edit: this buffer has no file', vim.log.levels.WARN)
    return
  end
  vim.cmd 'ClaudeCodeAdd %'
  prompt_and_send(vim.fn.fnamemodify(name, ':t'))
end

return M
