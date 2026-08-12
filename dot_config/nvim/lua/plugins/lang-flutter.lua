-- Dart / Flutter. This is the language the monorepo is actually written in
-- (~7.6k .dart files), so it gets its own file.
--
-- LazyVim ships no Dart/Flutter extra, so this is a plain plugin spec carried
-- over unchanged from the previous config.
--
-- Two things about this repo shape the config:
--   * FVM — there is no `flutter` or `dart` on PATH, and that is deliberate.
--     The SDK lives at .fvm/flutter_sdk, pinned per-project by .fvmrc. A
--     global SDK on PATH would shadow the per-repo pin.
--   * Melos — ~20 packages under packages/, core/ and mobile_apps/, each
--     with its own pubspec.yaml. dartls must root at the *workspace*, not
--     the nearest pubspec, or cross-package goto-definition breaks and you
--     get one analysis server per package.
return {
  {
    'nvim-flutter/flutter-tools.nvim',
    -- ft, not `lazy = false`. It was eager, and that cost ~96ms of every cold
    -- start for nothing: this spec's `config` calls
    -- `require('blink.cmp').get_lsp_capabilities()` below, so loading eagerly
    -- dragged blink.cmp in with it, and blink.cmp in turn pulled
    -- friendly-snippets, vim-dadbod-completion and vim-dadbod -- the last two
    -- despite db.lua gating both on `ft = { 'sql', 'mysql', 'plsql' }`.
    --
    -- Nothing was gained: flutter-tools registers its :Flutter* commands from
    -- setup_commands(), which runs on FileType dart either way. Measured, there
    -- are 0 Flutter commands at a bare start and 27 after opening a .dart
    -- buffer, with or without this line.
    ft = { 'dart' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('flutter-tools').setup {
        fvm = true, -- resolve the SDK through .fvmrc instead of PATH
        -- The default is { '.git', 'pubspec.yaml' }, and the search is
        -- directory-major (utils/path.lua:107) — so walking up from
        -- packages/payment/lib/x.dart stops at that package's own pubspec
        -- and you get ~20 analysis servers with no cross-package
        -- goto-definition. flutter-tools does climb to a *pub* workspace
        -- root, but only when a pubspec declares `resolution: workspace`,
        -- and this repo is melos-without-pub-workspaces. Dropping
        -- pubspec.yaml from the patterns is what pins it to the workspace.
        --
        -- VERIFY AFTER ANY CHANGE: :LspInfo in the monorepo must show
        -- exactly ONE dartls client, not ~20.
        --
        -- Note: passing `root_dir` under `lsp` below would not work —
        -- lsp/init.lua:290 overwrites it from these patterns.
        root_patterns = { 'melos.yaml', '.git' },
        ui = { border = 'rounded', notification_style = 'native' },
        decorations = { statusline = { app_version = false, device = true } },
        widget_guides = { enabled = true },
        closing_tags = { enabled = true, highlight = 'Comment', prefix = '// ' },
        dev_log = { enabled = true, open_cmd = 'botright 15split' },
        dev_tools = { autostart = false, auto_open_browser = false },
        outline = { open_cmd = '30vnew', auto_open = false },
        -- run_via_dap flipped on: nvim-dap now exists (see plugins/dap.lua),
        -- so `:FlutterRun` goes through the debug adapter and breakpoints in
        -- Dart actually stop.
        debugger = {
          enabled = true,
          run_via_dap = true,
          exception_breakpoints = {},
          register_configurations = function(_)
            require('dap').configurations.dart = {}
            require('dap.ext.vscode').load_launchjs()
          end,
        },
        lsp = {
          -- NOTE: no `color` key here, deliberately. flutter-tools' own colour
          -- handling is deprecated on nvim 0.12+, and its deprecation check
          -- (config.lua handle_nested_deprecation) iterates `pairs(value)` —
          -- it fires on the key's mere PRESENCE, so `color = { enabled = false }`
          -- still warns on every startup. The LspAttach hook below opts into
          -- Neovim's built-in vim.lsp.document_color instead.
          capabilities = require('blink.cmp').get_lsp_capabilities({}, true),
          settings = {
            showTodos = false, -- a monorepo this size has hundreds; they drown real diagnostics
            completeFunctionCalls = true,
            enableSnippets = true,
            renameFilesWithClasses = 'prompt',
            updateImportsOnRename = true,
            -- Analysing generated and build output is what makes dartls crawl
            -- on a workspace this size.
            analysisExcludedFolders = {
              vim.fn.expand '$HOME/.pub-cache',
              vim.fn.expand '$HOME/fvm/versions',
              'build',
              '.dart_tool',
              '.fvm',
            },
          },
        },
      }

      -- Colour swatches for Color(0xFF...) literals, via Neovim's own
      -- document-color support rather than flutter-tools' deprecated path.
      if vim.lsp.document_color then
        vim.api.nvim_create_autocmd('LspAttach', {
          group = vim.api.nvim_create_augroup('dart_document_color', { clear = true }),
          callback = function(ev)
            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            if client and client.name == 'dartls' then
              pcall(vim.lsp.document_color.enable, true, ev.buf)
            end
          end,
        })
      end
    end,
  },

  -- Treesitter parsers for the Dart/Android side.
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        'dart',
        'kotlin',
        'java',
        'groovy',
        'xml',
        'swift',
        'objc',
        'proto',
        'http',
        'sql',
      })
      return opts
    end,
  },

  -- ── Per-test running, so you are not waiting on `melos run test:unit-test`
  --    for a single expectation. ─────────────────────────────────────
  {
    'nvim-neotest/neotest',
    dependencies = { 'sidlatau/neotest-dart' },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(
        opts.adapters,
        require 'neotest-dart' {
          command = 'fvm flutter', -- no bare `flutter` on PATH
          use_lsp = true, -- resolve test names via dartls rather than guessing
        }
      )
      opts.output = { open_on_run = false }
      opts.quickfix = { enabled = false } -- trouble.nvim already owns that panel
      return opts
    end,
  },
}
