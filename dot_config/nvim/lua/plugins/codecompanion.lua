-- ╭──────────────────────────────────────────────────────────────╮
-- │  codecompanion.nvim -- local + aggregated AI, replacing Avante │
-- │                                                                │
-- │  Two adapters, both non-cloud from Neovim's point of view:     │
-- │   - ollama:   the same local model :AiModel already selects    │
-- │               for aider (util/ai_model.lua is the shared       │
-- │               source of truth for which model and context).    │
-- │   - litellm:  LiteLLM's own OpenAI-compatible proxy, so any     │
-- │               model IT aggregates (local GGUFs, Claude, OpenAI) │
-- │               is reachable without a second plugin. litellm     │
-- │               itself is a `uv tool` (see the installer script), │
-- │               started by hand: `litellm --config <file>`.       │
-- ╰──────────────────────────────────────────────────────────────╯
local ai_model = require 'util.ai_model'

-- LiteLLM's proxy needs a running server on this port to answer at all;
-- unlike ollama there is no managed brew-services unit for it, so this is
-- just where it is expected if you have started one.
local LITELLM_URL = 'http://127.0.0.1:4000'

return {
  {
    'olimorris/codecompanion.nvim',
    event = 'VeryLazy',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    opts = function()
      return {
        adapters = {
          ollama = function()
            local model = ai_model.current()
            return require('codecompanion.adapters').extend('ollama', {
              env = { url = 'http://127.0.0.1:11434' },
              schema = {
                model = { default = model },
                num_ctx = { default = model and ai_model.context(model) or nil },
              },
            })
          end,
          -- 'openai_compatible' is codecompanion's built-in template for any
          -- OpenAI-shaped endpoint that isn't OpenAI itself -- exactly what
          -- LiteLLM's proxy exposes. No API key is required by a local
          -- LiteLLM instance with no auth configured; the field still has
          -- to be present or the adapter refuses to build the request.
          litellm = function()
            return require('codecompanion.adapters').extend('openai_compatible', {
              env = {
                url = LITELLM_URL,
                api_key = os.getenv 'LITELLM_API_KEY' or 'sk-local',
              },
            })
          end,
        },
        strategies = {
          chat = { adapter = 'ollama' },
          inline = { adapter = 'ollama' },
          -- codecompanion's agentic tool-calling mode: point it at LiteLLM
          -- by default so it can reach a stronger model when one is
          -- configured there, without editing this file per session.
          agent = { adapter = 'litellm' },
        },
        display = {
          chat = {
            window = { layout = 'vertical', width = 0.4 },
          },
        },
      }
    end,
    keys = {
      -- A Neovim session starts without a local model selected; require one
      -- before opening the chat, same guard avante.lua used.
      {
        '<leader>aa',
        function()
          ai_model.with_ready_model(function()
            vim.cmd 'CodeCompanionChat Toggle'
          end)
        end,
        mode = { 'n', 'v' },
        desc = 'CodeCompanion: toggle chat',
      },
      {
        '<leader>ai',
        function()
          ai_model.with_ready_model(function()
            vim.cmd 'CodeCompanion'
          end)
        end,
        mode = { 'n', 'v' },
        desc = 'CodeCompanion: inline prompt',
      },
      { '<leader>ax', '<cmd>CodeCompanionActions<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion: actions menu' },
      -- The shared :AiModel picker (util/ai_model.lua), not codecompanion's
      -- own `/model` slash command: that only switches which configured
      -- ADAPTER answers (ollama vs. litellm), not which model inside
      -- ollama, and would leave aider's args and the readiness check
      -- out of sync with whatever codecompanion picked. Avante used to
      -- leave this lhs to the shared selector for the same reason.
      { '<leader>aM', '<cmd>AiModel<cr>', desc = 'Select local AI model (shared with aider)' },
    },
  },
}
