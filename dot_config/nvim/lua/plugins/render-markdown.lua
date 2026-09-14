-- ╭──────────────────────────────────────────────────────────────╮
-- │  render-markdown.nvim -- markdown as it will actually look,    │
-- │  not its raw syntax: headings, checkboxes, tables, code fences │
-- │  all render inline. Pairs with zk (dot_config/zk/config.toml)  │
-- │  for the notes workflow; diagram.nvim (own file) handles the   │
-- │  one thing this plugin does not -- fenced diagrams as images.  │
-- ╰──────────────────────────────────────────────────────────────╯
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      completions = { lsp = { enabled = true } },
    },
    keys = {
      { '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', ft = 'markdown', desc = 'Toggle rendered markdown' },
    },
  },
}
