-- Security work and API probing. Two jobs that share a tool: you need to
-- craft and replay HTTP requests both when building against the Kotlin
-- backend and when testing the app's own network behaviour.
return {
  -- ── Flagged comments as an audit trail ──────────────────────────
  --    The usual TODO/FIX/HACK highlighting, plus SECURITY and AUDIT
  --    keywords so a note left during review becomes a searchable,
  --    jumpable list rather than something you hope to find again.
  --    `SECURITY: token cached in plaintext` → `<leader>fs`.
  --
  --    Glyphs are `\u{}` escapes on purpose: Private-Use-Area characters
  --    get stripped to empty strings when written into these files.
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      signs = true,
      sign_priority = 8,
      -- Merged over the plugin's own TODO/FIX/HACK/WARN/PERF/NOTE/TEST.
      keywords = {
        SECURITY = {
          icon = '\u{f132}', -- shield
          color = 'security',
          alt = { 'VULN', 'CVE', 'INSECURE', 'EXPLOIT' },
        },
        AUDIT = {
          icon = '\u{f0f6}', -- document
          color = 'audit',
          alt = { 'REVIEW', 'VERIFY' },
        },
      },
      colors = {
        security = { '#f14c4c' }, -- same red as a diagnostic error
        audit = { '#cca700' }, -- same amber as a warning
      },
      -- ripgrep needs to know about the new keywords too.
      search = {
        command = 'rg',
        args = { '--color=never', '--no-heading', '--with-filename', '--line-number', '--column' },
        pattern = [[\b(KEYWORDS):]],
      },
    },
  },

  -- ── .http files, executed in-buffer ─────────────────────────────
  --    Replaces the Postman alt-tab. Requests live in the repo as text,
  --    so they diff and review like anything else.
  {
    'mistweaverco/kulala.nvim',
    ft = { 'http', 'rest' },
    keys = {
      { '<leader>hs', desc = 'Send request' },
      { '<leader>ha', desc = 'Send all requests in file' },
      { '<leader>hr', desc = 'Replay last request' },
      { '<leader>ht', desc = 'Toggle body / headers view' },
      { '<leader>he', desc = 'Pick environment' },
      { '<leader>hc', desc = 'Copy as curl' },
    },
    opts = {
      global_keymaps = false, -- set them explicitly below, under <leader>h
      default_view = 'body',
      default_env = 'dev',
      -- Requests go out from your machine to whatever host the file names;
      -- keep that explicit rather than silently following redirects.
      additional_curl_options = { '--max-time', '30' },
    },
    config = function(_, opts)
      require('kulala').setup(opts)
      local k = require 'kulala'
      local map = vim.keymap.set
      map('n', '<leader>hs', k.run, { desc = 'Send request' })
      map('n', '<leader>ha', k.run_all, { desc = 'Send all requests in file' })
      map('n', '<leader>hr', k.replay, { desc = 'Replay last request' })
      map('n', '<leader>ht', k.toggle_view, { desc = 'Toggle body / headers view' })
      map('n', '<leader>he', k.set_selected_env, { desc = 'Pick environment' })
      map('n', '<leader>hc', k.copy, { desc = 'Copy as curl' })
    end,
  },

  -- :Semgrep, :Gitleaks, :Trivy, :OsvScan and the APK commands all live in
  -- plugins/scanners.lua. They must share a single `init` function: lazy.nvim
  -- keeps only ONE `init` per plugin across specs, so two files both attaching
  -- an `init` to trouble.nvim would silently drop one set of commands.
}
