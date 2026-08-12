-- UI additions on top of LazyVim's defaults.
--
-- LazyVim already ships bufferline, lualine, noice, which-key, snacks
-- (notifier/indent/statuscolumn/bigfile/lazygit/bufdelete), trouble and
-- todo-comments. Only what it does not ship, or configures differently, is
-- here.
return {
  -- ── Symbol outline: the navigable stand-in for a minimap ────────
  {
    'stevearc/aerial.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    cmd = { 'AerialToggle', 'AerialOpen', 'AerialNavToggle' },
    opts = {
      backends = { 'lsp', 'treesitter', 'markdown', 'man' },
      layout = { default_direction = 'right', min_width = 28 },
      -- Outline whatever window is focused, rather than pinning to the first.
      attach_mode = 'global',
      close_automatic_events = {},
      show_guides = true,
      filter_kind = {
        'Class',
        'Constructor',
        'Enum',
        'Function',
        'Interface',
        'Module',
        'Method',
        'Struct',
      },
    },
  },

  -- ── Breadcrumbs in the winbar ───────────────────────────────────
  {
    'Bekaboo/dropbar.nvim',
    event = 'BufReadPost',
    opts = {},
  },

  -- ── Scrollbar with diagnostic / git / search marks ──────────────
  {
    'lewis6991/satellite.nvim',
    event = 'BufReadPost',
    opts = {
      current_only = false,
      winblend = 0,
      zindex = 40,
      excluded_filetypes = { 'neo-tree', 'aerial', 'trouble', 'toggleterm', 'snacks_dashboard' },
      width = 2,
      handlers = {
        cursor = { enable = true },
        search = { enable = true },
        diagnostic = { enable = true, min_severity = vim.diagnostic.severity.HINT },
        gitsigns = { enable = true },
        marks = { enable = false },
        quickfix = { enable = true },
      },
    },
  },

  -- ── Sticky scroll ───────────────────────────────────────────────
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = 'BufReadPost',
    opts = { max_lines = 4, mode = 'topline', separator = nil },
  },

  -- ── bufferline: label the neo-tree offset like VS Code's sidebar ─
  {
    'akinsho/bufferline.nvim',
    opts = {
      options = {
        offsets = {
          {
            filetype = 'neo-tree',
            text = 'EXPLORER',
            highlight = 'Directory',
            text_align = 'left',
            separator = true,
          },
        },
        diagnostics = 'nvim_lsp',
        show_buffer_close_icons = true,
        separator_style = 'thin',
      },
    },
  },

  -- ── lualine: show which LSP clients are attached ────────────────
  {
    'nvim-lualine/lualine.nvim',
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, {
        function()
          local names = {}
          for _, client in pairs(vim.lsp.get_clients { bufnr = 0 }) do
            names[#names + 1] = client.name
          end
          return #names > 0 and ('  ' .. table.concat(names, ' ')) or ''
        end,
        color = { fg = '#7dcfff' },
      })
      return opts
    end,
  },

  -- ── neo-tree: the previous config's layout, kept ────────────────
  {
    'nvim-neo-tree/neo-tree.nvim',
    opts = {
      close_if_last_window = true,
      popup_border_style = 'rounded',
      enable_git_status = true,
      enable_diagnostics = true,
      sort_case_insensitive = true,
      window = {
        position = 'left',
        width = 30,
        mappings = {
          ['<space>'] = 'none', -- keep <leader> free
          ['l'] = 'open',
          ['h'] = 'close_node',
          -- Cmd+B arrives as <C-S-B> now, not <D-b> -- Ghostty stopped
          -- encoding the Super bit so the chords survive tmux. This is a
          -- BUFFER-LOCAL map, so the global alias in config/keymaps.lua
          -- never gets a chance to translate it; it has to be the real key.
          ['<C-S-B>'] = 'close_window',
          -- Add the highlighted file to the Claude conversation.
          ['<leader>ai'] = function()
            vim.cmd 'ClaudeCodeTreeAdd'
          end,
        },
      },
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = { enabled = true, leave_dirs_open = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_by_name = { '.DS_Store', 'thumbs.db', '.git' },
        },
      },
      source_selector = {
        winbar = true,
        sources = {
          { source = 'filesystem', display_name = '\u{f07b} Files' },
          { source = 'buffers', display_name = '\u{f15b} Open' },
          { source = 'git_status', display_name = '\u{e725} Git' },
        },
      },
    },
  },

  -- LazyVim's dashboard is replaced by the neo-tree-on-start autocmd in
  -- config/autocmds.lua, matching how Cursor opens a folder.
  {
    'folke/snacks.nvim',
    opts = {
      dashboard = { enabled = false },
      -- ui_select routes vim.ui.select through the snacks picker. It is NOT
      -- on by default, and without it `:checkhealth snacks` reports
      --   `vim.ui.select` is not set to `Snacks.picker.select`
      -- and every vim.ui.select caller falls back to Neovim's built-in list
      -- prompt. That matters here specifically because tasks.lua drives the
      -- Flutter flavour picker, the Android app-id prompt, the melos script
      -- picker and the gradle prompt entirely through vim.ui.select/input.
      picker = { ui_select = true },
      input = { enabled = true },
      -- snacks.image needs the kitty graphics protocol, mmdc and pdflatex, none
      -- of which apply here. Note this does NOT quiet `:checkhealth` -- snacks
      -- runs the image health check regardless of `enabled`, so the 3 ERRORs and
      -- 3 WARNINGs about kitty/mmdc/tectonic are expected and can be ignored.
      -- The setting is kept because it stops the module doing work at runtime,
      -- not because it silences health output.
      image = { enabled = false },
    },
  },
}
