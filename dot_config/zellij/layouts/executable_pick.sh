#!/usr/bin/env bash
# Launch (or interactively pick) a zellij project-layout session.
#
#   pick.sh                  -- interactive: fzf a layout, then a directory
#                                (bound at Ctrl+o p in config.kdl)
#   pick.sh <layout> <dir>   -- direct, no prompts -- what `ide` (zsh
#                                function, functions.zsh) calls
#
# The single shared launcher for both paths, so there is one place that
# knows how to actually start a session instead of two that could drift.
set -euo pipefail

layout=${1:-}
dir=${2:-}

if [[ -z $layout ]]; then
  layout=$(printf '%s\n' mobile web backend sec arch \
    | fzf --height 40% --border-label ' layout ' --prompt '  ') || exit 0
  [[ -n $layout ]] || exit 0
fi

if [[ -z $dir ]]; then
  # Offer zoxide's known directories, falling back to ~/Repositories.
  if command -v zoxide >/dev/null 2>&1; then
    dirs=$(zoxide query -l)
  else
    dirs=$(find "$HOME/Repositories" -mindepth 1 -maxdepth 2 -type d 2>/dev/null)
  fi
  dir=$(printf '%s\n' "$dirs" \
    | fzf --height 80% --border-label " ${layout} -> directory " --prompt '  ') || exit 0
  [[ -n $dir ]] || exit 0
fi

name="$(basename "$dir" | tr '.:' '__')-${layout}"
layout_file="$HOME/.config/zellij/layouts/${layout}.kdl"

if [[ -n ${ZELLIJ:-} ]]; then
  # Already inside a session: zellij has no "switch-client" the way tmux
  # did, and attaching to a DIFFERENT session from inside one needs a
  # detach first (Ctrl+o d) -- so open the layout as a new tab in this
  # session instead, which needs no detach and does not collide with the
  # single-session-per-project intent (the tab is just named after it).
  exec zellij action new-tab --layout "$layout_file" --cwd "$dir" --name "$name"
fi

# Not inside a session: attach to an existing one for this project, or
# start a new one with the layout and the picked directory.
if zellij list-sessions -s 2>/dev/null | grep -qx "$name"; then
  exec zellij attach "$name"
fi
cd "$dir"
exec zellij --session "$name" --layout "$layout_file"
