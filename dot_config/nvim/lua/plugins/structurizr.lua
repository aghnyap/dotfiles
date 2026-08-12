-- Structurizr DSL / C4 model support.
--
-- Nothing is installed here, deliberately:
--
--   * Syntax already works. Structurizr syntax ships in Neovim core
--     (runtime/syntax/structurizr.vim, upstreamed as vim/vim#8764), and *.dsl
--     is already detected -- `nvim --headless -c 'set ft?' x.dsl` reports
--     filetype=structurizr on a clean install. So there is no filetype.lua and
--     no syntax plugin. The plugin most setup guides name,
--     jfcherng/vim-structurizr, does not exist: the URL 404s and that author
--     has no Vim repos at all.
--
--   * There is no LSP. The nvim-lspconfig PR for one was rejected (#3570,
--     "the LSP repo has no stars, so this needs to mature a bit") and mason has
--     no package. <leader>Cv shelling out to `structurizr validate` is the only
--     diagnostics available -- that is why it exists, not a nicety.
--
-- One filetype edge worth knowing: core maps `.dsl` with
--     dsl = detect_line1('^%s*<!', 'dsl', 'structurizr')
-- so a workspace file whose FIRST line starts with `<!` lands on the unrelated
-- `dsl` filetype. Structurizr files start with `workspace`, so this only bites
-- if something XML-ish gets pasted at the top.
--
-- IMPORTANT -- this file must never declare a `config` or `init` for
-- toggleterm. lazy.nvim keeps exactly one of each per plugin across all spec
-- files and does not chain them, so a second one would silently replace the
-- block in plugins/tasks.lua and take every <leader>r runner with it. The
-- terminal below requires toggleterm at call time instead.

local PORT = vim.env.C4_PORT or '8081'

-- The JVM structurizr is run with, and why it is not the ambient one.
--
-- Homebrew's launcher does `export JAVA_HOME="${JAVA_HOME:-<brew openjdk>}"` --
-- a fallback, not a pin. ~/.zshenv exports mise's temurin-17 for Gradle and
-- jdtls, Neovim inherits it, and structurizr's war needs Java 21+, so every
-- call failed with `UnsupportedClassVersionError ... class file version 65.0`.
-- Overriding JAVA_HOME per command fixes it without disturbing the global value
-- that the Android toolchain depends on. `_c4_structurizr` in
-- ~/.config/zsh/c4.zsh does the same thing for the shell side.
local JDK = (vim.env.HOMEBREW_PREFIX or '/opt/homebrew') .. '/opt/openjdk/libexec/openjdk.jdk/Contents/Home'

-- Merged into the parent environment, not replacing it -- vim.system only
-- clears when clear_env is set.
local function env()
  if vim.uv.fs_stat(JDK .. '/bin/java') then
    return { JAVA_HOME = JDK }
  end
  return nil -- let it fail with Homebrew's own message rather than inventing one
end

-- Resolve the directory holding workspace.dsl, mirroring _c4_workspace in
-- ~/.config/zsh/c4.zsh: the buffer's own directory, then cwd, then
-- docs/architecture, then the same from the git root.
local function workspace_dir()
  local buf = vim.api.nvim_buf_get_name(0)
  if buf:match('%.dsl$') then
    local dir = vim.fs.dirname(buf)
    if vim.uv.fs_stat(dir .. '/workspace.dsl') then
      return dir
    end
  end
  local cwd = vim.uv.cwd()
  local root = vim.fs.root(0, '.git') or cwd
  for _, dir in ipairs({ cwd, cwd .. '/docs/architecture', root, root .. '/docs/architecture' }) do
    if vim.uv.fs_stat(dir .. '/workspace.dsl') then
      return dir
    end
  end
  return nil
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'c4' })
end

-- Fence the exported Mermaid into Markdown so it renders in a PR.
--
-- Delegated to _c4_wrap_mermaid in ~/.config/zsh/c4.zsh rather than
-- reimplemented, so `c4-export` in the shell and <leader>Ce here cannot drift
-- apart. `zsh -c` with an explicit source is ~1ms against a byte-compiled
-- module; `zsh -ic` would drag in the whole interactive config.
local function wrap_mermaid(dir, done)
  vim.system({
    'zsh',
    '-c',
    'source ${HOME}/.config/zsh/c4.zsh 2>/dev/null; _c4_wrap_mermaid "$0"',
    dir .. '/diagrams',
  }, { text = true }, vim.schedule_wrap(function(out)
    done(vim.trim(out.stdout or ''))
  end))
end

local running = false
local function export(opts)
  opts = opts or {}
  local dir = workspace_dir()
  if not dir then
    if not opts.quiet then
      notify('no workspace.dsl in . or docs/architecture', vim.log.levels.WARN)
    end
    return
  end
  if running then
    return -- a save landed mid-export; the debounce catches the next one
  end
  running = true

  vim.system({
    'structurizr',
    'export',
    '-workspace',
    dir .. '/workspace.dsl',
    '-format',
    'mermaid',
    '-output',
    dir .. '/diagrams',
  }, { text = true, env = env() }, vim.schedule_wrap(function(out)
    if out.code ~= 0 then
      running = false
      notify('export failed:\n' .. vim.trim((out.stderr or '') .. (out.stdout or '')), vim.log.levels.ERROR)
      return
    end
    wrap_mermaid(dir, function(n)
      running = false
      notify(('exported %s view(s)'):format(n == '' and '?' or n))
    end)
  end))
end

-- Validate, violations into the quickfix list. The stand-in for an LSP.
local function validate()
  local dir = workspace_dir()
  if not dir then
    notify('no workspace.dsl in . or docs/architecture', vim.log.levels.WARN)
    return
  end
  notify('validating…')
  vim.system({
    'structurizr',
    'validate',
    '-workspace',
    dir .. '/workspace.dsl',
  }, { text = true, env = env() }, vim.schedule_wrap(function(out)
    if out.code == 0 then
      vim.fn.setqflist({})
      notify('workspace is valid')
      return
    end
    local items = {}
    for line in ((out.stderr or '') .. (out.stdout or '')):gmatch('[^\n]+') do
      -- Drop the JVM's own noise. Java 26 prints three WARNING lines about
      -- Jackson mutating final fields on every single run; they are not model
      -- problems and they cannot be silenced (the flag they suggest goes in
      -- JAVA_OPTS, which Homebrew's launcher never reads).
      if not line:match('^WARNING') then
        -- Strip the logger preamble -- "22:43:41.029 [main] ERROR
        -- com.structurizr.command.ValidateCommand -- " -- so the quickfix line
        -- is the message rather than 60 characters of timestamp and class name.
        local text = (vim.trim(line):gsub('^%d+:%d+:%d+%.%d+%s+%[[^%]]*%]%s+%u+%s+[%w%.]+%s+%-%-%s+', ''))
        -- Parser errors carry "at line N"; anything else still belongs in the
        -- list, just without a position.
        local lnum = line:match('at line (%d+)')
        table.insert(items, {
          filename = dir .. '/workspace.dsl',
          lnum = tonumber(lnum) or 1,
          text = text,
          type = 'E',
        })
      end
    end
    vim.fn.setqflist(items)
    vim.cmd('copen')
    notify(('%d problem(s)'):format(#items), vim.log.levels.WARN)
  end))
end

-- Serve, in a toggleterm split. Required at call time -- see the note above
-- about never declaring a config for toggleterm here.
local function serve()
  local dir = workspace_dir()
  if not dir then
    notify('no workspace.dsl in . or docs/architecture', vim.log.levels.WARN)
    return
  end
  local ok, terminal = pcall(require, 'toggleterm.terminal')
  if not ok then
    notify('toggleterm is not loaded', vim.log.levels.ERROR)
    return
  end
  terminal.Terminal
    :new({
      cmd = 'cd ' .. vim.fn.shellescape(dir) .. ' && c4-local',
      direction = 'horizontal',
      close_on_exit = false,
      hidden = true,
    })
    :toggle()
end

-- ── Auto-export on save ─────────────────────────────────────────────────────
-- Off by default. Each export is a JVM start, so 1-3s of background work per
-- save -- worth it while iterating on diagrams, pure noise mid-thought.
-- `:C4AutoExport` toggles it for the session.
--
-- Debounced on a uv timer so a burst of :w collapses into one run. This is the
-- config's first BufWritePost autocmd; format-on-save is conform's own hook.
local timer
local function schedule_export()
  if timer then
    timer:stop()
    timer:close()
  end
  timer = vim.uv.new_timer()
  timer:start(2000, 0, vim.schedule_wrap(function()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    export({ quiet = true })
  end))
end

local group = vim.api.nvim_create_augroup('cursorlike_c4', { clear = true })

vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  pattern = '*.dsl',
  desc = 'Structurizr: debounced Mermaid export when auto-export is on',
  callback = function()
    if vim.g.c4_auto_export then
      schedule_export()
    end
  end,
})

vim.api.nvim_create_user_command('C4Export', function()
  export()
end, { desc = 'Export the C4 model to Mermaid' })

vim.api.nvim_create_user_command('C4Validate', validate, { desc = 'Validate the Structurizr workspace' })

vim.api.nvim_create_user_command('C4AutoExport', function()
  vim.g.c4_auto_export = not vim.g.c4_auto_export
  notify('auto-export ' .. (vim.g.c4_auto_export and 'ON' or 'OFF'))
end, { desc = 'Toggle Mermaid export on save' })

-- Buffer-local, so <leader>C exists only where it means something. Registered
-- from a FileType autocmd rather than a lazy.nvim `keys` table because there is
-- no plugin here to lazy-load.
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'structurizr',
  desc = 'Structurizr: buffer-local C4 keymaps',
  callback = function(ev)
    local function map(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    map('<leader>Cs', serve, 'Serve (structurizr local)')
    map('<leader>Cb', function()
      vim.ui.open('http://localhost:' .. PORT)
    end, 'Open in browser')
    map('<leader>Ce', function()
      export()
    end, 'Export to Mermaid')
    map('<leader>Cv', validate, 'Validate workspace')
    map('<leader>Ca', '<cmd>C4AutoExport<cr>', 'Toggle export on save')
  end,
})

-- The only actual plugin spec: teach which-key the group name. `opts` is merged
-- by LazyVim, the same way lang-web.lua extends nvim-lspconfig -- no `config`,
-- so nothing is clobbered.
return {
  {
    'folke/which-key.nvim',
    opts = {
      spec = {
        { '<leader>C', group = 'c4', mode = 'n' },
      },
    },
  },
}
