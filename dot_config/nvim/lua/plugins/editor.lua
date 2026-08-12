-- Editing behaviour: terminal panel, multi-cursor, auto-save, formatting,
-- and the tmux bridge.
return {
  -- ── Seamless Neovim <-> tmux navigation ─────────────────────────
  --    C-hjkl moves between Neovim splits and tmux panes with no prefix and
  --    no mode change. The plugin checks whether the neighbouring tmux pane
  --    is running Neovim and forwards the key instead of switching panes.
  --    Requires the matching plugin in ~/.config/tmux/tmux.conf.
  {
    'christoomey/vim-tmux-navigator',
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
    },
    keys = {
      { '<C-h>', '<cmd>TmuxNavigateLeft<cr>', desc = 'Focus left pane' },
      { '<C-j>', '<cmd>TmuxNavigateDown<cr>', desc = 'Focus pane below' },
      { '<C-k>', '<cmd>TmuxNavigateUp<cr>', desc = 'Focus pane above' },
      { '<C-l>', '<cmd>TmuxNavigateRight<cr>', desc = 'Focus right pane' },
    },
  },

  -- ── Integrated terminal panel at the bottom ─────────────────────
  --    tasks.lua extends this spec with the named app/logcat/gradle/melos
  --    terminals, so the options live here and the config there.
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    cmd = { 'ToggleTerm', 'TermExec' },
    opts = {
      size = 15,
      direction = 'horizontal',
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      persist_size = true,
      persist_mode = true,
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = { border = 'rounded' },
    },
  },

  -- ── Multi-cursor: Cmd+D adds a cursor at the next occurrence ─────
  {
    'jake-stewart/multicursor.nvim',
    branch = '1.0',
    event = 'VeryLazy',
    config = function()
      local mc = require 'multicursor-nvim'
      mc.setup()

      local set = vim.keymap.set
      set({ 'n', 'x' }, '<D-d>', function()
        mc.matchAddCursor(1)
      end, { desc = 'Add cursor at next match' })
      set({ 'n', 'x' }, '<D-S-d>', mc.matchAllAddCursors, { desc = 'Select all occurrences' })
      set({ 'n', 'x' }, '<leader>ms', function()
        mc.matchSkipCursor(1)
      end, { desc = 'Skip next match' })
      -- Cmd+Alt+Up/Down stacks cursors vertically, as in VS Code.
      set({ 'n', 'x' }, '<M-D-Up>', function()
        mc.lineAddCursor(-1)
      end, { desc = 'Add cursor above' })
      set({ 'n', 'x' }, '<M-D-Down>', function()
        mc.lineAddCursor(1)
      end, { desc = 'Add cursor below' })

      -- Esc collapses back to a single cursor.
      mc.addKeymapLayer(function(layer)
        layer({ 'n', 'x' }, '<Esc>', function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
        layer('n', '<C-c>', mc.clearCursors)
      end)

      local hl = vim.api.nvim_set_hl
      hl(0, 'MultiCursorCursor', { link = 'Cursor' })
      hl(0, 'MultiCursorVisual', { link = 'Visual' })
      hl(0, 'MultiCursorSign', { link = 'SignColumn' })
      hl(0, 'MultiCursorMatchPreview', { link = 'Search' })
      hl(0, 'MultiCursorDisabledCursor', { link = 'Visual' })
      hl(0, 'MultiCursorDisabledVisual', { link = 'Visual' })
    end,
  },

  -- ── Auto-save, matching VS Code's files.autoSave = afterDelay ────
  {
    'okuuva/auto-save.nvim',
    version = '*',
    event = { 'InsertLeave', 'TextChanged' },
    opts = {
      enabled = true,
      -- No `execution_message`. It was removed upstream, and setting it made
      -- auto-save.nvim print a deprecation notice on every single startup.
      -- Silence is the default now, which is what it was set for anyway.
      debounce_delay = 1000,
      trigger_events = {
        immediate_save = { 'BufLeave', 'FocusLost' },
        defer_save = { 'InsertLeave', 'TextChanged' },
        cancel_deferred_save = { 'InsertEnter' },
      },
      condition = function(buf)
        if not vim.bo[buf].modifiable or vim.bo[buf].readonly then
          return false
        end
        if vim.api.nvim_buf_get_name(buf) == '' then
          return false
        end
        if vim.bo[buf].buftype ~= '' then
          return false
        end
        local skip = { 'neo-tree', 'gitcommit', 'gitrebase', 'oil', 'harpoon' }
        return not vim.tbl_contains(skip, vim.bo[buf].filetype)
      end,
      -- Suppress formatting for the duration of an auto-save write, by flipping
      -- the same global LazyVim's own format-on-save reads. Auto-save fires about
      -- a second after you stop typing; formatting those writes moves the cursor
      -- mid-keystroke, which is the bug this exists to prevent.
      --
      -- The previous value is saved and restored rather than forced back to true:
      -- `vim.g.autoformat` is also the user-facing toggle (`<leader>uf`), so
      -- hardcoding true here would silently re-enable formatting for anyone who
      -- had turned it off.
      --
      -- This used to be a `format_on_save` function in conform's own opts, which
      -- LazyVim warns about on every startup for good reason: LazyVim installs
      -- its own format-on-save, so setting conform's as well meant two
      -- independent format passes on the same write.
      callbacks = {
        before_saving = function()
          vim.g.autosave_prev_autoformat = vim.g.autoformat
          vim.g.autoformat = false
        end,
        after_saving = function()
          vim.g.autoformat = vim.g.autosave_prev_autoformat
        end,
      },
    },
  },

  -- ── Formatting ──────────────────────────────────────────────────
  {
    'stevearc/conform.nvim',
    opts = {
      default_format_opts = { lsp_format = 'fallback' },
      formatters_by_ft = {
        lua = { 'stylua' },
        kotlin = { 'ktlint' },
        -- Dart and XML deliberately have no entry: `default_format_opts`
        -- above falls back to the LSP, and dartls / lemminx both format
        -- well. Using the `dart format` CLI would not work anyway -- FVM
        -- means there is no `dart` on PATH.
        swift = { 'swiftformat' },
        go = { 'goimports', 'gofumpt' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
        zsh = { 'shfmt' },
        -- js/ts/json/yaml/markdown/html/css come from the
        -- formatting.prettier extra, which already prefers prettierd.
      },
      -- No `format_on_save` here, and no `:FormatToggle`. LazyVim owns
      -- format-on-save and gates it on `vim.g.autoformat` / `vim.b.autoformat`,
      -- which `<leader>uf` and `<leader>uF` already toggle. The auto-save
      -- exclusion is handled by flipping that same global in the auto-save
      -- callbacks above, so there is one format path and one toggle instead of
      -- two of each.
    },
  },

  -- ── gitsigns: the previous config's signs and hunk maps ─────────
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '┃' },
        change = { text = '┃' },
        delete = { text = '▁' },
        topdelete = { text = '▔' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      signs_staged_enable = true,
      current_line_blame = false,
      preview_config = { border = 'rounded' },
    },
  },

  -- ── Extra Mason tools beyond what the LazyVim extras install ────
  {
    'mason-org/mason.nvim',
    opts = function(_, opts)
      opts.ui = vim.tbl_deep_extend('force', opts.ui or {}, { border = 'rounded' })
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        'stylua',
        'shfmt',
        'prettierd',
        'gofumpt',
        'goimports',
        'ruff',
        'ktlint', -- Kotlin lint + format, wired into conform above
        'lemminx', -- AndroidManifest.xml, res/ layouts
      })
      return opts
    end,
  },
}
