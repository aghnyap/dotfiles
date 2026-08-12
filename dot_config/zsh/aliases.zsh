# ── Modern replacements ─────────────────────────────────────────────────────
# Each keeps the original reachable: `command ls`, or the \-prefixed form.
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza --icons --group-directories-first -l --git --time-style=long-iso'
  alias la='eza --icons --group-directories-first -la --git --time-style=long-iso'
  alias lt='eza --icons --tree --level=2 --git-ignore'
  alias ltt='eza --icons --tree --level=4 --git-ignore'
fi

if (( $+commands[bat] )); then
  alias cat='bat --paging=never'
  alias catp='bat --paging=never --plain'   # no line numbers/gutter, for piping
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT='-c'
fi

(( $+commands[btop] ))     && alias top='btop'
(( $+commands[dust] ))     && alias du='dust'
(( $+commands[duf] ))      && alias df='duf'
(( $+commands[procs] ))    && alias ps='procs'
(( $+commands[rg] ))       && alias grep='rg'
(( $+commands[hexyl] ))    && alias hex='hexyl'
# tlrc installs its binary as `tldr` -- no alias needed.

# ── Navigation ──────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ── Git ─────────────────────────────────────────────────────────────────────
# The ~200 oh-my-zsh git aliases (glog, gst, gcmsg, gwip, gco, gd, …) live in
# git-aliases.zsh, vendored so they survive dropping the framework.
#
# Nothing is redefined here that oh-my-zsh already defines. An earlier version
# of this file re-invented a small subset under names oh-my-zsh was already
# using, with DIFFERENT meanings -- and two of those were dangerous against
# muscle memory:
#     gst   omz: git status          was redefined to: git stash
#     gca   omz: git commit --all    was redefined to: git commit --amend
#     gl    omz: git pull            was redefined to: git log
#     gcm   omz: git checkout main   was redefined to: git commit -m
# oh-my-zsh wins all of them. It already had better-named equivalents for the
# intent behind each (glog/glol, gsta/gstp, gc!/gcn!, gcmsg).
#
# Only genuinely-new names belong below.
alias gs='git status --short --branch'                 # omz has gst/gss, not this exact form
alias gla='git log --oneline --graph --decorate --all -30'
alias gpl='git pull --rebase'                          # omz `gl` is a plain pull
alias lg='lazygit'                                     # `g` is omz's alias for git itself

# ── Editor ──────────────────────────────────────────────────────────────────
alias v='nvim'
alias vi='nvim'
alias vim='nvim'
export EDITOR='nvim'
export VISUAL='nvim'

# ── Config shortcuts ────────────────────────────────────────────────────────
alias zc='nvim ~/.zshrc'
alias zca='nvim ~/.config/zsh/aliases.zsh'
alias zcd='nvim ~/.config/zsh/dev.zsh'
alias zr='exec zsh'                        # reload by replacing the shell
alias vc='nvim ~/.config/nvim'
alias gc-conf='nvim ~/.config/ghostty/config'
alias tc='nvim ~/.config/tmux/tmux.conf'

# ── chezmoi ─────────────────────────────────────────────────────────────────
alias cm='chezmoi'
alias cma='chezmoi add'
alias cmr='chezmoi re-add'                 # pull local edits back into the source
alias cmd='chezmoi diff'
alias cme='chezmoi edit --apply'
alias cmcd='cd $(chezmoi source-path)'

# ── Misc ────────────────────────────────────────────────────────────────────
alias path='echo $PATH | tr ":" "\n"'
alias reload='source ~/.zshrc'
alias ip='curl -s https://ifconfig.me && echo'
alias localip="ipconfig getifaddr en0"
alias serve='python3 -m http.server 8000 --bind 127.0.0.1'
alias jsonf='jq .'
alias now='date +"%Y-%m-%d %H:%M:%S"'
