-- Security scanners, on demand.
--
-- security.lua already implements `:Semgrep` in this shape: shell out, parse
-- JSON, build a quickfix list, open it in Trouble. That pattern is factored
-- out here and reused for gitleaks, trivy and osv-scanner, plus the APK tools.
--
-- All of these are deliberately NOT wired into nvim-lint or format-on-save: a
-- scan over this monorepo takes seconds and would stall every write.
--
--   :Gitleaks       secrets in the working tree (and history with !)
--   :Trivy          dependency vulnerabilities + misconfig + secrets
--   :OsvScan        OSV advisories for the lockfiles
--   :ApkDecompile   jadx an APK into a scratch dir and open it
--   :ApkManifest    apktool an APK's manifest into an XML buffer

--- Run `cmd`, hand its JSON to `parse`, and show the resulting items in Trouble.
---
--- Set `report = true` when the tool only writes its report to a file. gitleaks
--- is the case in point: `--report-path /dev/stdout` produces zero bytes
--- (verified), so it must write to a real path that is read back afterwards.
--- The literal string 'REPORT' anywhere in `cmd` is replaced with that path.
---
--- @param opts table {name, cmd, parse, cwd?, report?}
local function scan(opts)
  local exe = opts.cmd[1]
  if vim.fn.executable(exe) == 0 then
    vim.notify(('%s not installed — brew install %s'):format(exe, exe), vim.log.levels.ERROR)
    return
  end

  local root = opts.cwd or vim.fs.root(0, { '.git' }) or vim.uv.cwd()

  local report
  local cmd = vim.deepcopy(opts.cmd)
  if opts.report then
    report = vim.fn.tempname()
    for i, a in ipairs(cmd) do
      if a == 'REPORT' then
        cmd[i] = report
      end
    end
  end

  vim.notify(opts.name .. ' scanning ' .. vim.fn.fnamemodify(root, ':~') .. '…', vim.log.levels.INFO)

  vim.system(
    cmd,
    { text = true, cwd = root },
    vim.schedule_wrap(function(out)
      local raw = out.stdout or ''
      if report then
        local fd = io.open(report, 'r')
        if fd then
          raw = fd:read '*a'
          fd:close()
        end
        os.remove(report)
      end

      -- Most of these exit non-zero *because* they found something, so the
      -- exit code is not a usable success signal; the parse result is.
      if vim.trim(raw) == '' then
        -- No report at all is only "clean" if the tool actually ran.
        if out.code ~= 0 and out.code ~= 1 then
          vim.notify(
            ('%s failed (exit %d):\n%s'):format(opts.name, out.code, out.stderr or ''),
            vim.log.levels.ERROR
          )
        else
          vim.notify(opts.name .. ': clean', vim.log.levels.INFO)
        end
        return
      end

      local ok, items = pcall(opts.parse, raw, root)
      if not ok then
        vim.notify(
          ('%s produced no parseable output:\n%s'):format(opts.name, out.stderr or tostring(items)),
          vim.log.levels.ERROR
        )
        return
      end
      if not items or #items == 0 then
        vim.notify(opts.name .. ': clean', vim.log.levels.INFO)
        return
      end
      vim.fn.setqflist({}, ' ', { title = opts.name, items = items })
      vim.cmd 'Trouble qflist toggle'
      vim.notify(('%s: %d finding(s)'):format(opts.name, #items), vim.log.levels.WARN)
    end)
  )
end

--- gitleaks --report-format json emits an array of findings.
local function parse_gitleaks(stdout, root)
  if vim.trim(stdout) == '' then
    return {}
  end
  local parsed = vim.json.decode(stdout)
  local items = {}
  for _, f in ipairs(parsed or {}) do
    items[#items + 1] = {
      filename = vim.fs.joinpath(root, f.File or ''),
      lnum = f.StartLine or 1,
      col = (f.StartColumn or 0) + 1,
      type = 'E',
      -- Never surface the matched secret itself, only the rule and location.
      text = ('[%s] %s'):format(f.RuleID or 'secret', f.Description or 'potential secret'),
    }
  end
  return items
end

--- trivy fs --format json nests results per target.
local function parse_trivy(stdout, root)
  local parsed = vim.json.decode(stdout)
  local items = {}
  for _, result in ipairs((parsed or {}).Results or {}) do
    local target = result.Target or ''
    for _, v in ipairs(result.Vulnerabilities or {}) do
      items[#items + 1] = {
        filename = vim.fs.joinpath(root, target),
        lnum = 1,
        type = (v.Severity == 'CRITICAL' or v.Severity == 'HIGH') and 'E' or 'W',
        text = ('[%s] %s %s → %s  %s'):format(
          v.Severity or '?',
          v.PkgName or '?',
          v.InstalledVersion or '?',
          v.FixedVersion or 'no fix',
          v.VulnerabilityID or ''
        ),
      }
    end
    for _, m in ipairs(result.Misconfigurations or {}) do
      items[#items + 1] = {
        filename = vim.fs.joinpath(root, target),
        lnum = (m.CauseMetadata or {}).StartLine or 1,
        type = 'W',
        text = ('[%s] %s'):format(m.ID or 'misconfig', m.Title or ''),
      }
    end
  end
  return items
end

--- osv-scanner --format json groups by package source.
local function parse_osv(stdout, root)
  local parsed = vim.json.decode(stdout)
  local items = {}
  for _, res in ipairs((parsed or {}).results or {}) do
    local src = (res.source or {}).path or ''
    for _, pkg in ipairs(res.packages or {}) do
      local name = (pkg.package or {}).name or '?'
      local version = (pkg.package or {}).version or '?'
      for _, v in ipairs(pkg.vulnerabilities or {}) do
        items[#items + 1] = {
          filename = vim.fs.joinpath(root, src),
          lnum = 1,
          type = 'W',
          text = ('%s %s — %s: %s'):format(name, version, v.id or '?', (v.summary or ''):gsub('%s+', ' ')),
        }
      end
    end
  end
  return items
end

return {
  {
    'folke/trouble.nvim',
    optional = true,
    -- IMPORTANT: this is the ONLY `init` attached to trouble.nvim. lazy.nvim
    -- keeps a single `init` per plugin across all specs, so every scanner
    -- command has to be registered from here -- including :Semgrep, which was
    -- previously defined in security.lua and got silently dropped when a
    -- second `init` appeared.
    init = function()
      vim.api.nvim_create_user_command('Semgrep', function(c)
        -- Default to the registry's audit rulesets for the languages here.
        local config = c.args ~= '' and c.args or 'p/security-audit'
        scan {
          name = 'semgrep ' .. config,
          -- NOTE: no `--no-git-ignore=false`. That was in the original config
          -- and is invalid — `--no-git-ignore` is a flag and rejects a value,
          -- so semgrep exited 2 with a usage error and produced no output.
          -- Omitting it gives the default behaviour (respect .gitignore),
          -- which is what the flag was reaching for anyway.
          cmd = { 'semgrep', '--config', config, '--json', '--quiet', '.' },
          parse = function(stdout)
            local parsed = vim.json.decode(stdout)
            local items = {}
            for _, r in ipairs((parsed or {}).results or {}) do
              -- semgrep severities are ERROR / WARNING / INFO.
              local sev = (r.extra and r.extra.severity) or 'INFO'
              items[#items + 1] = {
                filename = r.path,
                lnum = r.start and r.start.line or 1,
                col = r.start and r.start.col or 1,
                type = sev == 'ERROR' and 'E' or (sev == 'WARNING' and 'W' or 'I'),
                text = ('[%s] %s'):format(r.check_id or '?', (r.extra and r.extra.message or ''):gsub('%s+', ' ')),
              }
            end
            return items
          end,
        }
      end, { nargs = '?', desc = 'Run semgrep into the problems panel (arg: a --config value)' })

      vim.api.nvim_create_user_command('Gitleaks', function(c)
        -- gitleaks only writes its JSON to --report-path; sending that to
        -- /dev/stdout yields zero bytes, so scan() gives it a real temp file.
        local cmd = {
          'gitleaks', 'detect', '--no-banner', '--redact',
          '--report-format', 'json', '--report-path', 'REPORT',
        }
        if not c.bang then
          -- Default to the working tree; `:Gitleaks!` walks the full history,
          -- which is much slower on a repo this size.
          vim.list_extend(cmd, { '--no-git' })
        end
        scan { name = 'gitleaks', cmd = cmd, parse = parse_gitleaks, report = true }
      end, { bang = true, desc = 'Scan for secrets (! = include git history)' })

      vim.api.nvim_create_user_command('Trivy', function()
        -- Skipping build output is not cosmetic: on a large Flutter monorepo
        -- an unscoped `trivy fs` walks build/, .dart_tool/ and Pods/ and runs
        -- for minutes (measured: over five, before it was interrupted).
        scan {
          name = 'trivy',
          cmd = {
            'trivy', 'fs', '--scanners', 'vuln,secret,misconfig',
            '--format', 'json', '--quiet',
            '--skip-dirs', 'build,.dart_tool,.fvm,Pods,node_modules,.gradle,DerivedData',
            '.',
          },
          parse = parse_trivy,
        }
      end, { desc = 'Scan dependencies and config for vulnerabilities' })

      vim.api.nvim_create_user_command('OsvScan', function()
        scan {
          name = 'osv-scanner',
          cmd = { 'osv-scanner', 'scan', 'source', '-r', '--format', 'json', '.' },
          parse = parse_osv,
        }
      end, { desc = 'Scan lockfiles against the OSV database' })

      -- ── APK tooling ─────────────────────────────────────────────
      vim.api.nvim_create_user_command('ApkDecompile', function(c)
        local apk = c.args ~= '' and c.args or vim.api.nvim_buf_get_name(0)
        if not apk:match '%.apk$' then
          vim.notify('ApkDecompile: give a path to a .apk', vim.log.levels.ERROR)
          return
        end
        if vim.fn.executable 'jadx' == 0 then
          vim.notify('jadx not installed — brew install jadx', vim.log.levels.ERROR)
          return
        end
        -- Output goes to a scratch dir, never into the current repo.
        local out = vim.fs.joinpath(vim.fn.stdpath 'cache', 'apk', vim.fn.fnamemodify(apk, ':t:r'))
        vim.fn.mkdir(out, 'p')
        vim.notify('jadx → ' .. out .. ' …', vim.log.levels.INFO)
        vim.system(
          { 'jadx', '--no-debug-info', '--output-dir', out, apk },
          { text = true },
          vim.schedule_wrap(function()
            -- jadx routinely exits non-zero on partial decompilation, which is
            -- still useful output, so open whatever landed.
            if vim.uv.fs_stat(out) then
              vim.cmd('Neotree dir=' .. vim.fn.fnameescape(out) .. ' reveal')
              vim.notify('decompiled → ' .. out, vim.log.levels.INFO)
            else
              vim.notify('jadx produced no output', vim.log.levels.ERROR)
            end
          end)
        )
      end, { nargs = '?', complete = 'file', desc = 'Decompile an APK with jadx and open it' })

      vim.api.nvim_create_user_command('ApkManifest', function(c)
        local apk = c.args ~= '' and c.args or vim.api.nvim_buf_get_name(0)
        if vim.fn.executable 'apktool' == 0 then
          vim.notify('apktool not installed — brew install apktool', vim.log.levels.ERROR)
          return
        end
        local out = vim.fs.joinpath(vim.fn.stdpath 'cache', 'apk', vim.fn.fnamemodify(apk, ':t:r') .. '-res')
        vim.notify('apktool → ' .. out .. ' …', vim.log.levels.INFO)
        vim.system(
          { 'apktool', 'd', '-f', '-s', '-o', out, apk },
          { text = true },
          vim.schedule_wrap(function(res)
            local manifest = vim.fs.joinpath(out, 'AndroidManifest.xml')
            if vim.uv.fs_stat(manifest) then
              vim.cmd('edit ' .. vim.fn.fnameescape(manifest))
            else
              vim.notify('apktool failed:\n' .. (res.stderr or ''), vim.log.levels.ERROR)
            end
          end)
        )
      end, { nargs = '?', complete = 'file', desc = 'Extract an APK manifest and open it' })
    end,
  },

  -- Hex view, for looking at binaries and certificates in place.
  {
    'RaafatTurki/hex.nvim',
    cmd = { 'HexDump', 'HexAssemble', 'HexToggle' },
    opts = {},
  },
}
