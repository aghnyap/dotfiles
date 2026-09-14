-- d2 architecture-as-code support. Replaces plugins/structurizr.lua in the
-- v12.0-audited migration.
--
-- Unlike Structurizr's *.dsl, Neovim core has no built-in detection or
-- syntax for *.d2 -- checked (`nvim --headless -c 'e x.d2' -c 'set ft?'`
-- reports empty filetype on a clean install), so both are wired up below
-- instead of relying on upstream.
--
-- There is no known d2 LSP yet, same situation Structurizr was in:
-- <leader>Cv shelling out to `d2 validate` is the only diagnostics
-- available.
--
-- IMPORTANT -- this file must never declare a `config` or `init` for
-- toggleterm. lazy.nvim keeps exactly one of each per plugin across all spec
-- files and does not chain them, so a second one would silently replace the
-- block in plugins/tasks.lua and take every <leader>r runner with it. The
-- terminal below requires toggleterm at call time instead.

local PORT = vim.env.D2_PORT or '8081'

local function workspace_dir()
  local buf = vim.api.nvim_buf_get_name(0)
  if buf:match('%.d2$') then
    local dir = vim.fs.dirname(buf)
    if vim.uv.fs_stat(dir .. '/workspace.d2') then
      return dir
    end
  end
  local cwd = vim.uv.cwd()
  local root = vim.fs.root(0, '.git') or cwd
  for _, dir in ipairs({ cwd, cwd .. '/docs/architecture', root, root .. '/docs/architecture' }) do
    if vim.uv.fs_stat(dir .. '/workspace.d2') then
      return dir
    end
  end
  return nil
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'd2' })
end

-- Render every layer straight to an image -- d2 fans a layered file out on
-- its own (workspace.d2 with layers.c1/c2 -> images/workspace/c1.svg,
-- c2.svg), so unlike the old Structurizr path there is no separate export
-- step or PlantUML detour to shell out to c4.zsh for.
local function render(fmt)
  local dir = workspace_dir()
  if not dir then
    notify('no workspace.d2 in . or docs/architecture', vim.log.levels.WARN)
    return
  end
  notify('rendering ' .. fmt .. '…')
  vim.system({
    'd2',
    dir .. '/workspace.d2',
    dir .. '/images/workspace.' .. fmt,
  }, { text = true }, vim.schedule_wrap(function(out)
    if out.code ~= 0 then
      notify('render failed:\n' .. vim.trim((out.stderr or '') .. (out.stdout or '')), vim.log.levels.ERROR)
      return
    end
    notify('rendered to ' .. vim.fn.fnamemodify(dir .. '/images', ':~'))
  end))
end

-- Validate, violations into the quickfix list. The stand-in for an LSP.
local function validate()
  local dir = workspace_dir()
  if not dir then
    notify('no workspace.d2 in . or docs/architecture', vim.log.levels.WARN)
    return
  end
  notify('validating…')
  vim.system({ 'd2', 'validate', dir .. '/workspace.d2' }, { text = true }, vim.schedule_wrap(function(out)
    if out.code == 0 then
      vim.fn.setqflist({})
      notify('workspace is valid')
      return
    end
    local items = {}
    for line in ((out.stderr or '') .. (out.stdout or '')):gmatch('[^\n]+') do
      -- d2's own error shape: "err: ...: LINE:COL: message" -- much flatter
      -- than Structurizr's logger preamble, so there is less to strip.
      local lnum, col, text = line:match('(%d+):(%d+): (.+)$')
      table.insert(items, {
        filename = dir .. '/workspace.d2',
        lnum = tonumber(lnum) or 1,
        col = tonumber(col) or 1,
        text = text or vim.trim(line),
        type = 'E',
      })
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
    notify('no workspace.d2 in . or docs/architecture', vim.log.levels.WARN)
    return
  end
  local ok, terminal = pcall(require, 'toggleterm.terminal')
  if not ok then
    notify('toggleterm is not loaded', vim.log.levels.ERROR)
    return
  end
  terminal.Terminal
    :new({
      cmd = 'cd ' .. vim.fn.shellescape(dir) .. ' && PORT=' .. PORT .. ' d2 --watch workspace.d2',
      direction = 'horizontal',
      close_on_exit = false,
      hidden = true,
    })
    :toggle()
end

local group = vim.api.nvim_create_augroup('cursorlike_d2', { clear = true })

-- Neovim core has no *.d2 detection at all (unlike *.dsl for Structurizr),
-- so this is not optional the way the old comment about vim/vim#8764 was.
vim.filetype.add({ extension = { d2 = 'd2' } })

vim.api.nvim_create_user_command('D2Render', function()
  render('svg')
end, { desc = 'Render the d2 workspace to SVG' })

vim.api.nvim_create_user_command('D2Validate', validate, { desc = 'Validate the d2 workspace' })

-- Buffer-local, so <leader>C exists only where it means something.
-- Registered from a FileType autocmd rather than a lazy.nvim `keys` table
-- because there is no plugin config here to lazy-load against.
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'd2',
  desc = 'd2: buffer-local architecture keymaps',
  callback = function(ev)
    local function map(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    map('<leader>Cs', serve, 'Serve (d2 --watch)')
    map('<leader>Cb', function()
      vim.ui.open('http://localhost:' .. PORT)
    end, 'Open in browser')
    map('<leader>Cv', validate, 'Validate workspace')
    map('<leader>Cr', function() render('svg') end, 'Render images (svg)')
    map('<leader>CR', function() render('png') end, 'Render images (png)')
  end,
})

return {
  {
    -- Renamed upstream: the terrastruct/d2-vim URL still resolves (GitHub
    -- redirects it), but this is the current org.
    'd2lang/d2-vim',
    ft = 'd2',
  },
  {
    'folke/which-key.nvim',
    opts = {
      spec = {
        { '<leader>C', group = 'd2', mode = 'n' },
      },
    },
  },
}
