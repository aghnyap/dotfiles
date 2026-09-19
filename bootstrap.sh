#!/usr/bin/env bash
# Gets a bare macOS or Ubuntu machine to the point where `just` and
# `chezmoi` exist and the repo is registered as chezmoi's source. That is
# this script's whole job now -- everything past it (installing the
# Brewfile, applying configs, verifying the result) is a `justfile` recipe,
# not a bash step. See CLAUDE.md, "`just` is a hard prerequisite".
#
#   ./bootstrap.sh                      # repo already on disk; run from inside it
#   ./bootstrap.sh <url-or-path>        # clone from a remote, or copy from a path
#
# There are no flags for what kind of machine this is beyond the OS itself,
# because there is no other distinction: every Mac built from this repo gets
# the same configuration, and so does every Ubuntu box. It also asks nothing
# and needs no TTY -- not who you are, not where you work. Identity,
# network-specific config and per-project paths live outside the repo, in
# ~/.gitconfig, ~/.config/zsh/local/ and each project's own workspace
# settings.
#
# No default remote is baked in, even though the repo has one. A URL in here
# would be this checkout's remote asserted as everyone's, and the argument
# form already covers it. Sneakernet (INSTALL.md option A) or a URL you pass in.
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

OS=$(uname -s)
case $OS in
  Darwin) ;;
  Linux)  ;;
  *) die "macOS or Linux only; this is $OS" ;;
esac
[[ $OS == Darwin && $(uname -m) != arm64 ]] && warn "not arm64 -- Homebrew will land in /usr/local, not /opt/homebrew"

# ── 1. Homebrew (or apt, on Ubuntu, as its prerequisite) ────────────────────
# Every later step (chezmoi, just, the Brewfile once applied) depends on this.
if ! command -v brew >/dev/null 2>&1; then
  if [[ $OS == Linux ]]; then
    step "apt prerequisites for Homebrew"
    # Homebrew's own install docs list these as required on Debian/Ubuntu --
    # a bare Ubuntu box has none of them.
    sudo apt-get update -qq
    sudo apt-get install -y build-essential procps curl file git
  fi
  step "Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  [[ -x $prefix/bin/brew ]] && eval "$("$prefix/bin/brew" shellenv)" && break
done
command -v brew >/dev/null 2>&1 || die "Homebrew installed but not on PATH"

# ── 2. chezmoi + just ────────────────────────────────────────────────────────
step "chezmoi + just"
brew list chezmoi >/dev/null 2>&1 || brew install chezmoi
brew list just    >/dev/null 2>&1 || brew install just

# ── 3. Get the repo to ~/dotfiles ────────────────────────────────────────────
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

# ── 4. Register the source with chezmoi -- init only, never apply ──────────
# --no-tty is safe and deliberate: .chezmoi.toml.tmpl has no prompts left, so
# there is nothing to answer and nothing to feed on stdin. It also makes the
# failure honest -- if a prompt is ever added back, this dies with a clear EOF
# instead of hanging a CI or a `curl | bash` run waiting on a terminal.
#
# Deliberately `init`, not `init --apply`: applying writes to $HOME and runs
# the package installer, which is the one step this repo's safety rules say
# must be announced and confirmed, not folded into an unattended bootstrap.
# `just apply` is that confirmed step -- see CLAUDE.md.
step "chezmoi init (registers the source; does not touch \$HOME yet)"
if [[ -n $REMOTE ]]; then
  chezmoi init --no-tty --source="$SOURCE_DIR" "$REMOTE"
else
  chezmoi init --no-tty --source="$SOURCE_DIR"
fi

# ── 5. Verify -- only the three things this script is responsible for ───────
step "verifying"
fail=0
check() { if eval "$2" >/dev/null 2>&1; then printf '  ok      %s\n' "$1"; else printf '  MISSING %s\n' "$1"; fail=1; fi; }

check "Homebrew" 'command -v brew'
check "chezmoi"  'command -v chezmoi'
check "just"     'command -v just'

if (( fail )); then
  die "one of Homebrew/chezmoi/just did not install correctly -- see above"
fi

cat <<EOF

==> Done: Homebrew, chezmoi and just are installed, and $SOURCE_DIR is
    registered as chezmoi's source.

    Next, from $SOURCE_DIR:
      just dry-run    # preview what applying would do -- no changes made
      just apply      # applies it -- installs the Brewfile, writes configs
      just check      # audit + gitleaks, before you commit anything

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
    ~/.config/git/config. Anything network-specific -- internal host
    rewrites, a hook templateDir -- goes in ~/.gitconfig by hand.
EOF
fi
