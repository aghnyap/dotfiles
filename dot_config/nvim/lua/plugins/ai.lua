-- ╭──────────────────────────────────────────────────────────────╮
-- │  Claude as the native AI layer                               │
-- │                                                              │
-- │  claudecode.nvim implements the same WebSocket/MCP protocol   │
-- │  the official Claude extension speaks inside VS Code and      │
-- │  Cursor, in pure Lua. Neovim becomes the editor Claude Code   │
-- │  drives: it sees your active buffer and selection, @-mentions  │
-- │  resolve against your files, and proposed edits arrive as      │
-- │  real Neovim diffs you accept or reject.                       │
-- ╰──────────────────────────────────────────────────────────────╯
return {
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    event = 'VeryLazy',
    opts = {
      auto_start = true,
      log_level = 'warn',
      -- nil = use the `claude` binary from $PATH
      terminal_cmd = nil,
      terminal = {
        provider = 'snacks',
        split_side = 'right',
        split_width_percentage = 0.35,
        auto_close = false,
      },
      -- Cursor shows an edit inline, over the selection, rather than in a side
      -- pane. 'unified' is claudecode's equivalent -- diff.lua:842 dispatches
      -- to the inline handler on exactly that value.
      --
      -- The keys here used to be vertical_split / open_in_current_tab /
      -- auto_close_on_accept. Those still parse, but they are legacy aliases
      -- and config.lua:220 maps them with LEGACY TAKING PRECEDENCE:
      --     if type(d.vertical_split) == 'boolean' then d.layout = ... end
      -- so leaving vertical_split in place would silently pin layout back to
      -- 'vertical' and this setting would do nothing at all. Dropping it is
      -- what makes the inline diff reachable. auto_close_on_accept is
      -- validated by the plugin but read nowhere in it -- a dead option.
      diff_opts = {
        layout = 'unified',
        open_in_new_tab = false,
        keep_terminal_focus = false,
        on_new_file_reject = 'close_window',
        auto_resize_terminal = true,
      },
    },
    keys = {
      -- ── Cursor's AI chords ──────────────────────────────────────
      -- Cmd+L: open / close the Claude panel
      { '<D-l>', '<cmd>ClaudeCode<cr>', mode = { 'n', 'i', 'v', 't' }, desc = 'Claude: toggle panel' },
      -- Cmd+Shift+L: add the selection to the conversation
      { '<D-S-l>', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Claude: add selection to chat' },
      {
        '<D-S-l>',
        '<cmd>ClaudeCodeAdd %<cr>',
        mode = { 'n', 'i' },
        desc = 'Claude: add this file to chat',
      },
      -- Cmd+K: Cursor's inline edit. Prompts in a float and returns the answer
      -- as an inline diff over the selection, instead of dropping you into the
      -- Claude terminal to type. See lua/util/claude_edit.lua.
      {
        '<D-k>',
        function()
          require('util.claude_edit').selection()
        end,
        mode = 'v',
        desc = 'Claude: edit selection inline',
      },
      {
        '<D-k>',
        function()
          require('util.claude_edit').buffer()
        end,
        mode = 'n',
        desc = 'Claude: edit this file inline',
      },
      {
        '<D-k>',
        function()
          -- Leave insert first: the prompt is a float, and typing into it
          -- while the buffer is still in insert mode puts the text in the
          -- wrong place.
          vim.cmd 'stopinsert'
          require('util.claude_edit').buffer()
        end,
        mode = 'i',
        desc = 'Claude: edit this file inline',
      },
      -- The old behaviour, kept: jump into the Claude terminal to type freely.
      { '<leader>ak', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude prompt' },
      {
        '<leader>ae',
        function()
          require('util.claude_edit').selection()
        end,
        mode = 'v',
        desc = 'Edit selection inline',
      },

      -- ── Leader equivalents, usable over SSH or in another terminal ──
      { '<leader>ac', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
      { '<leader>af', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
      { '<leader>ar', '<cmd>ClaudeCode --resume<cr>', desc = 'Resume Claude session' },
      { '<leader>aC', '<cmd>ClaudeCode --continue<cr>', desc = 'Continue last conversation' },
      { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send selection to Claude' },
      { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', desc = 'Add current buffer to Claude' },
      { '<leader>am', '<cmd>ClaudeCodeSelectModel<cr>', desc = 'Select Claude model' },
      { '<leader>at', '<cmd>ClaudeCodeStatus<cr>', desc = 'Claude connection status' },
      -- Accept or reject a diff Claude proposes
      { '<leader>ay', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept Claude diff' },
      { '<leader>an', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Reject Claude diff' },
    },
  },
}
