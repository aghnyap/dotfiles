-- ╭──────────────────────────────────────────────────────────────╮
-- │  Terminal AI agents: aider and cursor-agent                  │
-- │                                                              │
-- │  Both drive a CLI in a terminal split. That is a different    │
-- │  thing from ai.lua, where claudecode.nvim makes Neovim the    │
-- │  editor Claude Code drives -- it sees the buffer, resolves    │
-- │  @-mentions against real files and returns native diffs.      │
-- │  These two edit files on disk and you reload.                 │
-- ╰──────────────────────────────────────────────────────────────╯
--
-- <leader>A, not <leader>a. The AI group already holds 13 Claude bindings and
-- the good mnemonics there are gone; a separate group also keeps Claude's
-- muscle memory untouched. Capital prefixes are how this config groups a
-- toolchain -- <leader>X Xcode, <leader>F Flutter, <leader>C c4.

-- Cursor's agent has no plugin worth installing. The candidates are all
-- single-author weekend projects -- the biggest is 57 stars with one commit and
-- nothing since -- and every one of them is a floating terminal wrapping the
-- same binary. snacks.nvim, which claudecode.nvim already uses as its terminal
-- provider, does that natively.
--
-- Deliberately not toggleterm: lua/plugins/tasks.lua owns toggleterm's single
-- `config`, and lazy.nvim keeps exactly one per plugin across all spec files.
local function cursor_agent(extra)
  if vim.fn.executable('cursor-agent') == 0 then
    vim.notify('cursor-agent is not installed -- brew install --cask cursor-cli', vim.log.levels.ERROR, { title = 'agents' })
    return
  end
  local cmd = 'cursor-agent' .. (extra and (' ' .. extra) or '')
  Snacks.terminal.toggle(cmd, {
    cwd = vim.fs.root(0, '.git') or vim.uv.cwd(),
    win = { position = 'right', width = 0.35 },
  })
end

-- aider --watch-files is the upstream editor-integration story and it needs no
-- plugin at all: it watches files on disk for one-line `AI!` / `AI?` comments
-- and acts when you save. That works in any editor, which is the point. The
-- plugin below is convenience on top -- add/drop files, send a selection --
-- not capability aider lacks.
--
-- Its own terminal, separate from the plugin's, because the plugin's args are
-- fixed at setup time and this mode is a different way of working rather than
-- a toggle within the same session.
local function aider_watch()
  if vim.fn.executable('aider') == 0 then
    vim.notify('aider is not installed -- see run_onchange_before_install-packages.sh', vim.log.levels.ERROR, { title = 'agents' })
    return
  end
  Snacks.terminal.toggle('aider --watch-files', {
    cwd = vim.fs.root(0, '.git') or vim.uv.cwd(),
    win = { position = 'right', width = 0.35 },
  })
end

return {
  {
    'GeorgesAlkhouri/nvim-aider',
    cmd = 'Aider',
    dependencies = { 'folke/snacks.nvim' },
    -- The two plugins with more stars are both dead: joshuavial/aider.nvim is
    -- GitHub-archived with "No longer maintained" as its first README line
    -- despite 558 stars, and aweis89/aider.nvim is deprecated by its own author
    -- in favour of a non-aider-specific successor. This one is the maintained
    -- choice, not the popular one.
    opts = {
      -- Defaults are --no-auto-commits --pretty --stream. The first matters and
      -- is kept: aider commits every edit otherwise, and ~/.aider.conf.yml sets
      -- auto-commits: false for the same reason outside Neovim.
      args = { '--no-auto-commits', '--pretty', '--stream' },
      -- aider edits files on disk, so without this the buffer keeps showing the
      -- old contents until something forces a re-read. Needs 'autoread', which
      -- LazyVim sets.
      auto_reload = true,
      win = { position = 'right', wo = { winbar = 'Aider' } },
    },
    keys = {
      { '<leader>Aa', '<cmd>Aider toggle<cr>', desc = 'aider: toggle' },
      { '<leader>Am', '<cmd>Aider command<cr>', desc = 'aider: command menu' },
      { '<leader>Ab', '<cmd>Aider add<cr>', desc = 'aider: add buffer' },
      { '<leader>Ad', '<cmd>Aider drop<cr>', desc = 'aider: drop buffer' },
      { '<leader>As', '<cmd>Aider send<cr>', mode = { 'n', 'v' }, desc = 'aider: send selection/buffer' },
      { '<leader>AR', '<cmd>Aider reset<cr>', desc = 'aider: reset session' },
      { '<leader>AH', '<cmd>Aider health<cr>', desc = 'aider: health check' },
      { '<leader>Aw', aider_watch, desc = 'aider: watch-files mode (AI! comments)' },
    },
  },

  {
    'folke/snacks.nvim',
    keys = {
      { '<leader>Ac', function() cursor_agent() end, desc = 'cursor-agent: toggle' },
      { '<leader>Ar', function() cursor_agent('--resume') end, desc = 'cursor-agent: resume' },
    },
  },

  -- Group label only -- `opts` is merged by LazyVim, no `config`, so nothing
  -- else is clobbered.
  {
    'folke/which-key.nvim',
    opts = {
      spec = {
        { '<leader>A', group = 'agents', mode = { 'n', 'v' } },
      },
    },
  },
}
