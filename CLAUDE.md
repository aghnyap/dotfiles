# CLAUDE.md — instructions for an AI agent working in this repo

This is a **chezmoi source repository**, currently migrating to the
**v12.0-audited** manifest — that spec is the master reference for what
belongs in the baseline. It manages the core terminal environment: Ghostty,
zsh (+ oh-my-zsh), Neovim (LazyVim), starship, bat, delta, lazygit, btop, git
config. Everything not in the v12.0-audited manifest — legacy security/RE
tooling, mobile SDKs, and anything else this repo used to install by
default — lives in `.chezmoitemplates/Brewfile.optional` and is opt-in per
machine via `brewopt`, never installed automatically.

It produces **one** environment per platform. There is no work variant and no
personal variant: a work MacBook and a personal Mac built from this repo are
identical, because everything that would make them differ — identity, employer
network config, per-project SDK pins — is not configuration this repo owns.
"Per platform" is the one exception: this repo targets **macOS and Ubuntu
Linux** from the same source, so a config may branch on `.chezmoi.os` /
`.chezmoi.arch` — see *Templating conventions* below for exactly what that is
allowed to mean, and nothing more.

**Migration in progress:** the repo is moving to the v12.0-audited manifest on
`feature/v12-migration`, tagged for rollback at `backup-pre-v12`. See *Git
workflow for large changes* below for the convention that migration follows.

**`just` is a hard prerequisite** for working in this repo, on both platforms.
`bootstrap.sh`'s only job is installing Homebrew (or `apt` on Ubuntu),
`chezmoi`, and `just` — nothing past that point is a bash step. Every other
piece of repo maintenance — audits, checks, package syncing, diffing, applying —
is a `justfile` recipe, not a command typed by hand:

```sh
just --list      # every recipe
just check       # audit + gitleaks -- run before every commit
just pre-push    # check + drift + employer-domain scan -- run before every push
just diff        # what `chezmoi apply` would change, read-only
just dry-run     # diff + which run_onchange scripts would fire, read-only
just apply       # applies to $HOME -- confirms first, never run unannounced
```

---

## Hard rules

- **Document command snippets and keybindings in the same commit you add
  them, never as a follow-up.** New commands, aliases, or CLI usage go in a
  `dot_config/tealdeer/pages/*.page.md` custom page; new or changed Neovim
  keymaps go in `dot_config/tealdeer/pages/dotfiles-nvim.page.md` (a summary,
  not exhaustive — LazyVim's own `<leader>` + which-key is the exhaustive
  reference; this page covers what this repo adds or overrides on top of
  it). Keep employer-specific values out of both.
- **Cross-platform: macOS + Ubuntu Linux, one configuration per platform.**
  Every Mac built from this repo is identical to every other Mac, and every
  Ubuntu box identical to every other Ubuntu box. Do not add a work/personal
  flag, a hostname check, a `.work` datum, or any other branch on *which
  machine this is* — that split existed, and removing it is why the repo has
  no prompts and `bootstrap.sh` takes no flags. If two machines on the
  **same** platform need to differ, the difference is not configuration this
  repo owns.

  The one axis allowed to branch is platform capability: `.chezmoi.os` (and,
  where it matters, `.chezmoi.arch`) — never a hostname, a role, or anything
  that identifies a person or employer. Use it only for install mechanics
  that a platform genuinely forces (a cask on macOS vs. a formula or `apt`
  package on Linux, `bubblewrap` vs. `sandbox-exec` for agent sandboxing),
  never to decide *whether* a manifest tool is installed. See *Templating
  conventions*.

  `.chezmoitemplates/Brewfile.optional` is **not** an exception to this.
  Nothing reads it at apply time and no data decides anything: it is a list a
  human installs from with `brewopt <group>` when a given machine wants
  something outside the audited baseline (`sec` = frida/semgrep/mitmproxy/
  jadx/objection and the rest of the RE toolchain; `mobile` = FVM/adb/
  fastlane/cocoapods). The distinction that matters is *who chooses* — a
  template conditional chooses for you and gets committed; a command someone
  types does not. Keep new optional groups there, and keep the baseline
  Brewfile strictly the v12.0-audited manifest.
- **This repo configures machines, not people. Nothing in it may need to know
  who the user is.** No identity in a template, in a prompt, in a prompt
  default, or in a script — not "temporarily", and not behind a gate, because
  a gate decides what gets *applied* and the question here is what gets
  *committed*. If a config seems to need a name, an address, a company or a
  hostname, it belongs in a machine-local file:

  | Kind | Goes in | Managed |
  | --- | --- | --- |
  | git identity, host rewrites, hook `templateDir` | `~/.gitconfig` | no |
  | git pager, editor, delta theme | `~/.config/git/config` | yes |
  | work VPN helpers, employer shell tooling | `~/.config/zsh/local/*.zsh` | no |
  | SDK pins, project directories, BDD paths | that project's own workspace settings | no |

  `bootstrap.sh` follows the same rule: it reports a missing git identity and
  prints the two `git config --global` lines, and never runs them.
- **Treat every commit here as published.** The remote is public
  (`github.com/aghnyap/dotfiles`), so there is no window in which a mistake is
  merely a diff to revert — it is fetched, cached by third parties and
  permanent even after a force-push. That is what makes the capture guards in
  `.chezmoiignore` mandatory rather than advisory, and why nothing here may
  carry an email address, an internal hostname or an employer project path —
  see the secrets rule below for the pre-push check. **Never push it to the
  employer's internal GitLab either:** a personal Mac generally cannot reach
  that host, and personal config does not belong on company infrastructure.
- **Never commit secrets, and never let a secret manager's config carry one
  either.** `.chezmoiignore` excludes `~/.ssh`, `~/.aws`, `~/.config/gcloud`,
  `~/.netrc`, `~/.git-credentials`. Bitwarden CLI and Infisical are installed
  as *clients* — this repo has no vault, no vault URL, and no project token
  in it; those are machine-local login state, same as `cursor-agent login`.
  `age`/`sops` are installed as binaries only — no key material, no
  `.sops.yaml` recipient list naming a person, ships from here. Run `just
  leaks` (`gitleaks detect --no-git -s .`) before any push; `just pre-push`
  runs it for you.

---

## Templating conventions (v12.0-audited)

chezmoi templates are Go `text/template`. Two rules keep them from becoming
the identity leak or the silent-drop trap the rest of this file warns about:

- **The only data a template may branch on is `.chezmoi.os` and
  `.chezmoi.arch`.** No `.chezmoi.hostname`, no custom `.chezmoi.toml.tmpl`
  prompt data, nothing that names a person, a team or an employer. A block
  reads `{{ if eq .chezmoi.os "darwin" }}` / `{{ if eq .chezmoi.os "linux" }}`;
  reach for `.chezmoi.arch` only when a platform itself forks by CPU (a cask
  with no arm64 build, say).
- **`include` does not evaluate templates; `includeTemplate` does.** In a
  chezmoi template, `include` inserts a file verbatim — template actions
  inside it are not run. Use `includeTemplate` against `.chezmoitemplates/`,
  which is why the Brewfile lives there and is pulled in via
  `{{ includeTemplate "Brewfile" . }}` rather than `include`.
- **`{{-` trims the newline on the side it faces.** A careless trim once
  glued two JSON keys onto one line in a managed `settings.json` — still
  valid JSON, so `jq` passed it; only diffing the render against the live
  file caught it. Diff the rendered output, not just lint it, after touching
  whitespace control.
- **No managed file is a `.tmpl` except four load-bearing ones:**
  `.chezmoi.toml.tmpl`, `run_onchange_before_install-packages.sh.tmpl`,
  `.chezmoiignore.tmpl` (OS-conditional ignores, added for the v12.0-audited
  Linux target), and `dot_config/tealdeer/config.toml.tmpl` (needs
  `.chezmoi.homeDir` because tealdeer's `custom_pages_dir` does not expand
  `~`). None of the four is a config file anyone hand-edits under `$HOME` —
  `.chezmoiignore` in particular has no live copy in `$HOME` at all, chezmoi
  reads it only from the source — which is what keeps `chezmoi re-add` safe
  everywhere else — it cannot reverse templating, so an edit to a live file
  whose source is templated is silently dropped by `re-add` and lost on the
  next `apply`. Adding a new `.tmpl` anywhere else reopens that trap; if you
  do, document it here.
- **A literal `{{`/`}}` pair is live template syntax anywhere in a rendered
  file, comment or not** — `text/template` has no idea what a `#` is. An
  example conditional spelled out in a comment inside
  `.chezmoitemplates/Brewfile.optional` (rendered by `brewopt`, same as the
  baseline Brewfile) broke rendering with a confusing `unexpected EOF`
  pointing at a totally unrelated line. Describe a conditional in prose in
  a comment; don't paste its literal syntax.
- **OS-conditional blocks inside `Brewfile` stay install-mechanics only.**
  `{{ if eq .chezmoi.os "darwin" }}cask "firefox"{{ else }}brew "firefox"{{ end }}`
  is the intended shape — same tool, different package type. A tool that
  exists on one platform and not the other at all is a *manifest* decision
  (does it belong in the baseline?), not a templating one — see the Brewfile
  rule above it.

---

## Git workflow for large changes

Any change big enough to span several commits and touch the package manifest,
the OS-branching structure, or more than a couple of the hard rules above
follows this sequence — it is how the v12.0-audited migration itself is being
done, on `feature/v12-migration`:

1. Confirm `git status` is clean before starting.
2. Tag the starting point (`git tag backup-pre-<name>`) so rollback is a tag
   checkout away, not a `reflog` hunt. Tag, don't branch, for the rollback
   point — the feature branch is what moves.
3. Branch (`git checkout -b feature/<name>`); never work the change directly
   on `main`.
4. Land each reviewed, working slice as its own commit
   (`git commit -m "checkpoint(phase-N): <what>"`), and stop there for
   sign-off before starting the next slice. A checkpoint that fails `just
   check` is not done.
5. Never `git reset --hard`, `git push --force`, or rewrite history that has
   already been pushed — this repo's remote is public (see the secrets rule
   above), so a force-push does not make a mistake unpublished, it just hides
   it from `git log`.
6. Never run `chezmoi apply` (or `just apply`) as part of a checkpoint
   without saying so first and getting it confirmed. `just diff` / `just
   dry-run` show what a checkpoint *would* do — that is the verification
   step, not `apply` itself.
7. Roll back with `git checkout main && git branch -D feature/<name>`; the
   tag stays, so the abandoned attempt is still reachable if needed later.

---

## Working on this repo afterwards

The rule that catches everyone:

> Edit the live file (`~/.zshrc`, anything in `~/.config/nvim`), then run
> **`chezmoi re-add`** to pull the change back into this repo.
> Running `chezmoi apply` (or `just apply`) *without* re-adding **overwrites
> your edit**.

`just diff` should be empty when in sync. Commit from `~/dotfiles` as normal.

### Gotchas that have already caused real bugs here

- **`chezmoi re-add` silently skips templates.** chezmoi cannot reverse
  templating, so an edit to a live file whose source is a `.tmpl` is ignored
  by `re-add` and lost on the next `apply`. **No managed file is a template
  any more** — `~/.gitconfig`, `~/.config/nvim/KEYBINDINGS.md` and VS Code's
  `settings.json` all were, and all three stopped being managed or stopped
  being templated. The templates left are `.chezmoi.toml.tmpl`,
  `run_onchange_before_install-packages.sh.tmpl`, `.chezmoiignore.tmpl`, and
  `dot_config/tealdeer/config.toml.tmpl` — none of which is a config file
  anyone edits in `$HOME`. So `re-add` is
  currently safe on everything — and the trap comes straight back the moment
  another `.tmpl` is
  added. If you add one, say so here.
- **`chezmoi re-add` is also how junk gets committed.** VS Code's
  `settings.json` was managed for a while, and every extension that wrote to
  it had its keys swept into this repo by a `re-add` — a corporate scanner's
  CLI path, a GitLab Duo language list, a vendor telemetry flag. Read the
  diff before re-adding an app-owned file, or do not manage it at all.
- **lazy.nvim keeps only ONE `config` and one `init` per plugin** across all
  spec files; it does not chain them. That is why every scanner command lives
  in `lua/plugins/scanners.lua` and every task runner in `lua/plugins/tasks.lua`.
  Splitting them silently drops one set — a plugin spec that needs to open a
  toggleterm split for its own command must `require('toggleterm.terminal')`
  inside its own keymap callback rather than declaring `config`/`init` for
  toggleterm itself, or it silently replaces the block in `tasks.lua` and
  takes every `<leader>r` runner with it.
- **A new `dot_config/zsh/*.zsh` module is not picked up automatically.**
  `dot_zshrc:216` is an explicit `_mods=(…)` array, not a glob; a file
  dropped in that directory without being listed there never loads, and
  nothing reports it. The array appends `.zsh`, so the extension is
  mandatory and a `.sh` file cannot be loaded at all.
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
- Nothing outside the v12.0-audited baseline installs by default. FVM, the RE
  toolchain (frida, jadx, semgrep, mitmproxy, objection, nmap, nuclei,
  jwt-cli, apktool), and the rest of `Brewfile.optional`'s groups are opt-in
  per machine via `brewopt <group>` — install only what that machine's work
  actually needs.
- **Shell startup may be much faster on some machines.** A corporate-managed
  Mac can carry a 5-7ms fork+exec floor from an endpoint security agent
  intercepting every exec, rising past 10ms under load; an unmanaged one is
  1–2ms. Much of `~/.zshrc`'s optimisation (the `git`/`scutil` shims around
  the oh-my-zsh load, `compinit -C`) exists to dodge that tax and is harmless
  but less necessary elsewhere.

---

## Layout

| Path | What |
| --- | --- |
| `dot_zshenv` | Toolchain PATH/env for **all** shells; `dev_paths_prepend()` re-asserted from `.zprofile` because `/etc/zprofile`'s `path_helper` reorders PATH |
| `dot_zshrc` | Interactive only. oh-my-zsh + the fork-elimination shims |
| `dot_config/zsh/` | `aliases` `functions` `dev` `sec` `fzf` `tools` `csiu` `d2` `zellij` `git-aliases` (a vendored copy of oh-my-zsh's git plugin, used only as a fallback when the framework is absent). **Every one of these is listed by name in `_mods` at `dot_zshrc:216`** — a new file here does nothing until it is added there |
| `dot_config/nvim/` | LazyVim + custom specs. See `dotfiles-nvim.page.md` (`tldr dotfiles-nvim`) |
| `dot_aider.conf.yml` | aider's non-model defaults. There is deliberately no model here: Neovim selects one per process with `:AiModel`, and shell use passes `--model` explicitly |
| `dot_aider.model.settings.yml` | Per-model `num_ctx` and `edit_format`. **`num_ctx` must be set here, not via `OLLAMA_CONTEXT_LENGTH`** — `brew services` starts ollama through launchd, which does not inherit a shell's environment, so an export would look correct and change nothing. Ollama's 2k default silently truncates instead of erroring |
| `dot_aider.model.metadata.json` | Per-model prompt/output budgets. Keep `max_tokens` equal to `num_ctx`, reserve 8192 in `max_output_tokens`, and set `max_input_tokens` to the difference. The reserve is that large because `edit_format: whole` returns an entire file, and 1024 truncated any rewrite past ~100 lines. Without this file aider trusts the model's advertised 262k window and can overrun the smaller local context silently |
| `dot_claude/skills/` | Claude Code skills, currently `d2-architect`. The **only** managed path under `~/.claude` — `.chezmoiignore` denies the rest of that tree, which holds session transcripts and memory files |
| `dot_config/ghostty/config` | Font, theme, and the 30 CSI-u Cmd-chord forwards Neovim depends on |
| `dot_config/git/config` | git's tooling half — pager, editor, delta theme. `~/.gitconfig` holds identity and is **not** managed |
| `.chezmoitemplates/Brewfile` | Baseline package list: the v12.0-audited manifest, cross-platform (macOS + Ubuntu). One list, no variants |
| `.chezmoitemplates/Brewfile.optional` | Opt-in groups, installed by hand via `brewopt` — everything outside the audited baseline (RE/security toolchain, mobile SDKs, and the rest). Never applied automatically |
| `dot_editorconfig` | Indentation every editor reads. Deliberately duplicates the per-language table in `nvim/lua/config/autocmds.lua` — that one is Neovim-only, this one also reaches any unmanaged GUI editor. **Change one, change the other**; Go and Make are the ones that bite, both needing literal tabs |
| `run_onchange_after_macos-defaults.sh` | The only thing here that reaches outside `$HOME`. Keyboard (press-and-hold off, fast repeat), Finder, screenshots. Machine behaviour only — no Dock, no wallpaper, nothing that is taste. Keyboard settings need a logout. macOS-only |
| `bootstrap.sh` | Installs Homebrew (or `apt` on Ubuntu), `chezmoi`, and `just` — nothing else. `.chezmoiignore`d, so it is not a target |
| `audit.sh` | Non-mutating source-contract checks (syntax, AI budgets, key ownership, templates, Brewfile scope, gitleaks). Run via `just audit`; also `.chezmoiignore`d |
| `justfile` | Task runner for repo maintenance — see the recipes listed at the top of this file. `.chezmoiignore`d, same reason as `bootstrap.sh`/`audit.sh`: it is repo tooling, not a dotfile for `$HOME` |
| `dot_config/tealdeer/pages/` | Custom `tldr` pages documenting this repo's own commands and aliases — the first place to add a new one, per the Hard rules above |
| `INSTALL.md` | The same bootstrap, written for a human |
