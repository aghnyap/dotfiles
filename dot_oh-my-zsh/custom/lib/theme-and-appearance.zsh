# Override for oh-my-zsh's lib/theme-and-appearance.zsh.
#
# oh-my-zsh.sh:199-201 sources $ZSH_CUSTOM/lib/<name>.zsh INSTEAD OF
# $ZSH/lib/<name>.zsh when it exists, so this file replaces the upstream one
# wholesale. $ZSH/custom is in oh-my-zsh's .gitignore, so it survives
# `omz update`.
#
# WHY: the upstream file costs 14-22ms, and ~14ms of that is two capability
# probes that each fork a process --
#     command diff --color /dev/null{,}     (~7ms)
#     test-ls-args ls -G                    (~7ms)
# On this machine a bare fork+exec is 5-7ms because execs are intercepted, so
# probing is far more expensive than the thing being probed.
#
# Both probes have a known answer on macOS 26 / arm64, verified before writing
# this file:
#     command diff --color /dev/null /dev/null   -> supported
#     command ls -G /dev/null                    -> supported
# Everything else the upstream file does is reproduced verbatim below.
#
# If you ever run this config on a machine where those are NOT true, delete
# this file and oh-my-zsh goes back to probing.

# Sets color variable such as $fg, $bg, $color and $reset_color
autoload -U colors && colors

# Expand variables and commands in PROMPT variables
setopt prompt_subst

# Prompt function theming defaults. Starship draws the prompt here, but some
# plugins read these, so they are kept.
ZSH_THEME_GIT_PROMPT_PREFIX="git:("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
ZSH_THEME_GIT_PROMPT_DIRTY="*"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_RUBY_PROMPT_PREFIX="("
ZSH_THEME_RUBY_PROMPT_SUFFIX=")"

# Upstream probes for `diff --color` support. macOS 26's diff has it.
function diff {
  command diff --color "$@"
}

# Don't set ls coloring if disabled
[[ "$DISABLE_LS_COLORS" != true ]] || return 0

# Default coloring for BSD-based ls
export LSCOLORS="Gxfxcxdxbxegedabagacad"

# GNU-equivalent of the above. dircolors is not installed here, so upstream
# lands on this literal anyway -- reproduced exactly.
# NOTE: ~/.zshrc's `zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"`
# and fzf-tab's colouring both depend on this being set.
if [[ -z "$LS_COLORS" ]]; then
  export LS_COLORS="di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
fi

# Upstream probes with `test-ls-args ls -G`. BSD ls on macOS supports -G.
# (Cosmetic here: aliases.zsh later points `ls` at eza.)
alias ls='ls -G'
