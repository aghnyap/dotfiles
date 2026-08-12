-- Database client, for the Kotlin backend side.
--
-- dadbod keeps connection strings out of the config: define them in the
-- environment or in a .env picked up by direnv, e.g.
--   export DBUI_URL_local='postgres://user@127.0.0.1:5432/appdb'
-- and never commit a URL containing a password.
return {
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      { 'tpope/vim-dadbod', lazy = true },
      { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    },
    cmd = { 'DBUI', 'DBUIToggle', 'DBUIAddConnection', 'DBUIFindBuffer' },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1
      -- Saved queries live in the repo-agnostic data dir, not in a project.
      vim.g.db_ui_save_location = vim.fn.stdpath 'data' .. '/db_ui'
      -- Do not write connection URLs into the buffer name / session files.
      vim.g.db_ui_hide_schemas = { 'pg_catalog', 'information_schema' }
    end,
    keys = {
      { '<leader>D', '<cmd>DBUIToggle<cr>', desc = 'Database UI' },
    },
  },

  -- protobuf: the `proto` parser was already installed but had no language
  -- server, so .proto files had highlighting and nothing else.
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        buf_ls = {},
      },
    },
  },
}
