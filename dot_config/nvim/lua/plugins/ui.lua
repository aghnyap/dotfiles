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
      excluded_filetypes = {
        'neo-tree',
        'aerial',
        'trouble',
        'toggleterm',
        'snacks_dashboard',
      },
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

  -- ── bufferline: kept only for the Tab/Shift-Tab cycle commands ──
  -- The horizontal tabline is never drawn (`showtabline = 0`, permanently --
  -- see CLAUDE.md's rationale); use neo-tree's Open source for a visual
  -- buffer list. bufferline itself stays loaded because BufferLineCycleNext/
  -- Prev still drive the buffer-cycle keys -- ours (Tab/Shift-Tab,
  -- Cmd-Shift-[/]) and LazyVim's own defaults (S-h/S-l, [b/]b, <leader>bp
  -- etc, lazyvim/plugins/ui.lua).
  {
    'akinsho/bufferline.nvim',
    -- opts is a function, not a table, only so `vim.o.showtabline` gets set
    -- once at setup and the state-keepalive autocmd below gets registered. It
    -- must NOT become `config`: LazyVim already defines one for this plugin
    -- (setup + the BufAdd/BufDelete session-restore fix), and lazy.nvim keeps
    -- a single config per plugin rather than chaining them.
    opts = function(_, opts)
      opts = vim.tbl_deep_extend('force', opts, {
        options = {
          -- Without this, bufferline forces `showtabline` back to 2 on every
          -- BufAdd/BufDelete, fighting the explicit 0 below.
          auto_toggle_bufferline = false,
          -- Without this, every :terminal buffer (toggleterm, the vnew|terminal
          -- fallback in keymaps.lua, snacks terminals) would be cycled through
          -- by BufferLineCycleNext/Prev same as a file buffer.
          custom_filter = function(buf)
            return vim.bo[buf].buftype ~= 'terminal'
          end,
        },
      })
      vim.o.showtabline = 0

      -- Neovim only ever evaluates the 'tabline' option when it would
      -- actually be drawn, so with showtabline permanently 0 bufferline's own
      -- render function -- the thing that populates the buffer list Cycle/
      -- Move commands walk -- never runs, and every cycle key silently does
      -- nothing. Call it ourselves on the same events bufferline would have
      -- redrawn for, purely to keep that internal state fresh; the return
      -- value (the tabline string) is discarded since nothing displays it.
      local pending = false
      vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufEnter' }, {
        group = vim.api.nvim_create_augroup('cursorlike_bufferline_state', { clear = true }),
        callback = function()
          if pending then
            return
          end
          pending = true
          -- BufDelete fires before the buffer leaves the list. Refresh once
          -- the entire change has finished, including any follow-up BufEnter.
          vim.schedule(function()
            pending = false
            if _G.nvim_bufferline then
              pcall(_G.nvim_bufferline)
            end
          end)
        end,
      })

      return opts
    end,
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
      -- config/autocmds.lua owns last-window behavior, including terminals.
      close_if_last_window = false,
      popup_border_style = 'rounded',
      enable_git_status = true,
      enable_diagnostics = true,
      sort_case_insensitive = true,
      commands = {
        -- Use the same terminal deletion as <leader>bd inside its pane:
        -- close the window and stop the job, leaving no replacement buffer.
        kill_buffer = function(state)
          local node = state.tree:get_node()
          if not node or node.type == 'message' then
            return
          end
          local buf = node.extra and node.extra.bufnr
          if not buf or not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          if vim.bo[buf].buftype == 'terminal' then
            require('util.terminal').delete(buf)
          else
            vim.api.nvim_buf_delete(buf, { force = false, unload = false })
          end
          require('neo-tree.sources.manager').refresh 'buffers'
        end,
        -- 'open_drop' still mirrors a terminal buffer into a fresh split
        -- instead of focusing it: get_appropriate_window() (utils/init.lua)
        -- skips any window whose buftype is in open_files_do_not_replace_types
        -- (default includes "terminal") before :drop ever runs, so if the
        -- only other window is that terminal, neo-tree decides there is no
        -- usable window and force-splits the same bufnr right there --
        -- two panes showing the same job. Check for an existing window on
        -- this exact bufnr ourselves, in any tab, before falling back to
        -- open_drop's normal behaviour.
        focus_or_open = function(state, toggle_directory)
          local node = state.tree:get_node()
          if not node or node.type == 'message' then
            return
          end
          local buf = node.extra and node.extra.bufnr
          local winid = buf and vim.fn.win_findbuf(buf)[1]
          if winid then
            vim.api.nvim_set_current_win(winid)
          else
            require('neo-tree.sources.common.commands').open_drop(state, toggle_directory)
          end
        end,
      },
      window = {
        position = 'left',
        width = 30,
        mappings = {
          ['<space>'] = 'none', -- keep <leader> free
          ['l'] = 'open',
          ['h'] = 'close_node',
          -- Cmd+B arrives as <C-S-B> now, not <D-b> -- Ghostty stopped
          -- encoding the Super bit so the chords survive the multiplexer
          -- (measured against tmux; see config/keymaps.lua). This is a
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
      buffers = {
        window = {
          mappings = {
            ['d'] = 'kill_buffer',
            ['bd'] = 'kill_buffer',
            -- Override LazyVim's current-buffer delete while selecting entries.
            ['<leader>bd'] = 'kill_buffer',
            -- The global 'l'/'<cr>' -> 'open' (window.mappings above, plus
            -- neo-tree's own default) always opens via `:edit`/`:buffer` in
            -- the closest content window -- for a buffer already visible in
            -- another window (a toggleterm split, a file already open
            -- side-by-side), that duplicates the display there instead of
            -- switching focus to the window that already has it.
            -- 'focus_or_open' jumps to an existing window showing that
            -- buffer when there is one (including a terminal split, which
            -- plain 'open_drop' cannot -- see its definition above), and
            -- only falls back to opening it when there isn't.
            ['l'] = 'focus_or_open',
            ['<cr>'] = 'focus_or_open',
            ['<2-LeftMouse>'] = 'focus_or_open',
          },
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
