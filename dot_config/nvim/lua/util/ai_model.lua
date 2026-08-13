local M = {}

-- Model choice is deliberately human, not a RAM-derived policy. This catalog
-- only records request budgets that have been checked against Ollama's q8_0 KV
-- cache. Keep it aligned with ~/.aider.model.settings.yml and
-- ~/.aider.model.metadata.json.
local PROFILES = {
  { model = 'qwen2.5-coder:7b', context = 16384 },
  { model = 'qwen2.5-coder:14b', context = 8192 },
  { model = 'qwen3-coder:30b', context = 16384 },
}

-- Ollama's num_ctx is input + output. Avante and aider receive the smaller
-- prompt budget so a response cannot silently run beyond that total.
local OUTPUT_TOKENS = 1024
local AIDER_BASE_ARGS = { '--no-auto-commits', '--pretty', '--stream' }

local profiles_by_model = {}
local models = {}
for _, profile in ipairs(PROFILES) do
  profiles_by_model[profile.model] = profile
  models[#models + 1] = profile.model
end

local warned_missing = {}
local autocmd_set = false

local function is_known(model)
  return type(model) == 'string' and profiles_by_model[model] ~= nil
end

-- Preserve an explicit choice when this module is reloaded within the same
-- Neovim process, but never invent or persist one.
if not is_known(_G.ai_model) then
  _G.ai_model = nil
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'ai' })
end

function M.models()
  return vim.deepcopy(models)
end

function M.current()
  if not is_known(_G.ai_model) then
    _G.ai_model = nil
  end
  return _G.ai_model
end

function M.context(model)
  local profile = profiles_by_model[model or M.current()]
  return profile and profile.context or nil
end

function M.output_tokens()
  return OUTPUT_TOKENS
end

function M.prompt_context(model)
  local context = M.context(model)
  return context and context - OUTPUT_TOKENS or nil
end

function M.aider_model(model)
  model = model or M.current()
  return model and ('ollama_chat/' .. model) or nil
end

function M.aider_args(model)
  local args = vim.deepcopy(AIDER_BASE_ARGS)
  local aider_model = M.aider_model(model)
  if aider_model then
    vim.list_extend(args, { '--model', aider_model })
  end
  return args
end

-- Snacks keys terminals by command, cwd and count. Reconstructing that key
-- loses a live aider session after :lcd or a counted toggle, so inspect the
-- registry and identify nvim-aider's decorated terminals instead.
local function aider_sessions()
  local ok_base, terminal = pcall(require, 'snacks.terminal')
  local ok_ext, snacks = pcall(require, 'nvim_aider.snacks_ext')
  if not ok_base or not ok_ext then
    return {}
  end

  return vim.tbl_filter(function(term)
    return type(term.send_with_timer) == 'function' and snacks.is_running(term)
  end, terminal.list())
end

function M.sync_aider_args()
  local ok, config = pcall(require, 'nvim_aider.config')
  if ok then
    config.options.args = M.aider_args()
  end
end

function M.warn_if_missing(model)
  model = model or M.current()
  if not model then
    return
  end
  if warned_missing[model] then
    return
  end
  warned_missing[model] = true

  if vim.fn.executable('ollama') == 0 then
    return notify('ollama is not installed; cannot use ' .. model, vim.log.levels.WARN)
  end

  vim.system({ 'ollama', 'show', model }, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        notify('Ollama model is not pulled: ' .. model, vim.log.levels.WARN)
      end)
    end
  end)
end

function M.require_selected()
  if M.current() then
    return true
  end

  notify('Select a local model first with :AiModel.', vim.log.levels.WARN)
  return false
end

local function apply(model)
  if not is_known(model) then
    notify('Unsupported local AI model: ' .. tostring(model), vim.log.levels.ERROR)
    return false
  end

  local sessions = aider_sessions()
  for _, term in ipairs(sessions) do
    if vim.b[term.buf].aider_busy then
      notify('Aider is busy; model unchanged.', vim.log.levels.WARN)
      return false
    end
  end

  -- aider 0.86.2 applies local metadata to the initial model, but `/model`
  -- reconstructs it after LiteLLM has loaded and can replace the safe 8k/16k
  -- budget with the advertised 32k/262k window. Reopen instead of hot-swapping
  -- into silent truncation; the chat transcript remains on disk.
  if #sessions > 0 then
    notify('Close Aider before switching models; model unchanged.', vim.log.levels.WARN)
    return false
  end

  _G.ai_model = model

  local ok, config = pcall(require, 'nvim_aider.config')
  if ok then
    config.options.args = M.aider_args(model)
  end

  pcall(function()
    local avante_config = require 'avante.config'
    avante_config.override {
      providers = {
        ollama = {
          model = model,
          context_window = M.prompt_context(model),
          extra_request_body = {
            options = {
              num_ctx = M.context(model),
              num_predict = M.output_tokens(),
            },
          },
        },
      },
    }

    -- Providers are materialized and cached on first access. Drop only the
    -- cached Ollama functor so the next request rebuilds it from the override;
    -- changing Config alone leaves Avante talking to the previous model.
    local providers = package.loaded['avante.providers']
    if providers then
      providers.ollama = nil
    end
  end)

  M.warn_if_missing(model)
  notify(('Local AI model: %s (%dk context)'):format(model, M.context(model) / 1024))
  return true
end

function M.select(model)
  if model and model ~= '' then
    return apply(model)
  end

  vim.ui.select(models, {
    prompt = 'Local AI model',
    format_item = function(item)
      return ('%s (%dk context)'):format(item, M.context(item) / 1024)
    end,
  }, function(choice)
    if choice then
      apply(choice)
    end
  end)
end

function M.setup()
  if autocmd_set then
    return
  end
  autocmd_set = true

  vim.api.nvim_create_autocmd('User', {
    pattern = 'AiderExit',
    callback = function()
      M.sync_aider_args()
    end,
  })

  if vim.fn.exists(':AiModel') == 0 then
    vim.api.nvim_create_user_command('AiModel', function(opts)
      M.select(opts.args)
    end, {
      nargs = '?',
      desc = 'Select the local AI model for this Neovim session',
      complete = function(arglead)
        return vim.tbl_filter(function(model)
          return vim.startswith(model, arglead)
        end, models)
      end,
    })
  end
end

M.setup()

return M
