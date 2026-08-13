return {
  {
    'yetone/avante.nvim',
    event = 'VeryLazy',
    build = 'make',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
    },
    keys = {
      {
        '<leader>aM',
        function()
          require('util.ai_model').select()
        end,
        desc = 'Select local AI model',
      },
    },
    opts = function()
      local ai_model = require 'util.ai_model'
      local model = ai_model.current()
      local endpoint_alive = require('avante.providers.ollama').check_endpoint_alive
      local ollama = {
        endpoint = 'http://127.0.0.1:11434',
        hide_in_model_selector = true,
        timeout = 120000,
        is_env_set = function()
          return ai_model.require_selected() and endpoint_alive()
        end,
        extra_request_body = {
          options = {
            num_predict = ai_model.output_tokens(),
            keep_alive = '5m',
          },
        },
      }

      -- A Neovim session deliberately starts without a local model. :AiModel
      -- fills these fields immediately, or they are present here when Avante
      -- loads after the user has already selected one.
      if model then
        ollama.model = model
        ollama.context_window = ai_model.prompt_context(model)
        ollama.extra_request_body.options.num_ctx = ai_model.context(model)
      end

      return {
        provider = 'ollama',
        providers = {
          ollama = ollama,
        },
        behaviour = {
          auto_suggestions = false,
          auto_approve_tool_permissions = false,
        },
        mappings = {
          ask = '<leader>aa',
          refresh = '<leader>aA',
          new_ask = '<leader>avn',
          edit = '<leader>ave',
          focus = '<leader>avf',
          stop = '<leader>avs',
          zen_mode = '<leader>avz',
          toggle = {
            default = '<leader>avt',
            debug = '<leader>avd',
            suggestion = '<leader>avg',
            repomap = '<leader>avr',
            selection = '<leader>avv',
          },
          files = {
            add_current = '<leader>avc',
            add_all_buffers = '<leader>avB',
          },
          -- The lazy key above owns this lhs, so Avante leaves the shared
          -- session selector in place instead of installing its native picker.
          select_model = '<leader>aM',
          select_history = '<leader>avh',
          select_acp_model = '<leader>avM',
          select_acp_mode = '<leader>avp',
        },
      }
    end,
  },
}
