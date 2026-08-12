-- Kotlin / JVM.
--
-- History, because it explains the shape of this file: the previous config
-- installed fwcd's `kotlin_language_server` but deliberately kept it OFF.
-- That server resolves each Gradle module's classpath by shelling out to the
-- Gradle CLI, and on this repo that never completes — the Flutter Android
-- build pulls in ~60 plugin modules, so you get a Gradle daemon per module and
-- no attach after 90 seconds.
--
-- JetBrains released an official Kotlin LSP in 2025 that does not do that. It
-- is the default here. fwcd's server stays installed behind
-- `:KotlinLspLegacy`, because the JetBrains one is still pre-1.0 and its
-- behaviour on a Flutter-embedded Gradle build is exactly what broke last time.
--
-- If neither attaches, treesitter highlighting and ktlint formatting still work
-- on .kt files — that is the floor, and it is unchanged.
--
--   :KotlinLspInstall   download/refresh the JetBrains server
--   :KotlinLspLegacy    switch this session to fwcd's server
return {
  {
    'neovim/nvim-lspconfig',
    -- The two user commands are registered in `init` rather than `opts`:
    -- lspconfig only loads on BufReadPre, so defining them in `opts` would
    -- mean :KotlinLspInstall does not exist until you have already opened a
    -- file -- which is exactly when you need it least.
    init = function()
      vim.api.nvim_create_user_command('KotlinLspLegacy', function()
        vim.lsp.enable('kotlin_lsp', false)
        -- The root markers live here rather than in a persistent `opts.servers`
        -- entry. There used to be one, carrying `enabled = false` -- a server
        -- configured on every startup purely so it could be switched on by this
        -- command. Setting them at switch time keeps the Gradle-root knowledge
        -- (the module dir, NOT the Flutter workspace root, or you get one Gradle
        -- daemon per module) without the permanent dead spec.
        --
        -- Needs the binary: `:MasonInstall kotlin-language-server`. It is not in
        -- Mason's ensure_installed, because this is a fallback, not the default.
        vim.lsp.config('kotlin_language_server', {
          root_markers = { 'settings.gradle', 'settings.gradle.kts', 'gradlew', 'build.gradle' },
        })
        vim.lsp.enable 'kotlin_language_server'
        vim.notify(
          'Switched to fwcd kotlin_language_server — first attach waits on Gradle',
          vim.log.levels.INFO
        )
        vim.cmd 'edit' -- re-trigger FileType so the current buffer attaches
      end, { desc = 'Fall back to fwcd’s Kotlin LSP' })

      vim.api.nvim_create_user_command('KotlinLspInstall', function()
        local script = vim.fn.stdpath 'config' .. '/scripts/install-kotlin-lsp.sh'
        vim.notify('Installing JetBrains kotlin-lsp…', vim.log.levels.INFO)
        vim.system({ 'bash', script }, { text = true }, vim.schedule_wrap(function(out)
          if out.code == 0 then
            vim.notify('kotlin-lsp installed — restart Neovim', vim.log.levels.INFO)
          else
            vim.notify(
              'kotlin-lsp install failed:\n' .. ((out.stderr or '') .. (out.stdout or '')),
              vim.log.levels.ERROR
            )
          end
        end))
      end, { desc = 'Download and install the JetBrains Kotlin LSP' })
    end,
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- No kotlin_language_server entry. fwcd's server was declared here with
      -- `enabled = false` -- configured, never used, and 89MB in Mason. The
      -- JetBrains kotlin-lsp registered below is the one that actually runs.
      -- lemminx handles AndroidManifest.xml and res/ layouts.
      opts.servers.lemminx = opts.servers.lemminx or {}

      -- Let LazyVim skip its own setup for fwcd's server entirely.
      -- ── JetBrains kotlin-lsp, registered as its own server so it does
      --    not collide with lspconfig's kotlin_language_server definition.
      -- `kotlin-lsp` is a symlink the installer points at bin/intellij-server
      -- inside the unpacked vsix. Using the symlink means a version bump does
      -- not change this path, and it avoids the deprecated kotlin-lsp.sh
      -- wrapper, which prints a deprecation warning to stderr on every start.
      local kotlin_lsp = vim.fs.normalize(vim.fn.stdpath 'data' .. '/kotlin-lsp/kotlin-lsp')

      vim.lsp.config('kotlin_lsp', {
        cmd = { kotlin_lsp, '--stdio' },
        filetypes = { 'kotlin' },
        root_markers = {
          'settings.gradle',
          'settings.gradle.kts',
          'build.gradle',
          'build.gradle.kts',
          'pom.xml',
        },
      })

      if vim.uv.fs_stat(kotlin_lsp) then
        vim.lsp.enable 'kotlin_lsp'
      else
        vim.api.nvim_create_autocmd('FileType', {
          pattern = 'kotlin',
          once = true,
          callback = function()
            vim.notify(
              'JetBrains kotlin-lsp not installed.\n'
                .. 'Run :KotlinLspInstall, or :KotlinLspLegacy for fwcd’s server.',
              vim.log.levels.WARN
            )
          end,
        })
      end

      return opts
    end,
  },
}
