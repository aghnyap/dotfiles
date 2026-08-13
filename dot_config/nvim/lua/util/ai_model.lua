local M = {}

local PRIMARY = 'qwen3-coder:30b'
local FALLBACK = 'qwen2.5-coder:7b'
local AIDER_BASE_ARGS = { '--no-auto-commits', '--pretty', '--stream' }

local warned_missing = {}
local autocmd_set = false

_G.ai_model = _G.ai_model or PRIMARY

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'ai' })
end

function M.current()
  if not _G.ai_model or _G.ai_model == '' then
    _G.ai_model = PRIMARY
  end
  return _G.ai_model
end

function M.aider_model(model)
  return 'ollama_chat/' .. (model or M.current())
end

function M.aider_args(model)
  local args = vim.deepcopy(AIDER_BASE_ARGS)
  vim.list_extend(args, { '--model', M.aider_model(model) })
  return args
end

local function aider_cmd(opts)
  opts = opts or {}
  local cmd = { opts.aider_cmd or 'aider' }
  vim.list_extend(cmd, opts.args or {})

  if opts.theme then
    for k, v in pairs(opts.theme) do
      table.insert(cmd, '--' .. k:gsub('_', '-') .. '=' .. tostring(v))
    end
  end

  return table.concat(cmd, ' ')
end

local function aider_session_running(opts)
  local ok, snacks = pcall(require, 'nvim_aider.snacks_ext')
  if not ok then
    return false
  end

  local lookup = vim.tbl_deep_extend('force', {}, opts or {}, { create = false })
  local term = snacks.get(aider_cmd(opts), lookup)
  return term and snacks.is_running(term) or false
end

function M.sync_aider_args()
  local ok, config = pcall(require, 'nvim_aider.config')
  if ok then
    config.options.args = M.aider_args()
  end
end

function M.warn_if_missing(model)
  model = model or M.current()
  if warned_missing[model] then
    return
  end
  warned_missing[model] = true

  if vim.fn.executable('ollama') == 0 then
    return notify('ollama is not installed; cannot use ' .. model, vim.log.levels.WARN)
  end

  vim.system({ 'ollama', 'list' }, { text = true }, function(result)
    local stdout = result.stdout or ''
    if result.code ~= 0 or not stdout:find(model, 1, true) then
      vim.schedule(function()
        notify('Ollama model is not pulled: ' .. model, vim.log.levels.WARN)
      end)
    end
  end)
end

function M.toggle()
  local next_model = M.current() == PRIMARY and FALLBACK or PRIMARY
  _G.ai_model = next_model

  pcall(function()
    require('avante.config').override {
      providers = {
        ollama = {
          model = next_model,
        },
      },
    }
  end)

  local ok, config = pcall(require, 'nvim_aider.config')
  if ok then
    if aider_session_running(config.options) then
      require('nvim_aider.api').send_command('/model', M.aider_model(next_model))
    else
      config.options.args = M.aider_args(next_model)
    end
  end

  M.warn_if_missing(next_model)
  notify('Local AI model: ' .. next_model)
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
end

M.setup()

return M
