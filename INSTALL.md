# Moving this setup to another Mac

**Zip this folder and carry it over.** No accounts, no remote, no extra files.

---

## Option A — zip this folder

This directory *is* the repo. `.git/` lives inside it, so a plain zip carries
every config file and the full commit history with it.

**1. On this Mac:**

```sh
cd ~
zip -qr ~/dotfiles.zip dotfiles -x 'dotfiles/.claude/*' 'dotfiles/.git/hooks/*'
```

The two `-x` patterns drop local state that is not tracked but would otherwise
ride along inside the directory:

- `.claude/settings.local.json` records Claude Code's permission grants as
  absolute paths from whichever Mac approved them.
- `.git/hooks/*` is seeded from `~/.git-templates` by the corporate git config,
  and `security.sh` alone is 44 KB naming an internal host and a commercial
  scanner 60-odd times. It is employer tooling, it is not tracked, and a work
  machine re-seeds it automatically at `git init` -- so a personal machine should
  neither receive it nor need it.

Worth knowing why this was easy to miss: everything else in this repo was audited
by reading tracked files and git objects, and `.git/hooks` is neither.

AirDrop / USB / iCloud `~/dotfiles.zip` to the other Mac.

**2. On the other Mac, paste this whole block into Terminal:**

```sh
cd ~
unzip -q ~/Downloads/dotfiles.zip        # -> ~/dotfiles

cd dotfiles && ./bootstrap.sh
```

`bootstrap.sh` does the rest — Homebrew, `chezmoi`, every config into place, the
Brewfile, and a check that the fonts and Nerd Font glyphs really landed. It
asks nothing and takes no flags. Re-running it is safe.

<details>
<summary>The same thing by hand</summary>

```sh
# Homebrew (skip if you already have it)
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

brew install chezmoi git

# Point chezmoi at it, then write every config into place. No prompts.
chezmoi init --source=~/dotfiles
chezmoi apply
```
</details>

> `--source` is the easy thing to miss. Without it chezmoi looks in
> `~/.local/share/chezmoi` and will not find the folder. You pass it once --
> the generated config records the path for every later command.

> Confirm the history survived the trip: `git -C ~/dotfiles log --oneline | wc -l`
> should match what it says on this Mac.

**3. `chezmoi init` asks nothing.**

Not what kind of machine this is — every Mac built from this repo gets the same
configuration, which is the point of having one — and not who you are. This
repo sets up machines and tools, and none of that needs an identity, so git's
identity half (`[user]`, an internal GitLab rewrite, a corporate hook
`templateDir`) is not in it. That lives in `~/.gitconfig`, which you write by
hand and which never leaves the machine it was written on. Step 5 sets it up.

The same goes for anything else that is genuinely per-machine or per-project:
work VPN helpers go in `~/.config/zsh/local/`, and an SDK pin or a project's
BDD directories go in that project's own `.vscode/settings.json`, never here.

**4. `chezmoi apply` then runs the installer by itself** — Homebrew packages,
mise runtimes, frida/objection, tmux's plugin manager and the zsh plugins.
Takes a while on a fresh Mac.

**5. One manual finish — your git identity:**

```sh
git config --global user.email "you@example.com"
git config --global user.name  "Your Name"
```

If you want the Neovim Claude integration (`Cmd+L`, `Cmd+K`), install the
`claude` CLI too — it ships its own installer rather than a brew formula, so this
repo checks for it and does not install it. `claudecode.nvim` runs whatever
`claude` is on PATH. Claude and cursor-agent are the explicit cloud paths:
prompts and selected code leave the machine. Avante and aider are the local
paths; they use loopback Ollama and need no API credential. Which-key labels
the request-producing actions added by this repo as local or cloud so that
egress choice stays visible.

Nothing else is left to do by hand. `bootstrap.sh` restores the nvim plugins
from the committed lockfile (`nvim --headless "+Lazy! restore"`), installs the
tmux plugins (tpm's own `install_plugins`) and builds the `bat` theme cache,
then verifies all three.
Mason still installs its language servers on your first real `nvim` start —
that needs a running event loop, so no script can force it.

For later source changes, run `./audit.sh` before committing. It performs the
non-mutating contract, syntax, key-ownership and secret checks; `bootstrap.sh`
remains the applied-machine verification.

Optional, if this machine does backend work:

```sh
brewopt              # list the optional package groups
brewopt backend      # colima + docker + docker-compose + kubectl, ~1 GB
```

Those groups are the one place the machines are allowed to differ in *packages*,
and it is a command you run, not something the repo decides. The baseline
Brewfile is identical everywhere.

Those two `git config --global` lines write `~/.gitconfig`, the file this repo
does not manage. The pager, the editor and delta's theme are already in place
from `~/.config/git/config`. If this Mac talks to an employer's git host, add
the URL rewrite and hook `templateDir` to `~/.gitconfig` by hand as well —
that is machine-and-network config, not dotfiles.

Then open Ghostty fresh and you have the same environment.


### Or just copy the folder

`~/dotfiles` is an ordinary git repo — the bundle is only a
convenience for squeezing it through AirDrop. Copying the directory itself
(USB, AirDrop, iCloud) works identically and keeps the full history, because
`.git/` comes along with it. Drop it at `~/dotfiles` on the other
Mac and skip straight to:

```sh
cd ~/dotfiles && ./bootstrap.sh
```

Nothing in the repo is machine-specific, and there is no per-machine variant to
choose: a personal Mac and a work Mac run the identical configuration. What
makes them differ is what you add outside the repo afterwards.

---

## Option B — a private git repo (better long-term)

Worth doing once you want changes to flow between the two machines instead of
re-copying a file.

**On this Mac:**

```sh
gh auth login                      # only needed once
cd ~/dotfiles
gh repo create dotfiles --private --source=. --push
```

No `gh`? Create an **empty private** repo in the web UI, then:

```sh
cd ~/dotfiles
git remote add origin git@github.com:<you>/dotfiles.git
git push -u origin main
```

**On the other Mac** — steps 1–2 above collapse into a clone plus the script:

```sh
brew install git
git clone git@github.com:<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

`bootstrap.sh` also accepts the URL itself (`./bootstrap.sh git@github.com:…`)
and will clone for you — useful when you carried the single script over but not
the repo. It is not fetched with `curl | bash`: the repo is private, so a raw
URL would need credentials anyway, and piping a remote script into a shell is a
bad habit to bake into a bootstrap doc.

Without the script at all:

```sh
brew install chezmoi
chezmoi init --apply --source=~/dotfiles git@github.com:<you>/dotfiles.git
```

**The remote is public, so treat anything committed here as published.** It
carries no email address, internal hostname or employer project path — identity
is not a machine setting, so it lives in `~/.gitconfig` and the work repo path in
`~/.config/chezmoi/chezmoi.toml`, neither of which is in the source tree — and
keeping it that way is the whole job, because a mistake here is fetched and
cached rather than merely reverted. Run `gitleaks detect --no-git -s .` before
pushing. Do not use the internal GitLab for this either: a personal Mac
generally cannot reach it, and personal config does not belong on company
infrastructure.

---

## Living with it afterwards

**Log out once after the first apply.** `chezmoi apply` writes macOS defaults —
press-and-hold off and a fast key repeat, the two that make `hjkl` usable — and
the running login session has already read the old values. Finder and the menu
bar restart themselves; the keyboard does not.

The one rule that catches people out:

> Edit a config file normally (`~/.zshrc`, anything in `~/.config/nvim`), then
> run **`chezmoi re-add`** to pull the change back into the repo.
>
> Running `chezmoi apply` *without* re-adding will **overwrite your edit** with
> the stored version.

`chezmoi diff` shows anything out of sync; empty means you are clean.

| Command | What |
| --- | --- |
| `chezmoi re-add` | Capture local edits into the repo (aliased `cmr`) |
| `chezmoi diff` | What would change (aliased `cmd`) |
| `chezmoi apply` | Write repo → home |
| `chezmoi cd` / `cmcd` | Jump to the repo |
| `chezmoi update` | Pull from the remote and apply (Option B only) |

Then commit and push as usual from `~/dotfiles`.

---

## What is *not* carried across

Deliberately — these are secrets or machine state, and are excluded in
`.chezmoiignore`:

- `~/.ssh` keys, `~/.aws`, `~/.config/gcloud`, `~/.netrc`, `~/.git-credentials`
- Atuin's history database and sync key (only its `config.toml` travels)
- Xcode, Android SDK, the Flutter SDKs — installed by their own tooling.
- GUI editors — Cursor, Android Studio and Xcode are not installed or configured
  by this repository. Install only the ones needed on that Mac, using their own
  supported distribution channels.
  Flutter is intentionally per-repo via FVM, so there is nothing global to move.
- `~/.config/zsh/plugins/` and `~/.config/tmux/plugins/` — upstream git clones
  the installer re-fetches.
- `~/.config/zsh/local/` — machine-local shell modules. Employer-specific and
  credential-adjacent config lives here (VPN helpers, work-only tooling) and is
  sourced last so it can override any module. Deliberately never captured.
- **The Ollama model weights.** aider runs locally, so it needs no API key, but
  the weights are several GB and do not belong in a dotfiles repo. Start with
  `brew services start ollama`, then pull at least one supported tag:
  `qwen2.5-coder:7b`, `qwen2.5-coder:14b`, or `qwen3-coder:30b`.
  `bootstrap.sh` reports whether one is present but never downloads or selects
  it. In Neovim run `:AiModel` once per process; at a shell pass
  `--model ollama_chat/<tag>` explicitly.
- **`cursor-agent login`.** A browser flow, and therefore the one step here that
  `bootstrap.sh` genuinely cannot automate. `CURSOR_API_KEY` in
  `~/.config/zsh/local/` is the scriptable alternative. Verify with
  `cursor-agent --list-models` rather than `cursor-agent status`, which has been
  seen reporting a successful login for an account with no models available.
- aider's own state — `.aider.chat.history.md`, `.aider.input.history` and the
  `.aider.tags.cache.v*` symbol cache. aider writes these into whatever
  directory it runs in and offers to gitignore them per project; `.chezmoiignore`
  denies `.aider*` here with holes for the three managed files:
  `~/.aider.conf.yml`, `~/.aider.model.settings.yml`, and
  `~/.aider.model.metadata.json`. The last one keeps aider's prompt budget below
  Ollama's real per-model context; none carries credentials. The chat transcript
  is the most sensitive file this setup produces, because it contains whatever
  source was in context.
- `~/.claude.json` — Claude Code session state next to, not inside, `~/.claude/`.
  The `.claude/**` rule does not match a sibling file; without this line a
  `chezmoi add` would capture it. Skills under `~/.claude/skills/` still travel.
- `~/.config/configstore/` — OAuth token caches belonging to tools this repo does
  not manage but the machine has anyway. Regenerates per machine.
- `~/.config/flutter/settings` — records the Apple Developer signing identity,
  which is an email address. Regenerates per machine.
- `~/.gitconfig` — git identity and anything network- or employer-shaped:
  `[user]`, internal host rewrites, the corporate hook `templateDir`. Written by
  hand per machine. The managed half of git config is `~/.config/git/config`
  (pager, editor, delta theme); git reads both files, and `~/.gitconfig` wins on
  any key set in both.
- `~/Library/Application Support/Code/` — VS Code. Not an editor this setup uses:
  the managed IDE is Neovim and all GUI editor state is unmanaged. The file is
  owned by its extensions, which rewrite it, so managing it only ever committed
  things nobody chose.
- `~/.config/karabiner/` — the remaps are keyed to one external keyboard's
  `vendor_id`/`product_id`, and the profile holds a work VPN hotkey. Karabiner
  owns and rewrites the file, so set it up by hand on a new machine.

## Keeping the copy fresh

The zip is a snapshot. After changing anything, commit here and re-zip:

```sh
cd ~/dotfiles && chezmoi re-add && git add -A && git commit
cd ~ && rm -f ~/dotfiles.zip && zip -qr ~/dotfiles.zip dotfiles -x 'dotfiles/.claude/*' 'dotfiles/.git/hooks/*'
```
