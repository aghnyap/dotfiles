# Task runner for this chezmoi repo. NOT managed by chezmoi -- see
# .chezmoiignore -- because it is repo tooling, not a dotfile for $HOME.
# `just` is a hard prerequisite for working in this repo; bootstrap.sh installs
# it alongside Homebrew and chezmoi and nothing else.

# Bare `just` lists every recipe.
default:
    @just --list

# Non-mutating source-contract checks: syntax, AI budgets, key ownership,
# templates, Brewfile scope, gitleaks. Safe before any commit.
audit:
    ./audit.sh

# Secret scan on the working tree, no git history walked.
leaks:
    gitleaks detect --no-git -s .

# What `chezmoi apply` would change, without changing anything.
diff:
    chezmoi diff --source=.

# Same as `diff`, plus scripts that would run (run_onchange, run_once) --
# still makes no changes.
dry-run:
    chezmoi apply --source=. --dry-run --verbose

# Applies the source state to $HOME, then finishes the plugin installs that
# only make sense once it has (lazy.nvim needs its config in place first).
# Confirms first: this is the one recipe here that writes outside the repo
# and can overwrite an unstaged edit to a live dotfile (see CLAUDE.md,
# "chezmoi re-add").
apply:
    @echo "About to run: chezmoi apply --source=." >&2
    @read -p "Continue? [y/N] " ans; [ "$ans" = "y" ] || [ "$ans" = "Y" ] || { echo "aborted"; exit 1; }
    chezmoi apply --source=.
    @just plugins

# Finishes what `chezmoi apply` cannot do itself -- these used to be
# bootstrap.sh's job (its own "finish the installs" step); it now installs
# only Homebrew/apt, chezmoi and just, so this is where they live instead.
# Every step is guarded and safe to re-run.
plugins:
    #!/usr/bin/env bash
    set -uo pipefail
    if command -v bat >/dev/null 2>&1; then
      echo "==> bat theme cache"
      bat cache --build >/dev/null 2>&1 || echo "warn: bat cache --build failed" >&2
    fi
    if command -v nvim >/dev/null 2>&1; then
      echo "==> nvim plugins (lazy.nvim + Mason)"
      # Restore the committed lockfile rather than `sync`, which advances
      # plugin commits and rewrites lazy-lock.json. Mason installs its tools
      # on the first real nvim start; nothing headless can force that.
      nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || echo "warn: nvim plugin restore failed; open nvim and run :Lazy restore" >&2
    fi
    tpm_install="$HOME/.config/tmux/plugins/tpm/bin/install_plugins"
    if [[ -x $tpm_install ]]; then
      echo "==> tmux plugins (tpm)"
      tmux -L bootstrap new-session -d 2>/dev/null || true
      tmux -L bootstrap run-shell "$tpm_install" >/dev/null 2>&1 || echo "warn: tpm install failed; open tmux and press prefix + I" >&2
      tmux -L bootstrap kill-server 2>/dev/null || true
    fi

# Everything to run before committing.
check: audit leaks

# Everything to run before pushing to the public remote: the commit checks,
# plus proof the source and $HOME have not drifted, plus the employer-domain
# grep from CLAUDE.md's verification section.
pre-push: check
    @test -z "$(chezmoi diff --source=. )" || { echo "chezmoi diff is not empty -- re-add or revert before pushing" >&2; exit 1; }
    @domain=$$(git config user.email | cut -d@ -f2); \
    match=$$(grep -rIl -iF "$${domain%%.*}" ~/.config ~/Library/Application\ Support/Code 2>/dev/null); \
    if [ -n "$$match" ]; then echo "employer-domain match found in managed config:" >&2; echo "$$match" >&2; exit 1; fi
    @echo "pre-push checks passed"
