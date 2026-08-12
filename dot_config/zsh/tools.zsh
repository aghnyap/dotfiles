# ╭──────────────────────────────────────────────────────────────────────────╮
# │  Tool shell-integration hooks                                            │
# │                                                                          │
# │  Each of these tools generates a chunk of zsh via `<tool> init zsh`.     │
# │  Running them at every prompt costs a fork each -- measured at 7-20ms    │
# │  per tool, ~75ms total. The generated output only changes when the       │
# │  binary does, so it is cached and re-sourced instead, and regenerated    │
# │  automatically when the binary's mtime moves (i.e. after a brew upgrade).│
# ╰──────────────────────────────────────────────────────────────────────────╯

_zsh_init_cache="$HOME/.cache/zsh/init"

# _cached_init <cache-name> <binary> <command...>
_cached_init() {
  local name=$1 bin=$2; shift 2
  (( $+commands[$bin] )) || return 0
  local cache="$_zsh_init_cache/$name.zsh"
  if [[ ! -s $cache || ${commands[$bin]} -nt $cache ]]; then
    [[ -d $_zsh_init_cache ]] || mkdir -p "$_zsh_init_cache"
    "$@" > "$cache" 2>/dev/null
  fi
  source "$cache"
}

# mise -- runtime version manager (node, java, python, go...).
# Flutter is NOT managed here; FVM owns it per-repository.
#
# `mise activate` is deliberately NOT run. It costs ~53ms because its generated
# script forks `mise hook-env` at source time, and it is not needed for version
# switching: ~/.zshenv:55 already puts mise's shims directory on PATH, and the
# shims resolve the correct pinned version per directory on their own. Verified
# in a clean environment -- `node -v` returns v22.23.2 through the shim with no
# activation.
#
# What activation would add: re-evaluating the environment on every `cd`, which
# only matters for `[env]` blocks in a mise.toml (setting variables, not tool
# versions). If you start using those, put this line back:
#     _cached_init mise mise mise activate zsh
# and expect ~53ms of it.

# zoxide -- frecency-ranked cd. `--cmd cd` replaces cd entirely; the real one
# stays reachable as `builtin cd`. `cdi` opens the interactive picker.
_cached_init zoxide zoxide zoxide init zsh --cmd cd

# direnv -- per-project env from .envrc. Loads after mise so a project .envrc
# can still override a mise-provided variable. Deliberately NOT deferred: the
# hook must run before the first prompt or the starting directory's .envrc is
# skipped.
_cached_init direnv direnv direnv hook zsh

# fzf -- Ctrl-T (files), Ctrl-R (history), Alt-C (cd). Options in fzf.zsh.
_cached_init fzf fzf fzf --zsh

# starship -- prompt. The generated init ends with
#   PROMPT2="$(starship prompt --continuation)"
# which forks a second time on every single shell. The continuation prompt is
# static, so it is stripped from the cache and baked in as a literal.
if (( $+commands[starship] )); then
  _starship_cache="$_zsh_init_cache/starship.zsh"
  if [[ ! -s $_starship_cache || ${commands[starship]} -nt $_starship_cache ]]; then
    [[ -d $_zsh_init_cache ]] || mkdir -p "$_zsh_init_cache"
    starship init zsh | grep -v '^PROMPT2=' > "$_starship_cache"
    printf 'PROMPT2=%s\n' "${(q)$(starship prompt --continuation)}" >> "$_starship_cache"
  fi
  source "$_starship_cache"
  unset _starship_cache
fi

# atuin -- SQLite-backed shell history with search (~25ms), lazy-loaded.
#
# Nothing needs atuin until you press Ctrl-R: Up-arrow is bound to zsh's own
# prefix search (atuin is initialised with --disable-up-arrow), and atuin's
# history *recording* happens in its own daemon, not in the shell hook, so
# deferring does not lose commands.
#
# Ctrl-R is bound to a stub widget that loads atuin on first press, then
# re-sends Ctrl-R so the real widget handles the keystroke. From the second
# press on, this code is gone.
#
# This is a deliberately different mechanism from zsh-defer, which was tried
# earlier in this config and reverted because its queue did not drain: the load
# here is triggered by an actual keypress, so if it fails you find out
# immediately rather than silently losing a feature.
if (( $+commands[atuin] )); then
  _atuin_lazy() {
    bindkey -r '^R'
    unfunction _atuin_lazy
    zle -D _atuin_lazy 2>/dev/null
    _cached_init atuin atuin atuin init zsh --disable-up-arrow
    zle -U $'\C-r'          # replay the keystroke into atuin's now-bound widget
  }
  zle -N _atuin_lazy
  bindkey '^R' _atuin_lazy
fi

# Completions for gh, mise, atuin, starship, zoxide, delta, eza and chezmoi are
# already installed by Homebrew into $HOMEBREW_PREFIX/share/zsh/site-functions,
# which is on fpath. Calling `gh completion -s zsh` here would cost another
# 36ms to regenerate what is already on disk.

# ── Lazy-loaded version managers ────────────────────────────────────────────
# No rbenv wrapper. There used to be one here, lazy-loading `rbenv init` because
# the eval cost ~119ms -- by far the most expensive thing in shell startup. mise
# owns ruby now (pinned in ~/.config/mise/config.toml), its shims are already on
# PATH from ~/.zshenv, and it needs no init eval at all, so the whole wrapper and
# the problem it solved are gone.

# No SDKMAN. It was the second version manager here, lazy-loaded behind an `sdk()`
# wrapper to dodge a ~24ms init, and its only remaining job was one JetBrains
# Runtime 17 candidate. mise owns java now.
#
# The reason it survived a first attempt at removal, recorded because it is not
# something the command line would ever reveal: Android Studio had
# ~/.sdkman/candidates/java/17.0.12-jbr registered as the JDK named "17" in
# jdk.table.xml, across 9 version dirs, plus 143 JDK source roots each. Deleting
# the directory would have broken in-IDE Gradle builds the moment that JDK was
# selected, with no symptom in any terminal. Those entries were repointed at
# mise's temurin-17 first (1287 paths), then the directory went.

# No greeting. fastfetch ran here, gated to real top-level terminals, and cost
# ~65ms on every new window -- the single largest cost in opening one, and one no
# `zsh -lic` benchmark ever showed because the `-t 1` guard makes it skip when
# stdout is a pipe.
