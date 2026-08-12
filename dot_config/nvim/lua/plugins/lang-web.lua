-- Web: React / TypeScript, plus React Native.
--
-- The lang.typescript, lang.tailwind and linting.eslint extras already provide
-- vtsls, tailwindcss-language-server, eslint and prettier. This file adds the
-- pieces they do not: JSX tag closing, package.json version hints, colour
-- swatches, emmet, and the React Native task runners.
return {
  -- Auto-close and auto-rename JSX/HTML tags.
  { 'windwp/nvim-ts-autotag', event = 'BufReadPost', opts = {} },

  -- Inline version / outdated hints in package.json.
  {
    'vuki656/package-info.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    event = { 'BufRead package.json' },
    opts = { package_manager = 'npm', hide_up_to_date = true },
    keys = {
      { '<leader>cp', function() require('package-info').toggle() end, desc = 'Toggle package versions' },
      { '<leader>cu', function() require('package-info').update() end, desc = 'Update package on line' },
    },
  },

  -- Colour swatches for hex/rgb/tailwind classes.
  {
    'catgoose/nvim-colorizer.lua',
    event = 'BufReadPre',
    opts = {
      filetypes = { 'css', 'scss', 'html', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'dart', 'kotlin', 'lua' },
      user_default_options = { tailwind = true, css = true, mode = 'virtualtext', virtualtext = '󱓻' },
    },
  },

  -- emmet for HTML/JSX expansion.
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        emmet_language_server = {
          filetypes = { 'html', 'css', 'scss', 'javascriptreact', 'typescriptreact' },
        },
      },
    },
  },

  -- The React Native task runners (<leader>rn*) live in plugins/tasks.lua,
  -- alongside the Flutter/gradle/melos ones. They have to: lazy.nvim keeps a
  -- single `config` per plugin across specs, so a second toggleterm `config`
  -- here would silently replace the one that defines <leader>rr and friends.
}
