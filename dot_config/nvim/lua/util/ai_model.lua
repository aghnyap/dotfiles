local M = {}

-- Context is a property of the model rather than of the machine, so Avante and
-- aider cannot end up disagreeing about the window for the same tag. The sizes
-- are what fits under macOS's default GPU wired limit -- `iogpu.wired_limit_mb`
-- of 0 means the system default, roughly two thirds of RAM on Apple Silicon at
-- 32 GB and below -- with the q8_0 KV cache the Homebrew ollama service sets:
--
--   qwen3-coder:30b    19.0 GB weights + ~0.8 GB KV = ~19.8 GB of ~21.3 GB
--   qwen2.5-coder:14b   9.0 GB weights + ~0.9 GB KV = ~10.2 GB of ~10.5 GB
--   qwen2.5-coder:7b    4.7 GB weights + ~0.5 GB KV =  ~5.2 GB, fits anywhere
--
-- 32k on the 30b is what those numbers rule out: it doubles the KV cache to
-- ~1.6 GB for ~20.6 GB total, which fits only while nothing else draws on the
-- GPU. 16k on the 14b is worse -- it exceeds the 16 GB ceiling outright.
--
-- All three assume OLLAMA_NUM_PARALLEL resolves to 1, since ollama allocates
-- the KV cache as num_ctx * num_parallel. It is deliberately left unset: the
-- server picks 4 only when a 4x buffer fits without spilling layers, and it
-- could not be set from a shell anyway, because `brew services` starts ollama
-- through launchd. Its plist is the only place that would work.
local CONTEXT = {
  ['qwen3-coder:30b'] = 16384,
  ['qwen2.5-coder:14b'] = 8192,
  ['qwen2.5-coder:7b'] = 16384,
}

-- First entry is the default; <leader>aM cycles the rest. The threshold sits
-- under the round number so a machine reporting slightly less than its nominal
-- size still lands in the right tier.
--
-- The lower tier is the floor: a 16 GB M3 Air. It fits the 14b at 8k, but the
-- M3 has half an M1 Pro's memory bandwidth (100 vs 200 GB/s) and no fan, which
-- puts the 14b near 9 tok/s and falling against ~18-20 for the 7b. aider's
-- `whole` format re-sends entire files, so that gap lands on every edit -- the
-- Air leads with the 7b and keeps the 14b one <leader>aM away.
--
-- qwen3-coder has no 14b or 7b tag; the smaller models are qwen2.5-coder.
local TIERS = {
  { min_gib = 30, models = { 'qwen3-coder:30b', 'qwen2.5-coder:7b' } },
  { min_gib = 0, models = { 'qwen2.5-coder:7b', 'qwen2.5-coder:14b' } },
}

local FALLBACK_CONTEXT = 8192
local AIDER_BASE_ARGS = { '--no-auto-commits', '--pretty', '--stream' }

local warned_missing = {}
local autocmd_set = false

-- get_total_memory() rather than `sysctl -n hw.memsize`: this runs on the
-- startup path, where the rest of this config works hard to avoid forks.
local function detect_models()
  local total_gib = vim.uv.get_total_memory() / (1024 * 1024 * 1024)

  for _, tier in ipairs(TIERS) do
    if total_gib >= tier.min_gib then
      return tier.models
    end
  end

  return TIERS[#TIERS].models
end

local MODELS = detect_models()

_G.ai_model = _G.ai_model or MODELS[1]

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'ai' })
end

function M.models()
  return MODELS
end

function M.current()
  if not _G.ai_model or _G.ai_model == '' then
    _G.ai_model = MODELS[1]
  end
  return _G.ai_model
end

function M.context(model)
  return CONTEXT[model or M.current()] or FALLBACK_CONTEXT
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
  if #MODELS < 2 then
    return notify('Only one model fits this machine: ' .. M.current())
  end

  local index = 1
  for i, model in ipairs(MODELS) do
    if model == M.current() then
      index = i
      break
    end
  end

  local next_model = MODELS[index % #MODELS + 1]
  _G.ai_model = next_model

  pcall(function()
    require('avante.config').override {
      providers = {
        ollama = {
          model = next_model,
          extra_request_body = {
            options = { num_ctx = M.context(next_model) },
          },
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
  notify(('Local AI model: %s (%dk context)'):format(next_model, M.context(next_model) / 1024))
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
