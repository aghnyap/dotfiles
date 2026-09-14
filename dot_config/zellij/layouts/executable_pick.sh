#!/usr/bin/env bash
# Ctrl+o then p -- pick a project layout, then a directory, and build the
# session. The zellij port of dot_config/tmux/layouts/pick.sh; same fzf
# flow, zellij CLI underneath instead of tmux's.
set -euo pipefail

layout=$(printf '%s\n' mobile web backend sec arch \
  | fzf --height 40% --border-label ' layout ' --prompt '  ') || exit 0
[[ -n $layout ]] || exit 0

# Offer zoxide's known directories, falling back to ~/Repositories.
if command -v zoxide >/dev/null 2>&1; then
  dirs=$(zoxide query -l)
else
  dirs=$(find "$HOME/Repositories" -mindepth 1 -maxdepth 2 -type d 2>/dev/null)
fi

dir=$(printf '%s\n' "$dirs" \
  | fzf --height 80% --border-label " ${layout} -> directory " --prompt '  ') || exit 0
[[ -n $dir ]] || exit 0

name="$(basename "$dir" | tr '.:' '__')-${layout}"
layout_file="$HOME/.config/zellij/layouts/${layout}.kdl"

# zellij has no "switch-client" -- attach if the session already exists,
# otherwise start a new one with the layout and the picked directory. Unlike
# tmux, this cannot be run from inside another zellij session in the same
# terminal without detaching first (Ctrl+o d); running it via `Run` from a
# keybind, as config.kdl does, opens it in its own pane, so that limitation
# does not bite from there.
if zellij list-sessions -s 2>/dev/null | grep -qx "$name"; then
  exec zellij attach "$name"
fi
cd "$dir"
exec zellij --session "$name" --layout "$layout_file"
