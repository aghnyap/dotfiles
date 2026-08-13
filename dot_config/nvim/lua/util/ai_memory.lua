local M = {}

local LOW_MEMORY_GB = 4
local BYTES_PER_GB = 1024 * 1024 * 1024

local function parse_number(value)
  value = tostring(value or ''):gsub('[^%d]', '')
  return tonumber(value) or 0
end

local function gb(bytes)
  return bytes / BYTES_PER_GB
end

local function parse_vm_stat(output)
  local stats = {
    free = 0,
    inactive = 0,
    speculative = 0,
    purgeable = 0,
    page_size = 4096,
  }

  local page_size = parse_number((output or ''):match('page size of%s+([%d,]+)%s+bytes'))
  if page_size > 0 then
    stats.page_size = page_size
  end

  local fields = {
    ['Pages free'] = 'free',
    ['Pages inactive'] = 'inactive',
    ['Pages speculative'] = 'speculative',
    ['Pages purgeable'] = 'purgeable',
  }

  for line in (output or ''):gmatch('[^\r\n]+') do
    local name, value = line:match('^([^:]+):%s+([%d,]+)%.')
    local key = name and fields[vim.trim(name)]
    if key then
      stats[key] = parse_number(value)
    end
  end

  return stats
end

local function parse_swap_used_gb(output)
  local amount, unit = (output or ''):match('used%s+=%s+([%d%.]+)([KMGTP])')
  amount = tonumber(amount)
  if not amount then
    return 0
  end

  local multipliers = {
    K = 1 / (1024 * 1024),
    M = 1 / 1024,
    G = 1,
    T = 1024,
    P = 1024 * 1024,
  }

  return amount * (multipliers[unit] or 1)
end

local function notify_memory(total_bytes, vm_stat_output, swap_output)
  local ai_model = require 'util.ai_model'
  local stats = parse_vm_stat(vm_stat_output)
  local total_gb = gb(total_bytes)
  local available_gb = gb((stats.free + stats.inactive + stats.speculative) * stats.page_size)
  local purgeable_gb = gb(stats.purgeable * stats.page_size)
  local swap_used_gb = parse_swap_used_gb(swap_output)
  local level = available_gb < LOW_MEMORY_GB and vim.log.levels.WARN or vim.log.levels.INFO

  -- Naming the model and window matters most on a 16 GB machine, where the
  -- margin between what is loaded and what fits is a few hundred megabytes.
  local message = ('%s at %dk context\nAvailable %.1f GB / %.1f GB (purgeable %.1f GB, swap used %.1f GB)'):format(
    ai_model.current(),
    ai_model.context() / 1024,
    available_gb,
    total_gb,
    purgeable_gb,
    swap_used_gb
  )

  if level == vim.log.levels.WARN then
    message = message .. ('\nBelow %d GB; pause local AI before macOS starts swap-paging.'):format(LOW_MEMORY_GB)
  end

  vim.notify(message, level, { title = 'AI memory' })
end

function M.check()
  if vim.uv.os_uname().sysname ~= 'Darwin' then
    vim.notify('AI memory check only supports macOS.', vim.log.levels.WARN, { title = 'AI memory' })
    return
  end

  local results = {}
  local remaining = 3

  local function done(key, result)
    results[key] = result
    remaining = remaining - 1

    if remaining > 0 then
      return
    end

    vim.schedule(function()
      if results.memsize.code ~= 0 or results.vm_stat.code ~= 0 then
        vim.notify('Could not read macOS memory stats.', vim.log.levels.ERROR, { title = 'AI memory' })
        return
      end

      notify_memory(tonumber(vim.trim(results.memsize.stdout or '0')) or 0, results.vm_stat.stdout, results.swap.stdout)
    end)
  end

  vim.system({ 'sysctl', '-n', 'hw.memsize' }, { text = true }, function(result)
    done('memsize', result)
  end)
  vim.system({ 'vm_stat' }, { text = true }, function(result)
    done('vm_stat', result)
  end)
  vim.system({ 'sysctl', '-n', 'vm.swapusage' }, { text = true }, function(result)
    done('swap', result)
  end)
end

return M
