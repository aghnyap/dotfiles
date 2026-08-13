return {
  {
    'yetone/avante.nvim',
    event = 'VeryLazy',
    build = 'make',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
    },
    opts = function()
      local ai_model = require 'util.ai_model'

      return {
        provider = 'ollama',
        providers = {
          ollama = {
            endpoint = 'http://127.0.0.1:11434',
            model = ai_model.current(),
            timeout = 120000,
            is_env_set = require('avante.providers.ollama').check_endpoint_alive,
            extra_request_body = {
              options = {
                num_ctx = 16384,
                num_predict = 1024,
                keep_alive = '5m',
              },
            },
          },
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
          select_model = '<leader>avm',
          select_history = '<leader>avh',
          select_acp_model = '<leader>avM',
          select_acp_mode = '<leader>avp',
        },
      }
    end,
  },
}
