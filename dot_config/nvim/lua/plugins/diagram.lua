-- ╭──────────────────────────────────────────────────────────────╮
-- │  diagram.nvim + image.nvim -- render fenced diagrams inline    │
-- │                                                                │
-- │  image.nvim does the actual drawing (Kitty graphics protocol,  │
-- │  which Ghostty speaks); diagram.nvim finds fenced code blocks  │
-- │  in markdown and shells out to a renderer per language. Both   │
-- │  own the same "one config" slot -- neither is set up anywhere  │
-- │  else in this repo, so no lazy.nvim ownership conflict.        │
-- │                                                                │
-- │  Config shape verified against the upstream READMEs            │
-- │  (github.com/3rd/diagram.nvim, github.com/3rd/image.nvim)      │
-- │  rather than guessed.                                          │
-- │                                                                │
-- │  d2 (Brewfile, baseline) and plantuml (Brewfile.optional's      │
-- │  `arch` group -- `brewopt arch`) are the two renderers this     │
-- │  repo actually has binaries for. mermaid needs `mmdc`           │
-- │  (mermaid-cli) and gnuplot needs `gnuplot`, neither installed   │
-- │  by this repo; those two integrations will simply error on use │
-- │  until/unless someone adds them.                                │
-- ╰──────────────────────────────────────────────────────────────╯
return {
  {
    '3rd/image.nvim',
    -- Loaded by diagram.nvim's dependency below, not lazy-loaded
    -- independently -- markdown files need it as soon as they open.
    opts = {
      backend = 'kitty',
      integrations = {
        markdown = {
          enabled = true,
          only_render_image_at_cursor = false,
        },
      },
      max_height_window_percentage = 50,
    },
  },
  {
    '3rd/diagram.nvim',
    ft = { 'markdown' },
    dependencies = { '3rd/image.nvim' },
    -- `config`, not `opts`: `require('diagram.integrations.markdown')` has
    -- to run AFTER lazy.nvim loads the plugin, not while it is merely
    -- reading this spec table at startup -- an `opts` table is evaluated
    -- immediately, before diagram.nvim is even on the runtimepath, which
    -- errored with "module 'diagram.integrations.markdown' not found"
    -- (caught by `nvim --headless -c luafile` on this very file).
    config = function()
      require('diagram').setup {
        integrations = {
          require 'diagram.integrations.markdown',
        },
        renderer_options = {
          d2 = {
            theme_id = nil, -- upstream default
          },
          plantuml = {
            charset = 'utf-8',
          },
        },
      }
    end,
    keys = {
      -- Manual view, independent of the automatic render-on-InsertLeave
      -- behaviour -- useful when a diagram fails to auto-render or you just
      -- want it bigger, in its own tab.
      {
        '<leader>cd',
        function()
          require('diagram').show_diagram_hover()
        end,
        ft = 'markdown',
        desc = 'Show diagram in new tab',
      },
    },
  },
}
