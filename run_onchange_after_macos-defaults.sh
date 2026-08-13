#!/usr/bin/env bash
# macOS system behaviour. The only part of this repo that reaches outside $HOME.
#
# `run_onchange_after_` -- chezmoi hashes this file and re-runs it only when the
# contents change, after everything else has been applied. So it is cheap on
# every apply and self-healing when a setting is added here.
#
# Scope is deliberately narrow: machine BEHAVIOUR, not taste. Nothing about the
# Dock's contents, the wallpaper, or window arrangement -- those are personal and
# this repo is the development environment only. Every value below is a generic
# default with no path, name or identifier specific to any machine or person.
#
# Most of these need a logout to take effect. The keyboard ones especially: the
# running WindowServer session has already read them.
set -euo pipefail

echo "==> macOS defaults"

# ── Keyboard ────────────────────────────────────────────────────────────────
# This is the reason the file exists.
#
# ApplePressAndHoldEnabled makes holding a key show the accent picker (á à â)
# instead of repeating the character. That is correct for writing prose and
# useless for `hjkl`, holding `j` to scroll, or any modal editor. It was already
# off on the machine this was written on -- set by hand, and lost on any rebuild,
# which is exactly the kind of thing that belongs here.
defaults write -g ApplePressAndHoldEnabled -bool false

# Below what System Settings' slider can reach. 2 is ~30ms between repeats and 15
# is ~225ms before the first one; the macOS defaults are 6 and 25.
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

# Autocorrect and smart punctuation rewrite what you type. In a terminal-first
# setup that mostly means mangled code in any native text field -- smart quotes
# in particular produce " and " which no compiler accepts.
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false

# ── Finder ──────────────────────────────────────────────────────────────────
# Show what is actually there: real extensions, the full path, hidden files.
defaults write -g AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
# List view by default, rather than whatever a folder was last left in.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Search the current folder, not the whole Mac.
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# Skip the "are you sure you want to change the extension" panel.
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Do not litter network shares and USB drives with .DS_Store files. This one is
# a courtesy to everyone else who touches those volumes.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Screenshots ─────────────────────────────────────────────────────────────
# Out of the Desktop, which is otherwise where they accumulate forever. $HOME is
# resolved at run time, so this carries no absolute path.
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# ── Apply ───────────────────────────────────────────────────────────────────
# Finder and SystemUIServer re-read on relaunch; the keyboard settings do not,
# and need a logout. `|| true` because killall exits non-zero when a process is
# not running, and `set -e` would take the whole apply down with it.
killall Finder SystemUIServer 2>/dev/null || true

echo "    done. Keyboard settings need a logout to take effect."
