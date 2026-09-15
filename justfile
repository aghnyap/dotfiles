# Task runner for this chezmoi repo. NOT managed by chezmoi -- see
# .chezmoiignore.tmpl -- because it is repo tooling, not a dotfile for $HOME.
# `just` is a hard prerequisite for working in this repo; bootstrap.sh installs
# it alongside Homebrew/apt and chezmoi and nothing else.

# `just` defaults to POSIX `sh` for any recipe line without its own `#!`
# shebang (the `apply`/`pre-push` one-liners below) -- `sh` on Ubuntu is
# dash, which has no `read -p` and no `$(...)` quirks this was written
# against. Recipes that already carry their own `#!/usr/bin/env bash`
# shebang (plugins, verify, tldr-test, linux-render) run as their own
# script regardless of this setting; this only covers the plain ones.
set shell := ["bash", "-euo", "pipefail", "-c"]

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

# Pull a live edit (~/.zshrc, anything in ~/.config/nvim, ...) back into the
# repo. Shows the diff first so re-adding an app-owned file (see CLAUDE.md's
# re-add gotchas) is a decision, not an accident -- non-destructive to
# $HOME either way, and anything it changes in the repo is git-tracked and
# reversible.
readd:
    @echo "About to pull these live changes into the repo:" >&2
    @chezmoi diff --source=. --reverse
    chezmoi re-add --source=.

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

# Everything to run before committing.
check: audit leaks

# Everything to run before pushing to the public remote: the commit checks,
# plus proof the source and $HOME have not drifted, plus the employer-domain
# grep from CLAUDE.md's verification section.
pre-push: check
    @test -z "$(chezmoi diff --source=. )" || { echo "chezmoi diff is not empty -- re-add or revert before pushing" >&2; exit 1; }
    @domain=$(git config user.email | cut -d@ -f2); \
    if [ -z "$domain" ]; then echo "no git user.email set -- skipping the employer-domain check" >&2; exit 0; fi; \
    match=$(grep -rIl -iF "${domain%%.*}" ~/.config ~/Library/Application\ Support/Code 2>/dev/null); \
    if [ -n "$match" ]; then echo "employer-domain match found in managed config:" >&2; echo "$match" >&2; exit 1; fi
    @echo "pre-push checks passed"

# Applied-machine "does it actually look and feel right" verification --
# what bootstrap.sh used to check before it was narrowed to three
# prerequisites. Checks the CURRENTLY APPLIED ~/.config tree, so it is only
# meaningful after `just apply` has actually run at least once. Every check
# is informational (MISSING, not a hard failure) except the login-shell one.
verify:
    #!/usr/bin/env bash
    set -uo pipefail
    fail=0
    check() { if eval "$2" >/dev/null 2>&1; then printf '  ok      %s\n' "$1"; else printf '  MISSING %s\n' "$1"; fail=1; fi; }
    echo "==> verifying the applied environment"
    check "chezmoi in sync (just diff)" 'test -z "$(chezmoi diff --source=. --exclude=scripts)"'
    check "oh-my-zsh"                'test -d "$HOME/.oh-my-zsh"'
    check "starship"                 'command -v starship'
    check "tealdeer custom pages"    'test -f "$HOME/.config/tealdeer/pages/dotfiles.page.md"'
    check "zellij config"            'zellij --config "$HOME/.config/zellij/config.kdl" setup --check 2>&1 | grep -q "Well defined"'
    check "nvim plugins"             'test -d "$HOME/.local/share/nvim/lazy/lazy.nvim"'
    check "bat theme registered"     'bat --list-themes | grep -q tokyonight_night'
    # A login shell must start silently -- an unguarded `source` or a
    # missing tool in ~/.zshenv shows up here and nowhere else, since none
    # of the checks above start a real shell. The "can't change option: zle"
    # line is expected noise from running interactive mode with no ZLE.
    check "clean login shell"        'test -z "$(zsh -lic true 2>&1 | grep -v "can.t change option: zle")"'
    if command -v fc-list >/dev/null 2>&1; then
      check "JetBrainsMono Nerd Font glyph U+F0035" \
        "fc-list ':charset=F0035' family | grep -qi 'jetbrainsmono nerd font'"
    fi
    if (( fail )); then
      echo "warn: something above is missing -- re-run 'just apply' or install it by hand" >&2
    fi
    exit "$fail"

# Render every custom tealdeer *.page.md standalone (no cache, no config
# dependency -- `tldr --render` just parses the file) to catch a malformed
# page before it ships. *.patch.md files are deliberately skipped: they are
# fragments meant to append to an upstream page, not valid standalone pages.
tldr-test:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    for f in dot_config/tealdeer/pages/*.page.md; do
      if tldr --render "$f" >/dev/null 2>&1; then
        printf '  ok      %s\n' "$f"
      else
        printf '  FAIL    %s\n' "$f" >&2
        fail=1
      fi
    done
    exit "$fail"

# Renders the baseline Brewfile and installer script as Linux would see
# them, and dry-run applies inside a throwaway Homebrew-on-Ubuntu container
# -- the one check that exercises the `.chezmoi.os "linux"` branches this
# machine can never take itself. Needs podman (baseline Brewfile);
# `podman machine start` first if the VM is not already running.
linux-render:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> rendering Brewfile and installer as Linux"
    podman run --rm -v "$PWD:/src:ro" -w /src ghcr.io/homebrew/ubuntu24.04 bash -c '
      set -e
      brew install -q chezmoi >/dev/null
      # No os override needed -- chezmoi detects .chezmoi.os from the
      # platform it actually runs on, and this IS linux, from inside here.
      chezmoi execute-template --source=/src < .chezmoitemplates/Brewfile > /tmp/Brewfile.linux 2>&1 || {
        echo "Brewfile: FAILED to render" >&2; cat /tmp/Brewfile.linux >&2; exit 1;
      }
      brew bundle list --file=/tmp/Brewfile.linux --formula --cask >/dev/null
      echo "Brewfile: renders and parses on linux"
      chezmoi execute-template --source=/src < run_onchange_before_install-packages.sh.tmpl > /tmp/install.linux.sh
      bash -n /tmp/install.linux.sh
      echo "installer script: renders and is valid bash on linux"
    '