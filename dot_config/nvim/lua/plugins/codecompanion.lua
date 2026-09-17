-- ╭──────────────────────────────────────────────────────────────╮
-- │  codecompanion.nvim -- local + aggregated AI, replacing Avante │
-- │                                                                │
-- │  Three adapters:                                               │
-- │   - ollama:      the same local model :AiModel already selects │
-- │                  for aider (util/ai_model.lua is the shared    │
-- │                  source of truth for which model and context). │
-- │   - litellm:     LiteLLM's own OpenAI-compatible proxy, so any  │
-- │                  model IT aggregates (local GGUFs, Claude,      │
-- │                  OpenAI) is reachable without a second plugin.  │
-- │                  litellm itself is a `uv tool` (see the         │
-- │                  installer script), started by hand:            │
-- │                  `litellm --config <file>`.                     │
-- │   - openrouter:  OpenRouter's own OpenAI-compatible endpoint,   │
-- │                  cloud and API-key-gated (unlike the two        │
-- │                  above). Needs OPENROUTER_API_KEY in the shell  │
-- │                  environment -- this repo does not manage or    │
-- │                  store it (see dot_aider.conf.yml). Reached the │
-- │                  same way as litellm: switch adapters from      │
-- │                  codecompanion's own picker, not :AiModel.      │
-- ╰──────────────────────────────────────────────────────────────╯
local ai_model = require 'util.ai_model'

-- LiteLLM's proxy needs a running server on this port to answer at all;
-- unlike ollama there is no managed brew-services unit for it, so this is
-- just where it is expected if you have started one.
local LITELLM_URL = 'http://127.0.0.1:4000'

-- OpenRouter's own endpoint -- unlike LITELLM_URL this is a fixed, non-local
-- base URL: OpenRouter is the cloud service itself, not a local proxy.
local OPENROUTER_URL = 'https://openrouter.ai/api/v1'

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
        -- Adapters live under `adapters.http`, not top-level -- checked
        -- against the installed plugin's own config.lua (adapters.http.*
        -- is where `ollama`/`openai_compatible` etc. are registered) after
        -- a top-level `adapters = { ollama = ... }` table was silently
        -- ignored: `require('codecompanion.config').config.adapters.http`
        -- never had these keys, so every chat used the plugin's own
        -- unmodified built-in ollama adapter (no model, no num_ctx) and
        -- `litellm` did not exist at all as far as codecompanion was
        -- concerned.
        adapters = {
          http = {
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
            -- 'openai_compatible' is codecompanion's built-in template for
            -- any OpenAI-shaped endpoint that isn't OpenAI itself --
            -- exactly what LiteLLM's proxy exposes. No API key is required
            -- by a local LiteLLM instance with no auth configured; the
            -- field still has to be present or the adapter refuses to
            -- build the request.
            litellm = function()
              return require('codecompanion.adapters').extend('openai_compatible', {
                env = {
                  url = LITELLM_URL,
                  api_key = os.getenv 'LITELLM_API_KEY' or 'sk-local',
                },
              })
            end,
            -- Same 'openai_compatible' template as litellm, pointed at
            -- OpenRouter instead. Unlike litellm's local proxy, a missing
            -- key here should fail loudly rather than quietly succeed
            -- against nothing -- 'sk-missing' is deliberately not a value
            -- OpenRouter will ever accept, unlike litellm's 'sk-local'
            -- fallback which is correct for a no-auth local server.
            openrouter = function()
              return require('codecompanion.adapters').extend('openai_compatible', {
                env = {
                  url = OPENROUTER_URL,
                  api_key = os.getenv 'OPENROUTER_API_KEY' or 'sk-missing',
                },
              })
            end,
          },
        },
        -- `strategies` was renamed to `interactions` upstream (config.lua
        -- still migrates the old key with a TODO to remove it, which is
        -- how this went unnoticed); `agent` is not a real interaction name
        -- either (the valid ones are chat/inline/cmd/cli/code_review/...),
        -- so it was silently dropped along with the whole table. litellm
        -- and openrouter both stay reachable as named adapters -- switch to
        -- either from codecompanion's own adapter picker -- rather than
        -- wired as a default strategy that does not exist.
        interactions = {
          chat = { adapter = 'ollama' },
          inline = { adapter = 'ollama' },
        },
        display = {
          chat = {
            window = { layout = 'vertical', width = 0.4 },
          },
        },
      }
    end,
    keys = {
      -- A Neovim session starts without a model selected; require one
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
      -- ADAPTER answers (ollama vs. litellm vs. openrouter), not which
      -- model inside ollama, and would leave aider's args and the
      -- readiness check out of sync with whatever codecompanion picked.
      -- Avante used to leave this lhs to the shared selector for the same
      -- reason.
      { '<leader>aM', '<cmd>AiModel<cr>', desc = 'Select AI model, local or OpenRouter (shared with aider)' },
    },
  },
}
