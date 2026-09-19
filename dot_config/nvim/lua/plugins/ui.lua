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
        -- The two sidebar panels under the explorer (util/bufferlist.lua,
        -- util/shelllist.lua): a scrollbar on a 2-12 line list is noise.
        'bufferlist',
        'shelllist',
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
  -- The horizontal tabline is replaced by the vertical OPEN EDITORS panel
  -- docked under the explorer (util/bufferlist.lua) and never drawn
  -- (`showtabline = 0`, permanently -- see CLAUDE.md's rationale). bufferline
  -- itself stays loaded because BufferLineCycleNext/Prev still drive the
  -- buffer-cycle keys -- ours (Tab/Shift-Tab, Cmd-Shift-[/]) and LazyVim's own
  -- defaults (S-h/S-l, [b/]b, <leader>bp etc, lazyvim/plugins/ui.lua).
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
          -- encoding the Super bit so the chords survive the multiplexer
          -- (measured against tmux; see config/keymaps.lua). This is a
          -- BUFFER-LOCAL map, so the global alias in config/keymaps.lua
          -- never gets a chance to translate it; it has to be the real key.
          ['<C-S-B>'] = 'close_window',
          -- Add the highlighted file to the Claude conversation.
          ['<leader>ai'] = function()
            vim.cmd 'ClaudeCodeTreeAdd'
          end,
          -- Source switching used to live in source_selector's winbar tabs;
          -- that's now the permanent ' EXPLORER' label instead (see
          -- config/autocmds.lua), so switching moved to these two keys.
          ['<leader>ef'] = function()
            vim.cmd 'Neotree source=filesystem'
          end,
          ['<leader>eg'] = function()
            vim.cmd 'Neotree source=git_status'
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
      -- No source_selector: its winbar tabs ('buffers' dropped for the
      -- permanent OPEN EDITORS panel below; Files/Git dropped too) are
      -- replaced by the static ' EXPLORER' label in config/autocmds.lua --
      -- switching source is now <leader>ef/<leader>eg above.
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
