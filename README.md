# dotfiles

Terminal-native development environment: Ghostty + zsh + zellij + LazyVim,
themed Tokyo Night throughout — except the prompt, left at starship's
built-in default. Managed with [chezmoi](https://chezmoi.io).

Covers mobile (Flutter, Android/Kotlin, iOS/Swift, React Native), web
(React/TS), backend (Kotlin/JVM), and mobile/web security work.

**Neovim is the IDE.** GUI editors (Cursor, Android Studio, Xcode) may be
installed when needed, but none is configured here.

## Bootstrap a new machine

```sh
./bootstrap.sh
just apply
```

`bootstrap.sh` installs Homebrew (or `apt` on Ubuntu), `chezmoi`, and `just`
— nothing else, no flags, idempotent. `just apply` runs `chezmoi apply`
(the Brewfile, every config file, macOS defaults) then `just plugins` (nvim
plugin restore, the bat theme cache).

No identity is asked for or stored — every machine on a platform gets the
same config. Git identity, VPN helpers, and per-project SDK pins live
outside the repo; see CLAUDE.md's ownership table for where. Maintainer
checks live behind `just check`, `just diff`, `just pre-push` — see
`just --list` for the rest.

Moving an existing setup to another machine: see [INSTALL.md](INSTALL.md).

## Layout

| Path | What |
| --- | --- |
| `dot_zshenv` | Toolchain PATH/env for all shells |
| `dot_zshrc` | Interactive shell entry point; loads `dot_config/zsh/` modules |
| `dot_config/zsh/` | Shell modules: `aliases functions dev sec fzf tools csiu d2 zellij` (+ `git-aliases` fallback) |
| `dot_config/nvim/` | LazyVim + custom plugin specs — see `tldr dotfiles-nvim` |
| `dot_config/zellij/` | `config.kdl` + per-project layouts (mobile/web/backend/sec/arch) |
| `dot_aider.conf.yml`, `dot_aider.model.settings.yml`, `dot_aider.model.metadata.json` | aider's local-model config — no credentials |
| `dot_claude/skills/` | Claude Code skills (`d2-architect`) — the only managed path under `~/.claude` |
| `dot_config/ghostty/config` | Font, theme, the Cmd-chord forwards Neovim depends on |
| `dot_config/git/config` | git pager/editor/delta theme (`~/.gitconfig` holds identity, unmanaged) |
| `starship-powerline.toml` | Optional Tokyo Night palette variant for starship — swap in per the comment in `dot_config/starship.toml` |
| `.chezmoitemplates/Brewfile` | Baseline package manifest (v12.0-audited), applied automatically |
| `.chezmoitemplates/Brewfile.optional` | Opt-in package groups, installed by hand via `brewopt <group>` |
| `dot_editorconfig` | Indentation rules for any editor |
| `run_onchange_after_macos-defaults.sh` | macOS keyboard/Finder/screenshot defaults (macOS only) |
| `bootstrap.sh` / `justfile` / `audit.sh` | Repo tooling — not applied to `$HOME` |

## Cheatsheet

`tldr dotfiles` is the entry point; `dot_config/tealdeer/pages/` covers every
tool this repo adds or changes, one page per topic (`tldr dotfiles-<topic>`).

## Opening a project

```sh
ide                      # this project, layout guessed from the tree
ide ~/Repositories/foo
ide -l sec .             # force one (mobile|web|backend|sec|arch)
```

`zj` gives a bare shell session instead. Inside zellij, `Ctrl+o p` picks a
layout and directory the same way.

## Architecture as code — C4 / d2

`workspace.d2` is the C4 model, one binary end to end:

```sh
d2-init                  # scaffold docs/architecture/workspace.d2
d2-local                 # serve it at http://localhost:8081
d2-render svg            # every layer as an image, locally
d2-validate              # diagnostics
```

`ide -l arch` opens a session with the preview server already running. The
`/d2-architect` Claude Code skill co-designs C1 → C2 → C3, one level per
exchange.

## AI tooling

**Claude Code** — `claudecode.nvim` gives the same panel as the VS
Code/Cursor extension (`Cmd+L` toggle, `Cmd+Shift+L` add context, `Cmd+K`
inline edit). The `mobilesec` MCP server exposes `adb_devices`, `logcat`,
and `scan` (semgrep/gitleaks/trivy/osv):

```sh
claude mcp add -s user mobilesec -- ~/.config/claude/mobilesec-mcp.py
```

**aider** — local, via Ollama, no API key. Pull a model, then pick it with
`:AiModel` in Neovim (`<leader>A` is the group: `Aa` toggle, `Am` menu, `As`
send selection):

```sh
brew services start ollama
ollama pull qwen2.5-coder:7b        # smaller/faster
ollama pull qwen3-coder:30b         # larger/better
```

**cursor-agent** — cloud, needs `cursor-agent login` once per machine
(`<leader>A` group: `Ac` toggle, `Ar` resume).

## Security tooling

`~/.config/zsh/sec.zsh` and the `:Semgrep` / `:Gitleaks` / `:Trivy` /
`:OsvScan` / `:ApkDecompile` commands in Neovim are for applications you are
authorized to test. Everything operates on a local file, emulator, or
attached device — nothing scans a remote host by default.
