local function local_ai_plug(plug, restore_visual)
  return function()
    local mode = vim.fn.mode()
    local was_visual = vim.tbl_contains({ 'v', 'V', '\22' }, mode)
    local origin = {
      buf = vim.api.nvim_get_current_buf(),
      win = vim.api.nvim_get_current_win(),
    }
    if was_visual then
      origin.first = vim.fn.getpos 'v'
      origin.last = vim.fn.getpos '.'
      if origin.first[2] > origin.last[2] or (origin.first[2] == origin.last[2] and origin.first[3] > origin.last[3]) then
        origin.first, origin.last = origin.last, origin.first
      end
    end

    require('util.ai_model').with_ready_model(function()
      if not vim.api.nvim_buf_is_valid(origin.buf) or not vim.api.nvim_win_is_valid(origin.win) then
        vim.notify('Original Avante buffer or window closed; action cancelled.', vim.log.levels.WARN, { title = 'ai' })
        return
      end
      vim.api.nvim_set_current_win(origin.win)
      if vim.api.nvim_win_get_buf(origin.win) ~= origin.buf then
        vim.api.nvim_win_set_buf(origin.win, origin.buf)
      end
      if restore_visual and was_visual then
        vim.fn.setpos("'<", origin.first)
        vim.fn.setpos("'>", origin.last)
        vim.cmd.normal { args = { 'gv' }, bang = true }
      end
      vim.api.nvim_feedkeys(vim.keycode(plug), 'm', false)
    end)
  end
end

local function local_suggestion_toggle()
  local function toggle()
    require('avante').toggle.suggestion()
  end

  if require('avante.config').behaviour.auto_suggestions then
    return toggle()
  end
  require('util.ai_model').with_ready_model(toggle)
end

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
        '<leader>aa',
        local_ai_plug('<Plug>(AvanteAsk)', true),
        mode = { 'n', 'v' },
        desc = 'Avante (local): ask',
      },
      {
        '<leader>avn',
        local_ai_plug('<Plug>(AvanteAskNew)', true),
        mode = { 'n', 'v' },
        desc = 'Avante (local): new ask',
      },
      {
        '<leader>ave',
        local_ai_plug('<Plug>(AvanteEdit)', true),
        mode = 'v',
        desc = 'Avante (local): edit selection',
      },
      {
        '<leader>avg',
        local_suggestion_toggle,
        desc = 'Avante (local): toggle suggestions',
      },
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
