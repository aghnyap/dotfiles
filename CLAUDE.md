# CLAUDE.md — instructions for an AI agent working in this repo

This is a **chezmoi source repository**. It manages the whole terminal
environment: Ghostty, zsh (+ oh-my-zsh), tmux, Neovim (LazyVim), starship, bat,
delta, lazygit, btop, git config, and a security toolchain.

It produces **one** environment. There is no work variant and no personal
variant: a work MacBook and a personal Mac built from this repo are identical,
because everything that would make them differ — identity, employer network
config, per-project SDK pins — is not configuration this repo owns.

---

## Task: bootstrap this onto a new machine

**`./bootstrap.sh` already does all of this**, idempotently, and verifies the
result. Prefer it. It takes no flags, asks nothing and needs no TTY:

```sh
./bootstrap.sh
```

The manual sequence below is what it automates — follow it only when debugging
the script itself. Run these in order. Stop and report if any step fails — do
not improvise past a failure.


### 0. Confirm where you are

```sh
uname -srm                       # expect: Darwin … arm64
ls ~/dotfiles/.git  # the repo must already be unzipped here
```

If the repo is somewhere else, either move it to `~/dotfiles` or
substitute the real path in every `--source=` below. Do not clone from a
remote; there isn't one.

### 1. Homebrew

```sh
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install chezmoi git
```

### 2. Initialise chezmoi against this folder

```sh
chezmoi init --source=~/dotfiles
```

**`--source` is mandatory.** Without it chezmoi uses `~/.local/share/chezmoi`
and silently manages nothing. It is only needed once — the generated
`~/.config/chezmoi/chezmoi.toml` records the path.

**`chezmoi init` asks nothing** — `.chezmoi.toml.tmpl` has no prompts at all, so
this runs fine headless and `--no-tty` is safe to pass.

**Do not add a prompt back.** Not for identity, not for a machine kind. If some
config appears to need one, that config is per-machine or per-project and does
not belong in this repo — see *Hard rules*.

Should a prompt ever reappear, note that it cannot be answered with
`--promptBool` / `--promptString`: `chezmoi init` accepts those flags and then
ignores them (v2.72.0), still reaching for `/dev/tty` and failing with *"could
not open a new TTY"*. `chezmoi execute-template --init` does honour them, which
is exactly what makes the trap easy to walk into. Pipe answers on stdin with
`--no-tty` instead.

### 3. Apply

```sh
chezmoi apply
```

This also runs `run_onchange_before_install-packages.sh`, which installs the
Brewfile, oh-my-zsh (unattended), mise runtimes (node/java/ruby) and the ruby
gems, the uv-managed security tools, tmux's plugin
manager and the zsh plugins. It takes a while on a fresh machine.

### 4. Two manual finishes

```sh
nvim        # LazyVim installs plugins, Mason installs servers; then :q
tmux        # press Ctrl-a then Shift-i to install tmux plugins
```

### 5. Verify — do not report success without this

```sh
chezmoi diff                      # expect: empty
zsh -lic 'true'                   # expect: no output at all
zsh -lic 'whence -w omz; alias glog; echo $STARSHIP_SHELL'
nvim --headless -c 'Lazy! sync' -c qa
```

In a **real terminal** (not headless — several defects in this config's history
were invisible to `zsh -c` and only appeared with a live ZLE):

- `glog`, `gcmsg`, `gco` resolve to oh-my-zsh git aliases
- syntax highlighting, autosuggestions and fzf-tab are active
- `Ctrl-R` opens atuin
- Starship prompt renders in its default format — `<dir> on  <branch> via
  ☕ <version> took <n>s`, then `❯` on the next line. `~/.config/starship.toml`
  is deliberately comment-only; emoji symbols there are upstream defaults, not
  a broken Nerd Font
- tab completion works: `git chec<TAB>` → `checkout`

Then confirm nothing employer-specific arrived:

```sh
# The employer's domain, derived rather than written down, so this repo names
# no company. ~/.gitconfig is excluded because that is exactly where the
# identity is supposed to be.
domain=$(git config user.email | cut -d@ -f2)
grep -rIl -iF "${domain%%.*}" ~/.config ~/Library/Application\ Support/Code 2>/dev/null
```
Expect **no output**. A match means employer-specific content has been committed
into a managed file; move it to `~/.gitconfig` or `~/.config/zsh/local/` and
re-apply. It is not a mis-answered prompt — there are no prompts.

---

## Hard rules

- **Always update `CHEATSHEET.md` in the same commit.** If you add or change a
  keybinding, alias, user command, or tool anywhere in this repo, the cheatsheet
  is part of that change, not a follow-up. It is the single cross-tool quick
  reference (Ghostty, tmux, Neovim, vim, shell, security tooling, chawan);
  `dot_config/nvim/KEYBINDINGS.md` remains the exhaustive Neovim one, and
  usually needs the same edit. Keep employer-specific values out of both.
- **One configuration, no variants.** Every machine built from this repo is
  identical. Do not add a work/personal flag, a hostname check, a `.work`
  datum, or any other branch on *which machine this is* — that split existed,
  and removing it is why the repo now has no prompts and `bootstrap.sh` takes
  no flags. If two machines need to differ, the difference is not configuration
  this repo owns.

  `.chezmoitemplates/Brewfile.optional` is **not** an exception to this. Nothing
  reads it at apply time and no data decides anything: it is a list a human
  installs from with `brewopt <group>` when a given machine wants a heavy
  toolchain (`backend` = colima/docker/kubectl, ~1 GB). The distinction that
  matters is *who chooses* — a template conditional chooses for you and gets
  committed; a command someone types does not. Keep new optional groups there,
  and keep the baseline Brewfile unconditional.
- **This repo configures machines, not people. Nothing in it may need to know
  who the user is.** No identity in a template, in a prompt, in a prompt
  default, or in a script — not "temporarily", and not behind a gate, because a
  gate decides what gets *applied* and the question here is what gets
  *committed*. If a config seems to need a name, an address, a company or a
  hostname, it belongs in a machine-local file:

  | Kind | Goes in | Managed |
  | --- | --- | --- |
  | git identity, host rewrites, hook `templateDir` | `~/.gitconfig` | no |
  | git pager, editor, delta theme | `~/.config/git/config` | yes |
  | work VPN helpers, employer shell tooling | `~/.config/zsh/local/*.zsh` | no |
  | SDK pins, project directories, BDD paths | that project's `.vscode/settings.json`, its `.fvm/` | no |

  `bootstrap.sh` follows the same rule: it reports a missing git identity and
  prints the two `git config --global` lines, and never runs them.
- **Never push this repo to a public remote,** and never to the employer's
  internal GitLab. It carries no email address, internal hostname or employer
  project path — but it is still a full description of one person's machine.
  Private remote or sneakernet only.
- **Never add Flutter or Dart to `PATH`.** Their absence is deliberate: FVM
  pins Flutter per-repository from each clone's `.fvm/`. A global SDK would
  shadow the pin and silently build the wrong version. Use `fvm flutter …`
  (aliased `fl`). "flutter: command not found" is **not** a bug to fix.
- **Never commit secrets.** `.chezmoiignore` excludes `~/.ssh`, `~/.aws`,
  `~/.config/gcloud`, `~/.netrc`, `~/.git-credentials`. Run
  `gitleaks detect --no-git -s .` before any push.

---

## Working on this repo afterwards

The rule that catches everyone:

> Edit the live file (`~/.zshrc`, anything in `~/.config/nvim`), then run
> **`chezmoi re-add`** to pull the change back into this repo.
> Running `chezmoi apply` *without* re-adding **overwrites your edit**.

`chezmoi diff` should be empty when in sync. Commit from
`~/dotfiles` as normal.

### Gotchas that have already caused real bugs here

- **`chezmoi re-add` silently skips templates.** chezmoi cannot reverse
  templating, so an edit to a live file whose source is a `.tmpl` is ignored by
  `re-add` and lost on the next `apply`. **No managed file is a template any
  more** — `~/.gitconfig`, `~/.config/nvim/KEYBINDINGS.md` and VS Code's
  `settings.json` all were, and all three stopped being managed or stopped being
  templated. The only templates left are `.chezmoi.toml.tmpl` and
  `run_onchange_before_install-packages.sh.tmpl`, neither of which is a config
  file anyone edits in `$HOME`. So `re-add` is currently safe on everything —
  and the trap comes straight back the moment a `.tmpl` is added. If you add
  one, say so here.
- **`chezmoi re-add` is also how junk gets committed.** VS Code's `settings.json`
  was managed for a while, and every extension that wrote to it had its keys
  swept into this repo by a `re-add` — a corporate scanner's CLI path, a GitLab
  Duo language list, a vendor telemetry flag. Read the diff before re-adding an
  app-owned file, or do not manage it at all.
- **`include` does not evaluate templates.** In a chezmoi template, `include`
  inserts a file verbatim; template actions inside it are not run. Use
  `includeTemplate` with `.chezmoitemplates/` (this is why the Brewfile lives
  there).
- **`{{-` trims the newline on the side it faces.** A careless trim glued two
  JSON keys onto one line in `settings.json`. Still valid JSON, so `jq` passed
  it — only diffing the render against the live file caught it.
- **lazy.nvim keeps only ONE `config` and one `init` per plugin** across all
  spec files; it does not chain them. That is why every scanner command lives
  in `lua/plugins/scanners.lua` and every task runner in `lua/plugins/tasks.lua`.
  Splitting them silently drops one set.
- **In `~/.config/nvim`, `flutter-tools` must keep
  `root_patterns = { 'melos.yaml', '.git' }` with `pubspec.yaml` absent.**
  Restoring `pubspec.yaml` spawns one Dart analysis server per package (~20 on
  the work monorepo). Verify with `:LspInfo` — exactly one `dartls` client.
- **`palette = "…"` below `[palettes.…]` in `starship.toml` is a no-op.** TOML
  scopes it into the table, leaving the top-level key unset; starship then
  drops `bg0`..`bg4` and falls back to 4-bit ANSI for the named colours. The
  prompt still draws, so it reads as a design choice rather than a bug. It sat
  broken from the day the file was written. Verify with `tomllib`, not
  `starship print-config` — the latter echoes the misplaced key happily.
  Only relevant if the config is customised again; it is currently default.
- **A stale Nerd Font codepoint renders as nothing, not as tofu.** The
  `nf-fa-*`/`nf-dev-*` ranges moved in Nerd Fonts v3, so a blank is
  indistinguishable from an icon that was never configured — seven
  keys in the old `fastfetch` greeting sat empty this way. Use `nf-md-*` (`U+F0xxx`) and prove the
  codepoint exists with
  `fc-list ':charset=F0035' family | grep -i 'jetbrainsmono nerd font'`
  before committing it.
- **`nf-md-*` being reliable is not the same as being portable.** That range is
  plane 15 (`U+F0xxx` — five digits, above the BMP), so it renders only where
  the patched font is genuinely active; astral-plane private use has no system
  fallback, and a terminal that is not set to JetBrainsMono Nerd Font shows
  tofu or nothing. Only Ghostty is configured for that font here, so a glyph
  can look perfect in the terminal it was tested in and be broken in every
  other one. **For anything that leaves Ghostty — the starship prompt above all,
  since it also has to survive ssh and other people's terminals — stay in the
  BMP.** `U+E0A0` and the rest of the original powerline range are the safe
  choice; `git_branch` in `starship.toml` was reverted to it for exactly this
  reason, and that file's comment has the detail. Inside `~/.config/nvim`,
  plane-15 glyphs are fine: Neovim only ever runs in Ghostty here.
- **zsh cannot define a function whose name is an existing alias.** oh-my-zsh's
  git plugin defines 197 aliases; a colliding function name aborts the rest of
  the file with a parse error. Check before adding any `g*` name.

---

## Things that will legitimately differ between machines

The configuration is identical everywhere; the *environment* it lands in is
not. These are not bugs — do not "fix" them:

- No Android SDK, Xcode, or work repos on a fresh Mac. `~/.zshenv` guards every
  toolchain path with `[[ -d … ]]`, so missing ones are skipped silently.
- FVM is not installed by the Brewfile. Install it only if you actually do
  Flutter work there.
- **Shell startup may be much faster on some machines.** A corporate-managed Mac
  can carry a 5-7ms fork+exec floor from an endpoint security agent intercepting
  every exec, rising past 10ms under load;
  an unmanaged one is 1–2ms. Much of `~/.zshrc`'s optimisation (the
  `git`/`scutil` shims around the oh-my-zsh load, `compinit -C`) exists to dodge
  that tax and is harmless but less necessary elsewhere.
- The security toolchain (frida, jadx, semgrep, mitmproxy…) installs regardless.
  Remove those lines from `.chezmoitemplates/Brewfile` if unwanted on a personal
  machine.

---

## Layout

| Path | What |
| --- | --- |
| `dot_zshenv` | Toolchain PATH/env for **all** shells; `dev_paths_prepend()` re-asserted from `.zprofile` because `/etc/zprofile`'s `path_helper` reorders PATH |
| `dot_zshrc` | Interactive only. oh-my-zsh + the fork-elimination shims |
| `dot_config/zsh/` | `aliases` `functions` `dev` `sec` `fzf` `tools` `csiu` `git-aliases` (a vendored copy of oh-my-zsh's git plugin, used only as a fallback when the framework is absent) |
| `dot_config/nvim/` | LazyVim + custom specs. See `KEYBINDINGS.md` |
| `dot_config/tmux/` | tmux.conf + mobile/web/backend/sec project layouts |
| `dot_config/ghostty/config` | Font, theme, and the 30 CSI-u Cmd-chord forwards Neovim depends on |
| `dot_config/git/config` | git's tooling half — pager, editor, delta theme. `~/.gitconfig` holds identity and is **not** managed |
| `.chezmoitemplates/Brewfile` | Baseline package list. One list, no variants |
| `.chezmoitemplates/Brewfile.optional` | Opt-in groups, installed by hand via `brewopt`. Never applied |
| `bootstrap.sh` | Scripted bootstrap + look-and-feel verification. `.chezmoiignore`d, so it is not a target |
| `INSTALL.md` | The same bootstrap, written for a human |
