# zellij -- persistent per-project sessions. Replaced tmux outright (see
# .chezmoitemplates/Brewfile).
#
# No `zellij init zsh` hook exists -- unlike direnv/starship/etc., zellij has
# no shell-integration script to source, so this module is functions only.

# zj [name] -- attach to a session, or create one named after the current dir.
# This cannot switch out of an already-attached session in the same
# terminal: zellij has no `switch-client` equivalent (tmux's `tm` had one),
# so it refuses instead of doing something confusing. Detach first
# (Ctrl+o d).
zj() {
  if [[ -n $ZELLIJ ]]; then
    print -u2 "zj: already inside a zellij session -- detach first (Ctrl+o d)"
    return 1
  fi
  local name="${1:-${PWD:t}}"
  name=${name//[.:]/_}
  zellij attach --create "$name"
}

# zjp -- interactive project layout picker (fzf a layout, then a
# directory). `ide` (functions.zsh) and zellij's own Ctrl+o p binding call
# the same script directly, with the layout and directory already known,
# skipping the prompts this gives you.
zjp() { "$HOME/.config/zellij/layouts/pick.sh"; }
