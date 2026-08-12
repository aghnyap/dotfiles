# ╭──────────────────────────────────────────────────────────────────────────╮
# │  fzf -- Tokyo Night (night)                                              │
# ╰──────────────────────────────────────────────────────────────────────────╯

(( $+commands[fzf] )) || return 0

# fd honours .gitignore by default, which is almost always what you want in a
# repo; --hidden brings back dotfiles, and .git itself is excluded explicitly.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

export FZF_DEFAULT_OPTS="
  --height=60%
  --layout=reverse
  --border=rounded
  --info=inline-right
  --pointer='▶'
  --marker='✓'
  --prompt='  '
  --color=bg+:#283457,bg:#16161e,border:#27a1b9,fg:#c0caf5
  --color=gutter:#16161e,header:#ff9e64,hl+:#2ac3de,hl:#2ac3de
  --color=info:#545c7e,marker:#ff007c,pointer:#ff007c,prompt:#2ac3de
  --color=query:#c0caf5:regular,scrollbar:#27a1b9,separator:#ff9e64,spinner:#ff007c
  --bind='ctrl-/:toggle-preview'
  --bind='ctrl-u:preview-half-page-up'
  --bind='ctrl-d:preview-half-page-down'
  --bind='ctrl-y:execute-silent(printf {} | pbcopy)+abort'
"

export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || eza --tree --level=2 --icons --color=always {}'
  --preview-window=right:60%:border-left
"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"
export FZF_CTRL_R_OPTS="--preview 'printf {2..}' --preview-window=down:3:wrap --border-label=' history '"

# ── fzf-tab ─────────────────────────────────────────────────────────────────
# Renders zsh's completion menu through fzf. Sourced from .zshrc after compinit.
zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border=rounded
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*'  fzf-preview 'eza --tree --level=2 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:z:*'   fzf-preview 'eza --tree --level=2 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:*:*'   fzf-preview \
  '[[ -d $realpath ]] && eza --tree --level=2 --icons --color=always $realpath \
   || bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null'
# git shows structured previews rather than a raw file listing
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
  'git diff --color=always $word 2>/dev/null || bat --color=always $word'
zstyle ':fzf-tab:complete:git-(checkout|switch):*'  fzf-preview \
  'git log --oneline --graph --color=always -20 $word 2>/dev/null'
