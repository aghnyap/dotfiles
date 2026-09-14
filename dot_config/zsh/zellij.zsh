# zellij -- persistent per-project sessions, alongside tmux (see
# dot_config/zellij/config.kdl's header for why both still exist).
#
# No `zellij init zsh` hook exists -- unlike direnv/starship/etc., zellij has
# no shell-integration script to source, so this module is functions only.

# zj [name] -- attach to a session, or create one named after the current dir.
# Unlike tmux's `tm`, this cannot switch out of an already-attached session
# in the same terminal: zellij has no `switch-client` equivalent, so it
# refuses instead of doing something confusing. Detach first (Ctrl+o d).
zj() {
  if [[ -n $ZELLIJ ]]; then
    print -u2 "zj: already inside a zellij session -- detach first (Ctrl+o d)"
    return 1
  fi
  local name="${1:-${PWD:t}}"
  name=${name//[.:]/_}
  zellij attach --create "$name"
}

# zjp -- project layout picker (mobile/web/backend/sec/arch), same fzf flow
# as tmux's `prefix + P`. Also bound inside zellij itself at Ctrl+o p.
zjp() { "$HOME/.config/zellij/layouts/pick.sh"; }
