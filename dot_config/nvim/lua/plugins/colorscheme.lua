-- Tokyo Night (night) -- the same palette as Ghostty, tmux, fzf, bat, delta,
-- lazygit and btop. See ~/.config/ghostty/config.
--
-- tokyonight is LazyVim's default colorscheme, so this only pins the style and
-- re-applies the handful of highlight overrides that the previous config had.
-- Those overrides were written against the VS Code Dark Modern palette and are
-- re-derived here from Tokyo Night's own colours rather than copied.
return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = {
      style = 'night',
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = false },
        sidebars = 'dark',
        floats = 'dark',
      },
      -- Dim inactive windows slightly, mirroring Ghostty's
      -- unfocused-split-opacity.
      dim_inactive = true,
      lualine_bold = false,
      on_colors = function(c)
        c.border = c.blue7
      end,
      on_highlights = function(hl, c)
        -- Separators and gutter: the defaults are too low-contrast against a
        -- 0.95-opacity background.
        hl.WinSeparator = { fg = c.bg_highlight, bold = false }
        hl.LineNr = { fg = c.dark3 }
        hl.CursorLineNr = { fg = c.orange, bold = true }

        -- Floats: match Ghostty's rounded, slightly-lifted panels.
        hl.NormalFloat = { bg = c.bg_dark }
        hl.FloatBorder = { fg = c.blue7, bg = c.bg_dark }

        -- Sticky scroll (treesitter-context) should read as a header, not as
        -- another line of code.
        hl.TreesitterContext = { bg = c.bg_highlight }
        hl.TreesitterContextLineNumber = { fg = c.dark3, bg = c.bg_highlight }

        -- Satellite scrollbar handlers, one per signal type.
        hl.SatelliteBar = { bg = c.bg_highlight }
        hl.SatelliteBackground = { bg = 'NONE' }
        hl.SatelliteCursor = { fg = c.fg_dark }
        hl.SatelliteSearch = { fg = c.yellow }
        hl.SatelliteDiagnosticError = { fg = c.error }
        hl.SatelliteDiagnosticWarn = { fg = c.warning }
        hl.SatelliteDiagnosticInfo = { fg = c.info }
        hl.SatelliteDiagnosticHint = { fg = c.hint }
        hl.SatelliteGitSignsAdd = { fg = c.git.add }
        hl.SatelliteGitSignsChange = { fg = c.git.change }
        hl.SatelliteGitSignsDelete = { fg = c.git.delete }
        hl.SatelliteQuickfix = { fg = c.purple }

        -- Snacks indent guides.
        hl.SnacksIndent = { fg = c.bg_highlight }
        hl.SnacksIndentScope = { fg = c.blue7 }
      end,
    },
  },
  {
    'LazyVim/LazyVim',
    opts = { colorscheme = 'tokyonight-night' },
  },
}
