-- Swift / iOS.
--
-- Previously this domain had nothing at all: no LSP, no parser, no build
-- integration — despite Xcode 26.6, swift, pod and ruby all being installed.
-- For a Flutter app with an iOS half, that was the largest single gap.
--
-- sourcekit-lsp ships inside Xcode, so there is nothing to install: it is
-- located through `xcrun`. If Xcode is absent this file degrades quietly.
return {
  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- Resolve the toolchain's sourcekit-lsp rather than hardcoding a path,
      -- so switching Xcode versions with xcode-select just works.
      local ok, res = pcall(function()
        return vim.system({ 'xcrun', '--find', 'sourcekit-lsp' }, { text = true }):wait(5000)
      end)
      local sourcekit = ok and res.code == 0 and vim.trim(res.stdout or '') or nil

      if sourcekit and sourcekit ~= '' then
        opts.servers.sourcekit = {
          cmd = { sourcekit },
          filetypes = { 'swift', 'objc', 'objcpp', 'c', 'cpp' },
          root_markers = {
            'Package.swift',
            'buildServer.json',
            '*.xcodeproj',
            '*.xcworkspace',
            'compile_commands.json',
            '.git',
          },
          -- clangd (from the lang.clangd extra, if ever enabled) would fight
          -- sourcekit over C/C++/ObjC buffers. sourcekit wins inside an Xcode
          -- project because it understands the build graph.
          capabilities = {
            workspace = {
              didChangeWatchedFiles = { dynamicRegistration = true },
            },
          },
        }
      end

      return opts
    end,
  },

  -- ── Xcode from inside Neovim ────────────────────────────────────
  --    Build, run on a simulator, run tests, and debug through codelldb.
  --    Needs `xcbeautify` and `xcode-build-server` on PATH (brew).
  {
    'wojciech-kulik/xcodebuild.nvim',
    ft = { 'swift', 'objc', 'objcpp' },
    cmd = {
      'XcodebuildSetup',
      'XcodebuildBuild',
      'XcodebuildBuildRun',
      'XcodebuildTest',
      'XcodebuildPicker',
      'XcodebuildSelectDevice',
      'XcodebuildSelectScheme',
      'XcodebuildToggleLogs',
    },
    dependencies = {
      -- telescope needs `lazy = true` spelled out. lazy.nvim's global default
      -- here is `lazy = false` (config/lazy.lua), and this repo uses the
      -- snacks_picker extra rather than the telescope one -- so nothing else
      -- gives telescope a trigger, and it was loading at every startup on a
      -- machine that may never touch Swift. As a dependency of an ft/cmd-gated
      -- plugin it is pulled in on demand anyway.
      { 'nvim-telescope/telescope.nvim', lazy = true },
      'MunifTanjim/nui.nvim',
      'folke/snacks.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      logs = { auto_open_on_success_tests = false, auto_open_on_failed_tests = false },
      code_coverage = { enabled = false },
      show_build_progress_bar = true,
    },
    keys = {
      { '<leader>X', '', desc = '+xcode' },
      { '<leader>Xl', '<cmd>XcodebuildToggleLogs<cr>', desc = 'Toggle Xcode logs' },
      { '<leader>Xb', '<cmd>XcodebuildBuild<cr>', desc = 'Build project' },
      { '<leader>Xr', '<cmd>XcodebuildBuildRun<cr>', desc = 'Build and run' },
      { '<leader>Xt', '<cmd>XcodebuildTest<cr>', desc = 'Run tests' },
      { '<leader>XT', '<cmd>XcodebuildTestClass<cr>', desc = 'Run this test class' },
      { '<leader>XX', '<cmd>XcodebuildPicker<cr>', desc = 'Xcode actions' },
      { '<leader>Xd', '<cmd>XcodebuildSelectDevice<cr>', desc = 'Select device' },
      { '<leader>Xs', '<cmd>XcodebuildSelectScheme<cr>', desc = 'Select scheme' },
      { '<leader>Xc', '<cmd>XcodebuildToggleCodeCoverage<cr>', desc = 'Toggle code coverage' },
    },
  },

  -- swiftformat / swiftlint are brew-installed (Mason does not package them).
  {
    'stevearc/conform.nvim',
    optional = true,
    opts = {
      formatters_by_ft = {
        swift = { 'swiftformat' },
      },
    },
  },
  {
    'mfussenegger/nvim-lint',
    optional = true,
    opts = {
      linters_by_ft = {
        swift = { 'swiftlint' },
      },
    },
  },
}
