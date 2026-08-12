#!/usr/bin/env bash
# Takes a bare Mac to this exact environment -- same prompt, same fonts, same
# toolchain -- in one command.
#
# This is the scripted form of INSTALL.md. It is idempotent: re-running it on a
# configured machine re-applies and re-verifies rather than duplicating work.
#
#   ./bootstrap.sh                      # repo already on disk; run from inside it
#   ./bootstrap.sh <url-or-path>        # clone from a private remote, or copy from a path
#
# There are no flags for what kind of machine this is, because there is no such
# distinction: every Mac built from this repo gets the same configuration. It
# also asks nothing and needs no TTY -- not who you are, not where you work.
# Identity, employer network config and per-project paths live outside the
# repo, in ~/.gitconfig, ~/.config/zsh/local/ and each project's own workspace
# settings. The verification step reports a missing git identity and moves on.
#
# There is deliberately no default remote baked in: this repo has none, and
# while it carries no address or internal hostname of its own, it is still a
# full description of one person's machine. Sneakernet (INSTALL.md option A) or
# a private remote you pass in.
set -euo pipefail

SOURCE_DIR="$HOME/dotfiles"
REMOTE=""          # git URL, when cloning
LOCAL_COPY=""      # directory to copy from, when not already in place

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\033[34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case $1 in
    # Print the header block itself, so the usage text cannot drift from it.
    -h|--help)  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    -*)         die "unknown flag: $1" ;;
    *)
      # A URL for chezmoi to clone, or a directory already holding the repo.
      if [[ $1 == *://* || $1 == git@* || $1 == *.git ]]; then
        REMOTE=$1
      elif [[ -d $1 ]]; then
        LOCAL_COPY=$(cd "$1" && pwd)
      else
        die "not a git URL and not an existing directory: $1"
      fi
      shift ;;
  esac
done

[[ $(uname -s) == Darwin ]] || die "macOS only; this is $(uname -s)"
[[ $(uname -m) == arm64 ]] || warn "not arm64 -- Homebrew will land in /usr/local, not /opt/homebrew"

# ── 1. Homebrew ────────────────────────────────────────────────────────────
# Every later step (chezmoi, git, the Brewfile) depends on this, and a fresh
# Mac has no brew on PATH even after the installer runs -- hence the shellenv.
if ! command -v brew >/dev/null 2>&1; then
  step "Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
for prefix in /opt/homebrew /usr/local; do
  [[ -x $prefix/bin/brew ]] && eval "$("$prefix/bin/brew" shellenv)" && break
done
command -v brew >/dev/null 2>&1 || die "Homebrew installed but not on PATH"

step "chezmoi + git"
brew list chezmoi >/dev/null 2>&1 || brew install chezmoi
brew list git     >/dev/null 2>&1 || brew install git

# ── 2. Get the repo to ~/dotfiles ───────────────────────────────────────────
# chezmoi's own config records sourceDir, but only once it exists -- see the
# comment in .chezmoi.toml.tmpl. So the source has to be in place, and named
# explicitly with --source, before init.
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ -n $LOCAL_COPY ]]; then
  mkdir -p "$(dirname "$SOURCE_DIR")"
  if [[ -e $SOURCE_DIR ]]; then
    # Never clobber an existing checkout -- it may hold uncommitted work.
    step "repo already at $SOURCE_DIR, leaving it alone"
  else
    step "copying repo from $LOCAL_COPY"
    cp -R "$LOCAL_COPY" "$SOURCE_DIR"
  fi
elif [[ -f "$here/.chezmoi.toml.tmpl" ]]; then
  # Running from inside a checkout: that checkout is the source of truth.
  SOURCE_DIR=$here
elif [[ -z $REMOTE ]]; then
  die "no repo found. Run this from inside the checkout, or pass a private git URL / a path to a copy."
fi

# ── 3. Init + apply ─────────────────────────────────────────────────────────
# --no-tty is safe and deliberate: .chezmoi.toml.tmpl has no prompts left, so
# there is nothing to answer and nothing to feed on stdin. It also makes the
# failure honest -- if a prompt is ever added back, this dies with a clear EOF
# instead of hanging a CI or a `curl | bash` run waiting on a terminal.
step "chezmoi init --apply (installs the Brewfile; slow on a fresh Mac)"
if [[ -n $REMOTE ]]; then
  chezmoi init --apply --no-tty --source="$SOURCE_DIR" "$REMOTE"
else
  chezmoi init --apply --no-tty --source="$SOURCE_DIR"
fi

# ── 4. Finish the installs that used to be manual ───────────────────────────
# These were printed as "two manual finishes" and are the difference between one
# command and three. Both are idempotent and both are safe headless.
#
# `bat cache --build` is not optional housekeeping: ~/.config/bat/config selects
# --theme="tokyonight_night", and a theme dropped into ~/.config/bat/themes is
# invisible until it is compiled into the cache. Until then bat, delta, lazygit's
# diff view and every fzf preview name a theme that does not resolve.
if command -v bat >/dev/null 2>&1; then
  step "bat theme cache"
  bat cache --build >/dev/null 2>&1 || warn "bat cache --build failed; the tokyonight theme will not resolve"
fi

if command -v nvim >/dev/null 2>&1; then
  step "nvim plugins (lazy.nvim + Mason; slow on a fresh Mac)"
  # `Lazy! sync` is the headless form: ! means no-wait, so it installs, cleans
  # and returns instead of opening the UI. Mason then installs its tools on the
  # first real start; nothing here can force that without a running event loop.
  nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || warn "nvim plugin sync failed; open nvim and run :Lazy sync"
fi

tpm_install="$HOME/.config/tmux/plugins/tpm/bin/install_plugins"
if [[ -x $tpm_install ]]; then
  step "tmux plugins (tpm)"
  # tpm's installer needs a server to talk to. Use a throwaway one rather than
  # touching a session the user may already have running.
  tmux -L bootstrap new-session -d 2>/dev/null || true
  TMUX= "$tpm_install" >/dev/null 2>&1 || warn "tpm install failed; open tmux and press prefix + I"
  tmux -L bootstrap kill-server 2>/dev/null || true
fi

# ── 5. Verify the look actually landed ──────────────────────────────────────
# First, put on PATH the two directories ~/.zshenv adds for interactive shells.
# This script is bash and was started before any of this was installed, so it
# never inherited them -- without this the checks below report ruby, java,
# frida-ps, objection and claude as MISSING on a fresh Mac moments after
# installing them, which is a false alarm that teaches you to ignore the output.
#
# mise shims resolve node/java/ruby; ~/.local/bin holds the uv-installed tools
# and the claude CLI.
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

# The font is the part that fails quietly: starship and Neovim both draw happily
# with a missing Nerd Font, just with blanks where the glyphs belong.
step "verifying"
fail=0
check() { if eval "$2" >/dev/null 2>&1; then printf '  ok      %s\n' "$1"; else printf '  MISSING %s\n' "$1"; fail=1; fi; }

check "ghostty"                'test -d /Applications/Ghostty.app'
check "JetBrainsMono Nerd Font" 'compgen -G "$HOME/Library/Fonts/JetBrainsMonoNerdFont*"'
check "starship"               'command -v starship'
check "nvim plugins"           'test -d "$HOME/.local/share/nvim/lazy/lazy.nvim"'
check "tmux plugins"           'compgen -G "$HOME/.config/tmux/plugins/tmux-*"'
check "zsh plugins"            'test -d "$HOME/.config/zsh/plugins/fzf-tab"'
check "oh-my-zsh"              'test -d "$HOME/.oh-my-zsh"'
# ruby comes from mise now, not rbenv. Check the gem binaries rather than the
# interpreter: a mise ruby with no cocoapods is the failure that actually bites,
# and `gem install` runs in the installer script where it can fail quietly.
check "ruby (mise)"            'ruby --version | grep -q "3\.3"'
check "cocoapods"              'command -v pod'
check "fastlane"               'command -v fastlane'
check "bat theme registered"   'bat --list-themes | grep -q tokyonight_night'
# A login shell must start silently. An unguarded `source` or a missing tool in
# ~/.zshenv shows up here and nowhere else -- it is invisible to every check
# above, because none of them starts a shell.
check "clean login shell"      'test -z "$(zsh -lic true 2>&1 | grep -v "can.t change option: zle")"'
# adb is not installed by this repo (the Android SDK is out of scope) but the
# logcat helpers, the tmux sec layout and the mobilesec MCP server all shell out
# to it, so report it rather than let those fail later with no explanation.
check "adb (see brewopt mobilesec)" 'command -v adb'
# macOS ships a `java` stub that exists and then refuses to run, so `command -v`
# proves nothing -- ask for a version instead. mise owns java (pinned temurin-17 in
# its config), so this should pass on any machine the installer has finished on;
# a failure here means `mise install` did not complete, and Gradle and jdtls will
# both be broken.
check "a working JDK"          'java -version 2>&1 | grep -qv "Unable to locate"'
check "frida (uv tool)"        'command -v frida-ps'
check "objection (uv tool)"    'command -v objection'
# claudecode.nvim runs the `claude` binary from PATH with auto_start = true, so
# Cmd+L does nothing without it. Claude Code ships its own installer and is not a
# brew formula, which is why this is a check and not a Brewfile line.
check "claude CLI (Cmd+L)"     'command -v claude'
# --exclude=scripts: run_onchange scripts show as a pending diff whenever their
# hash has not been recorded yet, which says nothing about the configs.
#
# --source is not optional here. Without it `chezmoi diff` reads the DEFAULT
# source dir, which on a checkout living anywhere else is empty -- so it prints
# nothing, and this check passes while managing no files at all.
check "in sync (chezmoi diff)" 'test -z "$(chezmoi diff --source="$SOURCE_DIR" --exclude=scripts)"'

# Braille art and nf-md-* icons both need the patched font; a stale codepoint
# renders as nothing rather than tofu, so check one glyph we actually use.
if command -v fc-list >/dev/null 2>&1; then
  check "glyph U+F0035 (md-apple)" \
    "fc-list ':charset=F0035' family | grep -qi 'jetbrainsmono nerd font'"
fi

if (( fail )); then
  warn "something above is missing -- the prompt, the icons or a toolchain."
  # NOT `chezmoi apply --force`. That re-writes files but skips run_onchange
  # scripts entirely: chezmoi keys those on a hash recorded in the scriptState
  # bucket of chezmoistate.boltdb, and --force does not clear it. Dropping the
  # bucket is what actually makes the Brewfile script run again.
  warn "to re-run the package install: chezmoi state delete-bucket --bucket=scriptState && chezmoi apply"
fi

# ── 5. What cannot be scripted ──────────────────────────────────────────────
cat <<'EOF'

==> Done. Plugins, tools and the bat theme cache are already installed above.

    Mason finishes its language servers on your first real `nvim` start -- that
    needs a running event loop, so no script can force it.

    Then open Ghostty fresh.
EOF

# Git identity is reported, never written. This script configures a machine; who
# commits from it is not its business, and ~/.gitconfig is not in the repo.
if ! git config --get user.email >/dev/null 2>&1; then
  cat <<'EOF'

==> git has no identity yet. That is on purpose -- ~/.gitconfig is yours, not
    this repo's. Set it up when you want to commit:

      git config --global user.email "you@example.com"
      git config --global user.name  "Your Name"

    The pager, the delta theme and the editor are already configured, in
    ~/.config/git/config. Anything employer-specific -- internal host
    rewrites, a hook templateDir -- goes in ~/.gitconfig by hand.
EOF
fi
