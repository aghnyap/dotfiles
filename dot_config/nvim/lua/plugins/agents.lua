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
-- Its own terminal, separate from the plugin's, because watch-files mode is a
-- different way of working rather than a toggle within the same session.
local function aider_watch()
  if vim.fn.executable('aider') == 0 then
    vim.notify('aider is not installed -- see run_onchange_before_install-packages.sh', vim.log.levels.ERROR, { title = 'agents' })
    return
  end
  local cwd = vim.fs.root(0, '.git') or vim.uv.cwd()
  local ai_model = require 'util.ai_model'
  ai_model.with_ready_model(function()
    local cmd = ('aider --watch-files --model %s'):format(vim.fn.shellescape(ai_model.aider_model()))
    Snacks.terminal.toggle(cmd, {
      cwd = cwd,
      win = { position = 'right', width = 0.35 },
    })
  end)
end

local function with_aider(callback, allow_start)
  if vim.fn.executable('aider') == 0 then
    vim.notify('aider is not installed -- see run_onchange_before_install-packages.sh', vim.log.levels.ERROR, { title = 'agents' })
    return
  end

  local ai_model = require 'util.ai_model'
  if ai_model.aider_running() then
    callback(require 'nvim_aider.api')
    return
  end
  if not allow_start then
    vim.notify('Open an Aider terminal first with <leader>Aa.', vim.log.levels.INFO, { title = 'agents' })
    return
  end

  ai_model.with_ready_model(function()
    callback(require 'nvim_aider.api')
  end)
end

local function current_path()
  local path = vim.api.nvim_buf_get_name(0)
  return path ~= '' and vim.fn.fnamemodify(path, ':p') or nil
end

local function aider_file(action)
  local path = current_path()
  if not path then
    vim.notify('No valid file in current buffer', vim.log.levels.INFO, { title = 'agents' })
    return
  end

  with_aider(function(api)
    if action == 'add' then
      api.add_file(path)
    elseif action == 'drop' then
      api.drop_file(path)
    else
      api.send_command('/read-only', path)
    end
  end)
end

-- The readiness check is asynchronous, so capture a visual selection before
-- the picker or `ollama show` changes mode. Re-selecting with `gv` would work
-- for Avante, but aider accepts the text directly and needs no mode restoration.
local function aider_send()
  local mode = vim.fn.mode()
  local content
  local subject = 'buffer'
  if vim.tbl_contains({ 'v', 'V', '\22' }, mode) then
    content = table.concat(vim.fn.getregion(vim.fn.getpos 'v', vim.fn.getpos '.', { type = mode }), '\n')
    subject = 'selection'
  else
    content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  end

  with_aider(function(api)
    vim.ui.input({ prompt = ('Add a prompt to your %s (empty to skip):'):format(subject) }, function(input)
      if input ~= nil then
        api.send_to_terminal(input ~= '' and (content .. '\n> ' .. input) or content)
      end
    end)
  end)
end

return {
  {
    'GeorgesAlkhouri/nvim-aider',
    dependencies = { 'folke/snacks.nvim' },
    -- The two plugins with more stars are both dead: joshuavial/aider.nvim is
    -- GitHub-archived with "No longer maintained" as its first README line
    -- despite 558 stars, and aweis89/aider.nvim is deprecated by its own author
    -- in favour of a non-aider-specific successor. This one is the maintained
    -- choice, not the popular one.
    opts = function()
      local ai_model = require 'util.ai_model'

      -- Defaults are --no-auto-commits --pretty --stream. The first matters and
      -- is kept: aider commits every edit otherwise, and ~/.aider.conf.yml sets
      -- auto-commits: false for the same reason outside Neovim.
      return {
        args = ai_model.aider_args(),
        -- aider edits files on disk, so without this the buffer keeps showing the
        -- old contents until something forces a re-read. Needs 'autoread', which
        -- LazyVim sets.
        auto_reload = true,
        win = { position = 'right', wo = { winbar = 'Aider' } },
      }
    end,
    keys = {
      {
        '<leader>Aa',
        function()
          with_aider(function(api)
            api.toggle_terminal()
          end, true)
        end,
        desc = 'aider (local): toggle',
      },
      {
        '<leader>Ao',
        function()
          with_aider(function(api)
            api.toggle_terminal { win = { position = 'float' } }
          end, true)
        end,
        desc = 'aider (local): toggle float',
      },
      {
        '<leader>Am',
        function()
          with_aider(function(api)
            api.open_command_picker()
          end)
        end,
        desc = 'aider (local): command menu',
      },
      {
        '<leader>Ab',
        function()
          aider_file 'add'
        end,
        desc = 'aider (local): add buffer',
      },
      {
        '<leader>AO',
        function()
          aider_file 'read-only'
        end,
        desc = 'aider (local): add buffer read-only',
      },
      {
        '<leader>Ad',
        function()
          aider_file 'drop'
        end,
        desc = 'aider (local): drop buffer',
      },
      {
        '<leader>As',
        aider_send,
        mode = { 'n', 'v' },
        desc = 'aider (local): send selection/buffer',
      },
      {
        '<leader>AR',
        function()
          with_aider(function(api)
            api.reset_session()
          end)
        end,
        desc = 'aider (local): reset session',
      },
      {
        '<leader>AH',
        function()
          require('nvim_aider.api').health_check()
        end,
        desc = 'aider: health check',
      },
      { '<leader>Aw', aider_watch, desc = 'aider (local): watch-files mode (AI! comments)' },
    },
  },

  {
    'folke/snacks.nvim',
    keys = {
      { '<leader>Ac', function() cursor_agent() end, desc = 'cursor-agent (cloud): toggle' },
      { '<leader>Ar', function() cursor_agent('--resume') end, desc = 'cursor-agent (cloud): resume' },
    },
  },

  -- Group label only -- `opts` is merged by LazyVim, no `config`, so nothing
  -- else is clobbered.
  {
    'folke/which-key.nvim',
    opts = {
      spec = {
        { '<leader>A', group = 'agents (local / cloud)', mode = { 'n', 'v' } },
        { '<leader>av', group = 'avante', mode = 'n' },
      },
    },
  },
}
