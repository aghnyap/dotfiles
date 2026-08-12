# ── General ─────────────────────────────────────────────────────────────────

# mkcd <dir> -- create a directory (with parents) and enter it.
mkcd() { mkdir -p "$1" && cd "$1"; }

# extract <archive> -- one command for every archive format.
extract() {
  [[ -f $1 ]] || { print -u2 "extract: no such file: $1"; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1"   ;;
    *.tar.gz|*.tgz)   tar xzf "$1"   ;;
    *.tar.xz)         tar xJf "$1"   ;;
    *.tar)            tar xf "$1"    ;;
    *.bz2)            bunzip2 "$1"   ;;
    *.gz)             gunzip "$1"    ;;
    *.zip|*.jar|*.apk|*.aar|*.ipa) unzip -q "$1" ;;
    # rar and 7z need a tool macOS does not ship and this repo does not install
    # (unrar is not in homebrew/core -- licensing). Say which tool is missing,
    # rather than letting the shell report `command not found` for a name the
    # caller never typed.
    *.rar)            _extract_with unar "$1" ;;
    *.7z)             _extract_with 7zz  "$1" ;;
    *.Z)              uncompress "$1";;
    *) print -u2 "extract: unknown format: $1"; return 1 ;;
  esac
}

_extract_with() {
  local tool=$1 file=$2 formula
  case $tool in
    7zz) formula=sevenzip ;;
    *)   formula=$tool ;;
  esac
  if ! command -v "$tool" >/dev/null 2>&1; then
    print -u2 "extract: .${file:e} needs $tool -- brew install $formula (or: brewopt extras)"
    return 1
  fi
  "$tool" "$file"
}

# port <number> -- what is listening on this port?
port() {
  [[ -n $1 ]] || { print -u2 "usage: port <number>"; return 1; }
  lsof -nP -iTCP:"$1" -sTCP:LISTEN
}

# killport <number> -- free a stuck dev server / Metro / Gradle daemon.
killport() {
  [[ -n $1 ]] || { print -u2 "usage: killport <number>"; return 1; }
  local pids=(${(f)"$(lsof -t -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null)"})
  (( $#pids )) || { print "nothing listening on $1"; return 0; }
  print "killing: $pids"
  kill -9 $pids
}

# ips -- every interface with an address, plus the public one.
ips() {
  print -P "%F{cyan}local%f"
  ifconfig | awk '/^[a-z]/ {iface=$1} /inet /{printf "  %-10s %s\n", iface, $2}'
  print -P "%F{cyan}public%f"
  print "  $(curl -s --max-time 5 https://ifconfig.me || echo unavailable)"
}

# ── Search / navigation ─────────────────────────────────────────────────────

# f [query] -- fuzzy-find a file and open it in $EDITOR.
f() {
  local file
  file=$(fd --type f --hidden --exclude .git ${1:+--full-path "$1"} \
    | fzf --preview 'bat --color=always --style=numbers --line-range=:200 {}') || return
  [[ -n $file ]] && $EDITOR "$file"
}

# rgf <pattern> -- ripgrep with a live preview, opens the hit at its line.
rgf() {
  [[ -n $1 ]] || { print -u2 "usage: rgf <pattern>"; return 1; }
  local match file line
  match=$(rg --line-number --no-heading --color=always --smart-case "$1" \
    | fzf --ansi --delimiter=: \
          --preview 'bat --color=always --highlight-line {2} --style=numbers {1}' \
          --preview-window '+{2}-/2') || return
  file=${match%%:*}
  line=${${match#*:}%%:*}
  [[ -n $file ]] && $EDITOR "+$line" "$file"
}

# ── Git ─────────────────────────────────────────────────────────────────────
# NOTE: git-aliases.zsh (oh-my-zsh's ~200 aliases) is sourced BEFORE this file.
# zsh cannot define a function whose name is an existing alias -- it fails with
# "defining function based on alias" and a parse error that aborts the rest of
# the file. Before adding a g* function or alias here, check:
#     grep -qx '<name>' <(grep -oE '^\s*alias [a-zA-Z0-9_!-]+' ~/.config/zsh/git-aliases.zsh | awk '{print $2}')


# gbf -- fuzzy branch switcher, local and remote.
gbf() {
  local branch
  branch=$(git branch --all --sort=-committerdate --format='%(refname:short)' \
    | sed 's|^origin/||' | awk '!seen[$0]++' \
    | fzf --preview 'git log --oneline --graph --color=always -20 {}') || return
  [[ -n $branch ]] && git switch "$branch" 2>/dev/null || git switch -c "$branch" --track "origin/$branch"
}

# gfc -- fuzzy commit browser; prints the full diff of the chosen commit.
gfc() {
  local commit
  commit=$(git log --oneline --color=always -200 \
    | fzf --ansi --preview 'git show --color=always {1}') || return
  [[ -n $commit ]] && git show "${commit%% *}"
}

# ── tmux ────────────────────────────────────────────────────────────────────

# tm [name] -- attach to a session, or create one named after the current dir.
tm() {
  local name="${1:-${PWD:t}}"
  name=${name//[.:]/_}                       # tmux forbids . and : in names
  if [[ -n $TMUX ]]; then
    tmux switch-client -t "$name" 2>/dev/null || \
      { tmux new-session -d -s "$name" -c "$PWD" && tmux switch-client -t "$name"; }
  else
    tmux new-session -A -s "$name" -c "$PWD"
  fi
}

# ide [-l <layout>] [dir] -- open a project the way an IDE opens a folder.
#
# `tm` gets you a session with a shell in it, which is a blank screen. This
# builds the whole layout instead: an `editor` window running Neovim -- which
# opens the file tree on the left by itself, via the startup hook in
# ~/.config/nvim/lua/config/autocmds.lua -- plus the side windows for the kind
# of project it is. Existing sessions are reused, not rebuilt.
#
# layout.sh already did all of this, but only tmux's `prefix + P` ever called
# it, so it was unreachable from a fresh terminal. This is the way in.
#
#   ide                      -- this project, layout guessed from the tree
#   ide ~/Repositories/foo
#   ide -l sec .             -- force one (mobile|web|backend|sec|arch)
ide() {
  local layout='' dir
  [[ $1 == -l ]] && { layout="$2"; shift 2; }

  if (( $# )); then
    dir="$1"
  elif [[ -d .git ]] || git rev-parse --git-dir &>/dev/null; then
    dir="$PWD"
  else
    # Nothing to infer from, so ask. zoxide knows where you actually work.
    local -a choices
    if command -v zoxide >/dev/null; then
      choices=(${(f)"$(zoxide query -l)"})
    else
      choices=(~/Repositories/*(N/))
    fi
    dir=$(print -l $choices | fzf --prompt '  ' --border-label ' project ') || return 0
    [[ -n $dir ]] || return 0
  fi

  [[ -d $dir ]] || { print -u2 "ide: no such directory: $dir"; return 1; }
  # Anchor on the git root so `ide` from three levels down still opens the
  # project, not the subdirectory.
  dir=$(cd "$dir" && { git rev-parse --show-toplevel 2>/dev/null || pwd; })

  [[ -n $layout ]] || layout=$(_ide_layout "$dir")
  "$HOME/.config/tmux/layouts/layout.sh" "$layout" "$dir"
}

# _ide_layout <dir> -- guess the project type from what is lying in the tree.
# Order matters: a Flutter repo also has an android/ directory, and an Android
# app also has a settings.gradle, so the more specific test has to come first.
_ide_layout() {
  local d="$1"
  if [[ -f $d/melos.yaml || -f $d/pubspec.yaml || -d $d/.fvm ]]; then
    print mobile
  elif [[ -d $d/android || -f $d/build.gradle || -f $d/build.gradle.kts ]]; then
    [[ -d $d/android || -d $d/app/src/main ]] && print mobile || print backend
  elif [[ -f $d/package.json ]]; then
    print web
  elif [[ -f $d/workspace.dsl || -f $d/docs/architecture/workspace.dsl ]]; then
    # A dedicated C4 model repo -- checked last on purpose. `c4-init` works in
    # any repo, so an app repo can hold docs/architecture/workspace.dsl too;
    # only a repo with no app manifest at all is really an architecture repo.
    print arch
  else
    print backend
  fi
}

# mancha [section] <name> -- read a man page in chawan, where the cross-references
# are real links you can follow instead of names you have to retype.
#
# chawan serves the `man:` scheme itself, so this is only argument shuffling:
# `mancha ls` -> man:ls, and `mancha 5 cha-config` -> man:cha-config(5), matching
# how man itself takes an optional leading section.
mancha() {
  if (( $# == 0 )); then
    print -u2 'usage: mancha [section] <name>'
    return 1
  fi
  if (( $# >= 2 )) && [[ $1 == <-> ]]; then
    cha "man:$2($1)"
  else
    cha "man:$1"
  fi
}

# ── Homebrew ────────────────────────────────────────────────────────────────

# brewopt [group] -- install an optional package group.
#
# The Brewfile the bootstrap applies is the baseline, identical on every machine.
# Groups that are large and only pay off on some machines live in
# `.chezmoitemplates/Brewfile.optional` and are installed from here by hand, so
# nothing in the repo has to branch on what kind of machine it is running on.
#
# No argument lists the groups. `brew bundle` only ever installs, so this cannot
# remove anything.
brewopt() {
  local file="$(chezmoi source-path 2>/dev/null)/.chezmoitemplates/Brewfile.optional"
  [[ -r $file ]] || { print -u2 "brewopt: no optional Brewfile at $file"; return 1 }

  if (( $# == 0 )); then
    print -P "%F{blue}optional groups%f  --  brewopt <group>"
    # Each group is a `# ── name ──` banner; print its name plus the comment line
    # underneath, so the listing explains itself instead of needing a second doc.
    awk '/^# ── /{ n=$3; getline c; sub(/^# ?/, "", c); printf "  %-10s %s\n", n, c }' "$file"
    return 0
  fi

  # Slice one group out: everything from its banner to the next banner or EOF.
  local body
  body=$(awk -v want="$1" '
    /^# ── / { inside = ($3 == want); next }
    inside   { print }
  ' "$file")

  if [[ -z ${body//[[:space:]]/} ]]; then
    print -u2 "brewopt: no group '$1' -- run 'brewopt' for the list"
    return 1
  fi

  print -P "%F{blue}==>%f brew bundle: $1"
  print -r -- "$body" | brew bundle --file=/dev/stdin
}
