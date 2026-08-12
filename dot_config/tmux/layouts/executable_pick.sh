#!/usr/bin/env bash
# prefix + P -- pick a layout, then a directory, and build the session.
set -euo pipefail

layout=$(printf '%s\n' mobile web backend sec \
  | fzf-tmux -p 40%,30% --border-label ' layout ' --prompt '  ') || exit 0
[[ -n $layout ]] || exit 0

# Offer zoxide's known directories, falling back to ~/Repositories.
if command -v zoxide >/dev/null 2>&1; then
  dirs=$(zoxide query -l)
else
  dirs=$(find "$HOME/Repositories" -mindepth 1 -maxdepth 2 -type d 2>/dev/null)
fi

dir=$(printf '%s\n' "$dirs" \
  | fzf-tmux -p 80%,60% --border-label " ${layout} -> directory " --prompt '  ') || exit 0
[[ -n $dir ]] || exit 0

exec "$HOME/.config/tmux/layouts/layout.sh" "$layout" "$dir"
