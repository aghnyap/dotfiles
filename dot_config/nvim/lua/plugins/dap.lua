-- Debugging.
--
-- The previous config had no DAP at all — no breakpoints in any language, and
-- flutter-tools was explicitly set to `run_via_dap = false`. This is the
-- biggest cross-cutting gap being closed.
--
-- The dap.core extra provides nvim-dap, dap-ui, virtual text and mason-nvim-dap.
-- The lang.go and lang.java extras register delve and java-debug themselves.
-- What is added here: the JVM remote-attach configuration that makes Kotlin
-- backend debugging usable, and the JS/Chrome/React Native adapters.
return {
  -- Function keys matching the VS Code vocabulary already in keymaps.lua.
  {
    'mfussenegger/nvim-dap',
    keys = {
      { '<F5>', function() require('dap').continue() end, desc = 'Debug: continue' },
      { '<F9>', function() require('dap').toggle_breakpoint() end, desc = 'Debug: toggle breakpoint' },
      { '<F10>', function() require('dap').step_over() end, desc = 'Debug: step over' },
      { '<F11>', function() require('dap').step_into() end, desc = 'Debug: step into' },
      { '<S-F11>', function() require('dap').step_out() end, desc = 'Debug: step out' },
      {
        '<leader>dA',
        function() require('dap').continue { before = function() end } end,
        desc = 'Attach to JVM (:5005)',
      },
    },
    opts = function()
      local dap = require 'dap'

      -- ── Kotlin / JVM: attach to a running Gradle/Spring process ───
      --    Start the service with `./gradlew bootRun --debug-jvm` (aliased to
      --    `gwdebug` in ~/.config/zsh/dev.zsh); it suspends on :5005 until a
      --    debugger attaches. This is what makes Kotlin backend work viable.
      --
      --    This uses kotlin-debug-adapter, NOT `type = 'java'`. The java
      --    adapter is registered by nvim-jdtls only once jdtls attaches to a
      --    Java buffer -- and the backend repos here are pure Kotlin (0 .java
      --    files), so it never exists. A `type = 'java'` config in a Kotlin
      --    buffer fails with "no adapter", the same silent class of breakage
      --    the JS adapter had.
      local kda = vim.fn.exepath 'kotlin-debug-adapter'
      if kda == '' then
        kda = vim.fn.stdpath 'data' .. '/mason/bin/kotlin-debug-adapter'
      end
      if vim.uv.fs_stat(kda) then
        dap.adapters.kotlin = {
          type = 'executable',
          command = kda,
          options = { auto_continue_if_many_stopped = false },
        }

        dap.configurations.kotlin = dap.configurations.kotlin or {}
        vim.list_extend(dap.configurations.kotlin, {
          {
            type = 'kotlin',
            request = 'attach',
            name = 'Attach to JVM on :5005 (gradlew --debug-jvm)',
            hostName = '127.0.0.1',
            port = 5005,
            timeout = 5000,
            projectRoot = '${workspaceFolder}',
          },
          {
            type = 'kotlin',
            request = 'launch',
            name = 'Launch (needs mainClass)',
            projectRoot = '${workspaceFolder}',
            mainClass = function()
              return vim.fn.input('mainClass > ', vim.g.kotlin_main_class or '', 'file')
            end,
          },
        })
      end

      -- Java keeps LazyVim's jdtls-brokered adapter; it works there because
      -- jdtls is attached whenever you are in a .java buffer.
      dap.configurations.java = dap.configurations.java or {}
      table.insert(dap.configurations.java, {
        type = 'java',
        request = 'attach',
        name = 'Attach to JVM on :5005 (gradlew --debug-jvm)',
        hostName = '127.0.0.1',
        port = 5005,
      })

      -- ── JS / TS / React / React Native ────────────────────────────
      -- The pwa-node / pwa-chrome / pwa-msedge adapters come from LazyVim's
      -- lang.typescript extra; do NOT redefine them here.
      --
      -- A hand-rolled adapter used to live at this spot and it silently broke
      -- debugging: vscode-js-debug's dapDebugServer binds to `::1`, and the
      -- custom definition dialled `127.0.0.1`. The adapter would start, fail
      -- to accept the connection, and exit 0 — so `continue()` just ran the
      -- program to completion and no breakpoint ever hit. Only the dap.log
      -- ("Process exit node 0") made it visible.
      --
      -- Only the *configurations* below are ours; they are additive.
      for _, ft in ipairs { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' } do
        dap.configurations[ft] = dap.configurations[ft] or {}
        vim.list_extend(dap.configurations[ft], {
          {
            type = 'pwa-chrome',
            request = 'attach',
            name = 'Attach to Chrome (React, :9222)',
            port = 9222,
            webRoot = '${workspaceFolder}',
            -- Chrome must be started with --remote-debugging-port=9222.
          },
          {
            type = 'pwa-node',
            request = 'attach',
            name = 'Attach to React Native (Hermes, :8081)',
            port = 8081,
            cwd = '${workspaceFolder}',
            sourceMaps = true,
          },
          {
            type = 'pwa-node',
            request = 'launch',
            name = 'Launch this file (node)',
            program = '${file}',
            cwd = '${workspaceFolder}',
          },
        })
      end

      -- Breakpoint signs in the Tokyo Night palette.
      local signs = {
        DapBreakpoint = { '', 'DiagnosticError' },
        DapBreakpointCondition = { '', 'DiagnosticWarn' },
        DapLogPoint = { '', 'DiagnosticInfo' },
        DapStopped = { '', 'DiagnosticWarn' },
        DapBreakpointRejected = { '', 'DiagnosticError' },
      }
      for name, sign in pairs(signs) do
        vim.fn.sign_define(name, { text = sign[1], texthl = sign[2], numhl = '' })
      end
    end,
  },

  -- Adapters that Mason can fetch.
  {
    'jay-babu/mason-nvim-dap.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        'js-debug-adapter', -- React / React Native / node
        'codelldb', -- Swift (shared with xcodebuild.nvim)
        'kotlin-debug-adapter', -- Kotlin/JVM attach; see the note above
      })
      return opts
    end,
  },
}
