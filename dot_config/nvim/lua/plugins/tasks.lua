-- Running things: the melos scripts that are this repo's real build
-- interface, plus the two long-lived terminals (app + logcat) you otherwise
-- keep in separate Ghostty tabs.
--
-- The Android app id and flavour are read out of android/app/build.gradle
-- rather than hardcoded, and both stay overridable:
--
--   vim.g.android_app_id = 'com.example.app'   -- skip detection entirely
--   vim.g.android_flavor = 'staging'           -- skip the flavour prompt
--   :AndroidAppId [id]                         -- set/clear at runtime
--   :AndroidFlavor [name]                      -- set/clear at runtime
--
-- All of this hangs off toggleterm, which editor.lua already configures.
return {
  {
    'akinsho/toggleterm.nvim',
    optional = true, -- extend the spec in editor.lua rather than redefine it
    -- These are defined in `config` below, so without stubs here they would
    -- not exist until you had already pressed one of the keys.
    cmd = { 'AndroidAppId', 'AndroidFlavor', 'Logcat' },
    keys = {
      { '<leader>rr', desc = 'Run Flutter app' },
      { '<leader>rl', desc = 'adb logcat' },
      { '<leader>rL', desc = 'Logcat panel (filterable)' },
      { '<leader>rm', desc = 'Run a melos script' },
      { '<leader>rg', desc = 'Gradle (Android)' },
      { '<leader>ra', desc = 'Set Android app id' },
      { '<leader>rf', desc = 'Set Android flavour' },
      { '<leader>rnm', desc = 'Metro bundler' },
      { '<leader>rni', desc = 'RN run-ios' },
      { '<leader>rna', desc = 'RN run-android' },
      { '<leader>rnp', desc = 'pod install' },
      { '<leader>rnc', desc = 'Reset Metro cache' },
    },
    config = function(_, opts)
      require('toggleterm').setup(opts)

      local Terminal = require('toggleterm.terminal').Terminal
      local adb = vim.fn.expand '$HOME/Library/Android/sdk/platform-tools/adb'

      local function repo_root()
        return vim.fs.root(0, { 'melos.yaml', '.git' }) or vim.uv.cwd()
      end

      -- ── android/app/build.gradle ──────────────────────────────────
      --    Globbed rather than searched: a downward vim.fs.find over a repo
      --    this size walks every build/ directory too.
      local function gradle_file()
        local root = repo_root()
        for _, pat in ipairs {
          root .. '/android/app/build.gradle',
          root .. '/android/app/build.gradle.kts',
          root .. '/mobile_apps/*/android/app/build.gradle',
          root .. '/mobile_apps/*/android/app/build.gradle.kts',
        } do
          local hit = vim.fn.glob(pat, false, true)[1]
          if hit then
            return hit
          end
        end
      end

      -- Returns the base applicationId and { flavour = suffix } pairs.
      -- Suffixes may be '' — `production` here declares no suffix.
      local parsed
      local function parse_gradle()
        if parsed ~= nil then
          return parsed
        end
        local file = gradle_file()
        if not file then
          parsed = false
          return parsed
        end

        local base, flavors = nil, {}
        local in_flavors, depth, current = false, 0, nil
        for line in io.lines(file) do
          if not base then
            base = line:match 'applicationId%s*=?%s*["\']([%w%.%_]+)["\']'
          end
          if line:match 'productFlavors%s*{' then
            in_flavors, depth = true, 1
          elseif in_flavors then
            -- Track braces so a nested block cannot be mistaken for a flavour.
            local name = line:match '^%s*([%w_]+)%s*{%s*$'
            if name and depth == 1 then
              current = name
              flavors[current] = flavors[current] or ''
            end
            depth = depth + select(2, line:gsub('{', '')) - select(2, line:gsub('}', ''))
            if current then
              local suffix = line:match 'applicationIdSuffix%s*=?%s*["\']([%w%.%_]+)["\']'
              if suffix then
                flavors[current] = suffix
              end
            end
            if depth <= 0 then
              in_flavors = false
            end
          end
        end

        parsed = base and { base = base, flavors = flavors, file = file } or false
        return parsed
      end

      -- ── flavour ───────────────────────────────────────────────────
      local function flavor_names()
        local g = parse_gradle()
        if not g then
          return {}
        end
        local names = vim.tbl_keys(g.flavors)
        table.sort(names)
        return names
      end

      local function with_flavor(cb)
        if vim.g.android_flavor then
          return cb(vim.g.android_flavor)
        end
        local names = flavor_names()
        if #names == 0 then
          return cb(nil) -- no productFlavors block; run without --flavor
        end
        vim.ui.select(names, { prompt = 'Flutter flavour' }, function(choice)
          if not choice then
            return
          end
          vim.g.android_flavor = choice
          cb(choice)
        end)
      end

      -- ── app id ────────────────────────────────────────────────────
      --    base applicationId + the selected flavour's applicationIdSuffix.
      local function with_app_id(cb)
        if vim.g.android_app_id then
          return cb(vim.g.android_app_id)
        end
        local g = parse_gradle()
        if not g then
          return vim.ui.input({ prompt = 'Android app id: ' }, function(id)
            if id and id ~= '' then
              vim.g.android_app_id = id
              cb(id)
            end
          end)
        end
        with_flavor(function(flavor)
          local id = g.base .. (flavor and g.flavors[flavor] or '')
          -- Confirm rather than assume: the suffix only covers the flavour
          -- dimension, and a build type can add another one.
          vim.ui.input({ prompt = 'Android app id: ', default = id }, function(answer)
            if answer and answer ~= '' then
              vim.g.android_app_id = answer
              cb(answer)
            end
          end)
        end)
      end

      vim.api.nvim_create_user_command('AndroidAppId', function(c)
        if c.args == '' then
          vim.g.android_app_id = nil -- clear, so the next use re-detects
          vim.notify('Android app id cleared — will re-detect from build.gradle')
        else
          vim.g.android_app_id = c.args
          vim.notify('Android app id: ' .. c.args)
        end
      end, { nargs = '?', desc = 'Set the Android app id (no arg clears it)' })

      vim.api.nvim_create_user_command('AndroidFlavor', function(c)
        if c.args == '' then
          vim.g.android_flavor = nil
          vim.notify 'Android flavour cleared'
        else
          vim.g.android_flavor = c.args
          vim.notify('Android flavour: ' .. c.args)
        end
      end, {
        nargs = '?',
        complete = flavor_names,
        desc = 'Set the Flutter flavour (no arg clears it)',
      })

      -- ── terminals ─────────────────────────────────────────────────
      local terms = {}
      local function run(key, cmd, dir)
        -- Reuse the named terminal so scrollback survives a toggle, but
        -- rebuild it when the command changes (a different flavour).
        if terms[key] and terms[key].cmd ~= cmd then
          terms[key]:shutdown()
          terms[key] = nil
        end
        terms[key] = terms[key]
          or Terminal:new {
            cmd = cmd,
            dir = dir,
            direction = 'horizontal',
            close_on_exit = false, -- leave the failure on screen
            hidden = true,
          }
        terms[key]:toggle()
      end

      local map = vim.keymap.set

      map('n', '<leader>rr', function()
        with_flavor(function(flavor)
          -- `flutter` is not on PATH; FVM resolves it from .fvmrc.
          local cmd = 'fvm flutter run' .. (flavor and (' --flavor ' .. flavor) or '')
          run('app', cmd, repo_root())
        end)
      end, { desc = 'Run Flutter app' })

      map('n', '<leader>rl', function()
        with_app_id(function(id)
          -- Resolve the pid up front so an unfiltered logcat is a conscious
          -- fallback rather than a silent `--pid=0` showing nothing.
          local ok, res = pcall(function()
            return vim.system({ adb, 'shell', 'pidof', '-s', id }, { text = true }):wait(5000)
          end)
          local pid = ok and res.code == 0 and vim.trim(res.stdout or '') or ''
          if pid == '' then
            vim.notify(id .. ' is not running — showing unfiltered logcat', vim.log.levels.WARN)
            run('logcat', adb .. " logcat '*:W'")
          else
            run('logcat', adb .. ' logcat --pid=' .. pid)
          end
        end)
      end, { desc = 'adb logcat' })

      -- ── logcat as a readable panel ────────────────────────────────
      -- `<leader>rl` above is the raw stream in a terminal, kept because it
      -- is the right tool for "just watch it scroll". This is the other one:
      -- a real buffer you can filter retroactively and jump out of into the
      -- source. See lua/util/logcat.lua.
      map('n', '<leader>rL', function()
        with_app_id(function(id)
          require('util.logcat').toggle(id)
        end)
      end, { desc = 'Logcat panel (filterable)' })

      vim.api.nvim_create_user_command('Logcat', function(c)
        if c.args ~= '' then
          require('util.logcat').start(c.args)
        else
          with_app_id(function(id)
            require('util.logcat').start(id)
          end)
        end
      end, { nargs = '?', desc = 'Stream adb logcat into a filterable panel' })

      map('n', '<leader>ra', '<cmd>AndroidAppId<cr>', { desc = 'Clear/re-detect Android app id' })
      map('n', '<leader>rf', function()
        vim.g.android_flavor = nil
        with_flavor(function(f)
          vim.notify('Flavour: ' .. tostring(f))
        end)
      end, { desc = 'Set Android flavour' })

      -- ── melos script picker ───────────────────────────────────────
      --    melos.yaml is the source of truth for build/test/codegen in this
      --    repo (lint:analyze, test:unit-test, codegen:build-runner, ...).
      map('n', '<leader>rm', function()
        local root = vim.fs.find('melos.yaml', { path = vim.uv.cwd(), upward = true })[1]
        if not root then
          vim.notify('No melos.yaml above the cwd', vim.log.levels.WARN)
          return
        end

        -- Collect the keys nested one level under `scripts:`. A real YAML
        -- parse would be better, but melos.yaml is hand-written and flat
        -- enough that indentation is a reliable signal.
        local scripts, in_scripts = {}, false
        for line in io.lines(root) do
          if line:match '^scripts:' then
            in_scripts = true
          elseif in_scripts then
            if line:match '^%S' then
              break -- dedented back to a top-level key
            end
            local name = line:match '^  ([%w_:%-]+):%s*$'
            if name then
              scripts[#scripts + 1] = name
            end
          end
        end

        if #scripts == 0 then
          vim.notify('No scripts found in ' .. root, vim.log.levels.WARN)
          return
        end

        vim.ui.select(scripts, { prompt = 'melos run' }, function(choice)
          if choice then
            -- melos comes from `dart pub global activate`, not Homebrew, and this
            -- repo installs it nowhere -- Dart is deliberately off PATH so FVM's
            -- per-repo pin always wins. Say so instead of opening a terminal whose
            -- first line is `melos: command not found`.
            if vim.fn.executable 'melos' == 0 then
              vim.notify(
                'melos is not installed.\nInstall it with:  fvm dart pub global activate melos',
                vim.log.levels.WARN
              )
              return
            end
            run('melos', 'melos run ' .. choice, vim.fs.dirname(root))
          end
        end)
      end, { desc = 'Run a melos script' })

      -- ── gradle ────────────────────────────────────────────────────
      map('n', '<leader>rg', function()
        local file = gradle_file()
        local dir = file and vim.fs.dirname(vim.fs.dirname(file)) -- .../android
        if not dir or not vim.uv.fs_stat(dir .. '/gradlew') then
          vim.notify('No gradlew found', vim.log.levels.WARN)
          return
        end
        vim.ui.input({ prompt = './gradlew ', default = 'tasks' }, function(args)
          if args then
            run('gradle', './gradlew ' .. args, dir)
          end
        end)
      end, { desc = 'Gradle (Android)' })

      -- ── React Native ──────────────────────────────────────────────
      --    Same named-terminal pattern as the Flutter/gradle runners above.
      --    These live here rather than in lang-web.lua because lazy.nvim
      --    keeps only one `config` per plugin: a second toggleterm `config`
      --    in another file would silently replace this whole function.
      local function rn_root()
        return vim.fs.root(0, { 'package.json', '.git' }) or vim.uv.cwd()
      end

      map('n', '<leader>rnm', function()
        run('metro', 'npx react-native start', rn_root())
      end, { desc = 'Metro bundler' })
      map('n', '<leader>rni', function()
        run('rn-ios', 'npx react-native run-ios', rn_root())
      end, { desc = 'RN run-ios' })
      map('n', '<leader>rna', function()
        run('rn-android', 'npx react-native run-android', rn_root())
      end, { desc = 'RN run-android' })
      map('n', '<leader>rnp', function()
        run('pods', 'pod install --repo-update', rn_root() .. '/ios')
      end, { desc = 'pod install' })
      map('n', '<leader>rnc', function()
        -- The Metro/haste caches are the usual cause of phantom RN failures.
        -- watchman is not installed by this repo (it is in `brewopt extras`), and
        -- the cache reset is still worth running without it -- so call it only if
        -- it exists rather than opening a terminal that leads with a
        -- `command not found`.
        run(
          'metro',
          'if command -v watchman >/dev/null 2>&1; then watchman watch-del-all; '
            .. 'else echo "watchman not installed (brewopt extras) -- skipping watch-del-all"; fi; '
            .. 'rm -rf $TMPDIR/metro-* $TMPDIR/haste-map-*; npx react-native start --reset-cache',
          rn_root()
        )
      end, { desc = 'Reset Metro cache and restart' })
    end,
  },
}
