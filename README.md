# dotfiles

Terminal-native development environment: Ghostty + zsh + tmux + LazyVim,
themed Tokyo Night throughout — except the prompt, where starship is left at
its built-in default. Managed with [chezmoi](https://chezmoi.io).

Covers mobile (Flutter, Android/Kotlin, iOS/Swift, React Native), web
(React/TS), backend (Kotlin/JVM), and mobile/web security work.

**Neovim is the IDE**, which is why every editor concern here is a terminal
concern. The GUI editors that remain are deliberately unmanaged: Cursor is kept
for its model rather than its editing surface, and Android Studio and Xcode are
the fallback for mobile work. None of the three has config in this repo, so
moving to another machine carries the environment without dragging along an
editor's accumulated state.

## Bootstrap a new machine

Get the repo onto the machine (private remote, or the zip in
[`INSTALL.md`](INSTALL.md)), then from inside it:

```sh
./bootstrap.sh
```

That is the whole thing: Homebrew, chezmoi, `chezmoi apply`, the Brewfile, and a
verification pass that the fonts and Nerd Font glyphs actually landed. It
takes no flags and asks no questions, so it is already unattended, and it is
idempotent — re-run it any time.

```sh
./bootstrap.sh git@github.com:<you>/dotfiles.git    # clone, then do all of the above
```

Doing it by hand instead:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply --source=~/dotfiles <this-repo-url>
```

**`chezmoi init` asks nothing.** There is no work/personal split and no
identity: every Mac built from this repo gets the same editor, the same
toolchain and the same theme, so there is nothing to branch on and nobody to
ask about. It holds no address, no author name, no employer hostname and no
project path — not templated, not gated, not stored.

What genuinely differs between two Macs is not configuration, and lives
outside the repo:

| Differs | Lives in | Managed |
| --- | --- | --- |
| Who commits from this machine | `~/.gitconfig` | no |
| Employer network config — host rewrites, hook `templateDir` | `~/.gitconfig` | no |
| Work VPN helpers, employer shell tooling | `~/.config/zsh/local/*.zsh` | no |
| Per-project SDK pins, BDD directories | that project's `.vscode/settings.json`, its `.fvm/` | no |

Git config is split along that same line, using the fact that git reads two
user-level files:

| File | Holds | Managed |
| --- | --- | --- |
| `~/.config/git/config` | pager, editor, delta's Tokyo Night theme, `conflictStyle` | yes |
| `~/.gitconfig` | `[user]`, internal host rewrites, hook `templateDir` | no — hand-written per machine, `.chezmoiignore`d |

`~/.gitconfig` wins on any key set in both, so a machine can override anything
the repo ships without editing the repo. A fresh machine has no git identity
until you write one; `bootstrap.sh` says so at the end and does not do it for
you.

`run_onchange_before_install-packages.sh.tmpl` then runs `brew bundle` over
`.chezmoitemplates/Brewfile`, sets up the mise runtimes (node, java, ruby) and the
cocoapods/fastlane gems, installs frida/objection via `uv tool`, and
clones tpm plus the zsh plugins Homebrew does not package. It re-runs by itself
whenever the Brewfile changes.

`bootstrap.sh` then installs the nvim and tmux plugins headlessly and builds the
`bat` theme cache, so nothing is left to do by hand except write your git
identity, which this repo deliberately does not own. Mason installs its language
servers on the first real `nvim` start — that needs an event loop, so no script
can force it.

## Cheatsheet

[`CHEATSHEET.md`](CHEATSHEET.md) is the one-page reference across every tool —
Ghostty, tmux, Neovim, vim itself, the shell, the security toolchain and the
terminal browser (chawan).
`dot_config/nvim/KEYBINDINGS.md` stays the exhaustive Neovim reference.

## Layout

| Path | What |
| --- | --- |
| `dot_zshenv` | Toolchain PATH/env for **all** shells. `dev_paths_prepend()` is re-asserted from `.zprofile` because `/etc/zprofile`'s `path_helper` reorders PATH. |
| `dot_zshrc` | Interactive shell only. Thin — content lives in the modules. |
| `dot_config/zsh/` | `aliases` `functions` `dev` `sec` `fzf` `tools` `csiu`, plus `git-aliases` as a fallback when oh-my-zsh is absent |
| `dot_config/nvim/` | LazyVim + custom plugin specs. See `KEYBINDINGS.md`. |
| `dot_config/tmux/` | tmux.conf + project layouts (mobile/web/backend/sec) |
| `dot_config/ghostty/config` | Font, theme, and the 30 CSI-u Cmd-chord forwards Neovim depends on |
| `dot_config/git/config` | git's tooling half — pager, editor, delta theme. `~/.gitconfig`, which holds identity, is not managed |
| `.chezmoitemplates/Brewfile.optional` | Opt-in package groups (`brewopt backend`). Not installed by `apply` |
| `bootstrap.sh` | One-command setup for a new machine, plus the look-and-feel verification. Not a target — `.chezmoiignore`d like the docs. |

## Opening a project

```sh
ide                      # this project, layout guessed from the tree
ide ~/Repositories/foo
ide -l sec .             # force one (mobile|web|backend|sec|arch)
```

`ide` builds the tmux session the layouts describe: an `editor` window running
Neovim, which opens the file tree itself, plus the side windows for that kind
of project. `tm` is the lower-level one — it gives you a session with a bare
shell in it. Inside tmux, `prefix + P` picks a layout and a directory instead.

## Architecture as code — C4 / Structurizr

The C4 model lives in a repo as `workspace.dsl` and is the single source of truth
for the architecture. One binary drives all of it:

```sh
c4-init                  # scaffold docs/architecture/
c4-local                 # serve it at http://localhost:8081
c4-export                # every view to Mermaid, fenced for PR review
c4-validate              # the only diagnostics that exist
```

`ide -l arch` (or `ide` in a repo with a `workspace.dsl` and no app manifest)
builds a tmux session with the preview server already running.

**No Docker.** Nearly every guide you will find says to run Structurizr Lite in
a container, and Colima with it. Two things changed upstream: the
`structurizr-cli` Homebrew formula is deprecated and Homebrew disables it on
2027-02-17, and Structurizr Lite is filed under "End of life". The unified
`structurizr` binary replaces both — `local` is documented as *"equivalent to the
previous Structurizr Lite tooling"* — and it runs natively. `colima` and `docker`
stayed in the optional `backend` group, where they were.

**Port 8081, not 8080.** 8080 is the upstream default and is exactly where
`mitmweb` and the tmux `sec` layout listen. `C4_PORT=9000 c4-local` overrides it,
and `c4-local` names the process holding the port rather than letting the JVM
fail obscurely.

**Commit `workspace.json`.** Layout you drag in the browser is saved there, next
to the DSL. Lose it and you re-drag every box.

`c4-init` writes a `structurizr.properties` turning on auto-refresh at 2000 ms,
which upstream ships disabled — so editing the DSL updates the browser without a
reload. That plus a split-screen browser is the working setup; it is also what
upstream recommends in place of an editor preview panel.

### In Neovim

Nothing is installed. Structurizr syntax and the `structurizr` filetype are built
into Neovim, and `jfcherng/vim-structurizr` — the plugin most guides name — does
not exist. `<leader>C` is the group: `Cs` serve, `Cb` browser, `Ce` export, `Cv`
validate, `Ca` toggle export-on-save. There is no language server for the DSL
(the nvim-lspconfig PR was rejected, mason has no package), so `<leader>Cv` into
the quickfix list is the substitute.

### In Android Studio / IntelliJ

Nothing here is committed for either IDE, the same as for Cursor and VS Code.

Install **Structurizr DSL Language Support** (Dirk Groot, plugin `20606`) — free,
by far the largest install base, and no upper build bound so it installs on
current Android Studio. It is syntax and indentation only, which is enough
because the modelling happens in Neovim. The plugin usually recommended,
*Structurizr DSL Support* (`21358`), is abandoned: last updated April 2023 and
capped at build `231.*`, so it will not install at all. If you want in-IDE live
preview and export, **Structurizr DSL** (Jakub Jirák, `29351`) is the only plugin
that has them, and it is paid.

The IDE terminal needs no setup — it starts a login shell, which sources
`~/.zshrc`, which sources `c4.zsh`, so `c4-local` and `c4-export` are there. The
one gotcha: Toolbox-launched IDEs inherit the GUI environment, so `structurizr`
is visible only because `/opt/homebrew/bin` is on the login-shell PATH.

There is no embedded-browser option. JetBrains has no general-purpose webview to
point at `localhost:8081` — the choices are *Open in Browser* or plugin `29351`'s
own panel.

### The Claude skill

`~/.claude/skills/c4-architect/SKILL.md` is managed here, so `/c4-architect` is
available in any repo on any machine. It co-designs C1 → C2 → C3 one level per
exchange, refuses Level 4 and implementation code, enforces the Flutter
UI/BLoC/Repository split against the Java Controller/Service/Repository split, and
emits the OpenAPI contract for every relationship that crosses between them.

`.chezmoiignore` denies `.claude/**` and allows back only `.claude/skills/**`.
That skill is the sole reason this repo touches `~/.claude` at all, and the rest
of that tree is session transcripts and memory files describing the machine's
owner. With a public remote, an accidental `chezmoi add` there is published and
permanent.

## Things that will bite you

- **The Cmd chords are not Cmd keys, and they only work because two files
  agree.** They used to die inside tmux: Ghostty encoded them with the Super bit
  (`\E[112;9u` = Cmd+P), tmux's key model has no Super modifier so it collapsed
  Super onto Meta, and a pane received a bare `<M-p>`. Ctrl+Shift and
  Ctrl+Alt+Shift *do* survive, so the chords were re-encoded onto those —
  Ghostty sends `\E[112;6u`, Neovim aliases `<C-S-P>` back to `<D-p>`, and
  `tmux.conf` sets `extended-keys-format csi-u` so the sequence arrives intact.
  Changing any Cmd binding means editing **both** `dot_config/ghostty/config`
  and `lua/config/keymaps.lua`; touching one alone silently breaks it.
- **LazyVim picks the file explorer for you.** On `install_version` 8 its
  default list is `{ snacks, neo-tree }`, so it auto-enables the
  `editor.snacks_explorer` extra and binds `<leader>e` to it — giving you a
  second explorer alongside the neo-tree that `plugins/ui.lua` configures.
  `vim.g.lazyvim_explorer = 'neo-tree'` in `config/options.lua` settles it.
- **Flutter is not on PATH, on purpose.** FVM pins it per repository from the
  clone's `.fvm/`. Use `fvm flutter ...` (aliased to `fl`). A global SDK would
  shadow the per-repo pin and silently build the wrong version.
- **`~/.config/zsh/plugins/` and `~/.config/tmux/plugins/` are not managed
  here.** They are upstream git clones; the bootstrap script fetches them.
- **A wrong Nerd Font codepoint renders as nothing, not as tofu.** The
  `nf-fa-*` and `nf-dev-*` ranges were relocated in Nerd Fonts v3, so a stale
  codepoint leaves a blank that is indistinguishable from a config which never
  had an icon — that is precisely how seven rows of the old `fastfetch` greeting
  sat iconless without looking broken, and how `starship.toml` lost every glyph
  outside the
  `U+F0xxx` range in one go — all six powerline separators, every language
  logo, the clock, and the `Repositories` directory substitution, which turned
  `~/Repositories/x` into `/x`. Grep for `= ""` and for a double space inside a
  `format` string; both are the shape this leaves behind.
  Prefer `nf-md-*` (`U+F0xxx`), and confirm the
  codepoint is in the font before committing it instead of trusting a
  cheatsheet:

  ```sh
  fc-list ':charset=F0035' family | grep -i 'jetbrainsmono nerd font'
  ```

  Output means the font can draw `U+F0035`; silence means it cannot, and the
  icon would vanish. That answers *whether* a codepoint exists but not *what it
  draws* — for that, read the `cmap` and `post` tables of the file
  `fc-match 'JetBrainsMono Nerd Font Mono' file` resolves to, where the patched
  glyph names (`md-apple`, `md-cpu_64_bit`, …) are recorded.
- **If you re-customise starship, `palette = "…"` must sit ABOVE
  `[palettes.…]`.** TOML assigns every key after a table header to that table,
  so a `palette` line below the palette definition silently becomes
  `palettes.<name>.palette` and the top-level key stays unset. Starship then
  drops the custom colour names and falls back to 4-bit ANSI — the prompt still
  renders, just flat and mis-coloured, so nothing looks broken enough to
  investigate. A Tokyo Night powerline config lost days to exactly this. Check
  the parsed key, not the file:
  `python3 -c "import tomllib;print(tomllib.load(open('$HOME/.config/starship.toml','rb')).get('palette'))"`
  must echo the palette name. `starship print-config` is *not* a useful check
  here: it happily prints the misplaced key.
- **Never commit secrets.** `.chezmoiignore` excludes `~/.ssh`, `~/.aws`,
  `~/.config/gcloud`, `~/.netrc` and `~/.git-credentials`. Run
  `gitleaks detect` on this repo before pushing. The repo carries no address,
  employer hostname or project path at all: identity is not something a machine
  config needs, so it lives in `~/.gitconfig` and nothing here templates it.
  Keep the repo private anyway; the toolchain it describes is still a map of
  one person's machine.
- **Shell startup is load-dependent, so do not trust a single number** — this
  README asserted "~179ms" for a while and it was not reproducible. Measured at
  load ~3 it is 227ms mean (± 39), range 147-291, down from 475ms before the
  rework. The spread within one benchmark run is wider than most changes you would
  make, so compare means at equal load, or bisect the layers with
  `zsh -fc/-c/-lc/-lic exit`, which are stable. The notes at the bottom of
  `dot_zshrc` record where the time goes and why the rest is unreachable.

## Claude in the editor

`claudecode.nvim` speaks the same protocol the official extension speaks inside
VS Code and Cursor. `Cmd+L` toggles the panel, `Cmd+Shift+L` adds the selection
or file, and `Cmd+K` is an inline edit — it prompts in a float and returns the
answer as an inline diff over the selection (`diff_opts.layout = 'unified'`).

`~/.config/claude/mobilesec-mcp.py` is an MCP server exposing this machine's
toolchain as structured data: `adb_devices`, `logcat` (scoped to an app's pid),
and `scan` (semgrep / gitleaks / trivy / osv). Register it once, for every
project:

```sh
claude mcp add -s user mobilesec -- ~/.config/claude/mobilesec-mcp.py
claude mcp list          # expect: mobilesec ... ✔ Connected
```

It is deliberately not a shell: scanners are addressed by name from a fixed
table, flags are pinned by the server, and there is no `shell=True` anywhere —
so a caller cannot smuggle in arguments. It holds no credentials.

**`~/.claude.json` is not managed by chezmoi**, on purpose. It carries session
state and auth caches, so it is a local file, not a dotfile. Servers that need a
token are registered locally and reference it as `${ENV_VAR}` — never a literal,
and never committed.

## Security tooling

`~/.config/zsh/sec.zsh` and the `:Semgrep` / `:Gitleaks` / `:Trivy` /
`:OsvScan` / `:ApkDecompile` commands in Neovim are for applications you are
authorized to test. Everything operates on a local file, a local emulator, or
an attached device — nothing scans a remote host by default.
