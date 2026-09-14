# ── d2 -- architecture as code ──────────────────────────────────────────────
# Replaces the Structurizr/C4 toolchain in the v12.0-audited migration: one
# `d2` binary (already baseline, no JVM, no plantuml/graphviz detour) instead
# of structurizr + plantuml + graphviz. Model lives as `workspace.d2`,
# previewed live in a browser, rendered straight to SVG/PNG -- no Mermaid
# export step, because d2 writes real images directly.
#
# The trade Structurizr made that d2 does not: Structurizr's `views {}` block
# filtered ONE shared model into several views that could never drift from
# it or each other. d2's `layers { ... }` blocks are closer to several
# related-but-separate diagrams -- each layer restates what it needs rather
# than being auto-derived from a single model. Less automatic; also less
# magic. `d2-init` below still scaffolds C1/C2 as layers of one file, because
# `d2 workspace.d2 out.svg` renders every layer to its own file in one pass
# (verified: `layers.c1`/`layers.c2` become `out/c1.svg`/`out/c2.svg`
# automatically, no per-view flag needed) -- keep restating deliberately, per
# level, rather than trying to make d2 do what Structurizr did.

# Host port for `d2 --watch`. d2 defaults to a random free port; pinning one
# keeps the workflow the same as before. Override per shell: D2_PORT=9000 d2-local
: ${D2_PORT:=8081}

# _d2_require -- one check, one message, used by every command below.
_d2_require() {
  if ! command -v d2 >/dev/null 2>&1; then
    print -u2 "d2: not installed -- brew install d2"
    return 1
  fi
}

# _d2_workspace -- echo the directory holding workspace.d2, or fail loudly.
# Same search order c4.zsh used for workspace.dsl: $PWD, $PWD/docs/architecture,
# then the same two from the git root, so the commands work from anywhere.
_d2_workspace() {
  local d root
  for d in "$PWD" "$PWD/docs/architecture"; do
    [[ -f $d/workspace.d2 ]] && { print -r -- "${d:A}"; return 0 }
  done
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n $root ]]; then
    for d in "$root" "$root/docs/architecture"; do
      [[ -f $d/workspace.d2 ]] && { print -r -- "${d:A}"; return 0 }
    done
  fi
  print -u2 "d2: no workspace.d2 in . or docs/architecture -- run d2-init"
  return 1
}

# d2-init -- scaffold docs/architecture/workspace.d2.
#
# A complete two-layer model rather than a stub, so `d2-local` shows a real
# diagram on the first run: a C1-ish context layer and a C2-ish container
# layer. There is no C3/component layer here on purpose -- d2 has no
# equivalent of Structurizr's `!impliedRelationships`, so a third
# hand-restated layer is exactly the kind of drift this tool cannot prevent
# for you; add one only if you are going to keep it in sync by hand.
d2-init() {
  local dir=${1:-docs/architecture}
  if [[ -f $dir/workspace.d2 ]]; then
    print -u2 "d2-init: $dir/workspace.d2 already exists -- refusing to overwrite"
    return 1
  fi
  mkdir -p "$dir" || return 1

  cat > "$dir/workspace.d2" <<'D2'
# App -- C4-style model, as d2 layers. `d2-local` live-previews this;
# `d2-render` writes each layer to its own image (layers/c1.svg, c2.svg).

layers: {
  c1: {
    title: |md # Level 1 -- System context|

    customer: Customer {shape: person}
    app: App {tooltip: The product.}

    customer -> app: Uses
  }

  c2: {
    title: |md # Level 2 -- Containers|

    customer: Customer {shape: person}

    app: App {
      mobile: Flutter App {
        tooltip: iOS and Android client (Flutter / Dart)
      }
      api: Backend API {
        tooltip: Serves the mobile client (Java 17 / Spring Boot)
      }
      db: Database {
        shape: cylinder
        tooltip: PostgreSQL 16
      }

      mobile -> api: "Calls (HTTPS / JSON)"
      api -> db: "Queries (JDBC)"
    }

    customer -> app.mobile: Uses
  }
}
D2

  print -P "%F{blue}==>%f d2-init: ${dir}/workspace.d2"
  print -P "    next: %F{cyan}d2-local%f"
}

# d2-local -- live-preview the workspace at http://localhost:$D2_PORT.
# Edit workspace.d2 and the browser follows ($D2_IMG_CACHE off would matter
# only if you use remote icons and expect them to change mid-session).
d2-local() {
  local dir pid who
  _d2_require || return 1
  dir=$(_d2_workspace) || return 1

  pid=$(lsof -nP -iTCP:"$D2_PORT" -sTCP:LISTEN -t 2>/dev/null | head -1)
  if [[ -n $pid ]]; then
    # `command ps`, not `ps`: aliases.zsh points ps at procs, which does not
    # accept -o and would silently produce an empty name here.
    who=$(command ps -o comm= -p "$pid" 2>/dev/null)
    print -u2 "d2-local: port $D2_PORT is held by ${${who:t}:-unknown} (pid $pid)"
    print -u2 "          retry with: D2_PORT=$(( D2_PORT + 1 )) d2-local"
    return 1
  fi

  print -P "%F{blue}==>%f d2 --watch  %F{cyan}http://localhost:$D2_PORT%f  (${dir/#$HOME/~})"
  print -P "    edit workspace.d2 and the browser follows.  Ctrl-C to stop."
  PORT="$D2_PORT" d2 --watch "$dir/workspace.d2"
}

# Kept for muscle memory coming from the old c4-local name.
alias d2-lite=d2-local

# d2-render [svg|png|pdf] -- render every layer straight to an image, no
# Mermaid/PlantUML detour: d2 IS the renderer. A layered workspace.d2 fans
# out automatically -- `d2 workspace.d2 out.svg` with two layers writes
# `out/c1.svg` and `out/c2.svg`, not a single out.svg (verified).
#
# Trade-off worth knowing: unlike the old Mermaid export, none of this
# renders natively in a GitHub/GitLab markdown fence. Committing the image
# and linking it (`![c1](images/c1.svg)`) is the PR-review path now.
d2-render() {
  local fmt=${1:-svg} dir out
  case $fmt in
    svg|png|pdf) ;;
    *) print -u2 "usage: d2-render [svg|png|pdf]"; return 1 ;;
  esac

  _d2_require || return 1
  dir=$(_d2_workspace) || return 1

  out="$dir/images"
  mkdir -p "$out" || return 1

  d2 "$dir/workspace.d2" "$out/workspace.$fmt" || {
    print -u2 "d2-render: render failed -- try 'd2-validate' for the reason"
    return 1
  }

  print -P "%F{blue}==>%f d2-render: ${out/#$HOME/~}"
}

# d2-validate -- the only diagnostics that exist; there is no d2 LSP known to
# exist yet, same situation Structurizr was in.
d2-validate() {
  _d2_require || return 1
  local dir
  dir=$(_d2_workspace) || return 1
  d2 validate "$dir/workspace.d2" || return 1
  print -P "%F{blue}==>%f d2-validate: workspace is valid"
}

# d2-fmt -- canonicalise workspace.d2 in place (d2's own formatter).
d2-fmt() {
  _d2_require || return 1
  local dir
  dir=$(_d2_workspace) || return 1
  d2 fmt "$dir/workspace.d2"
}

alias d2l='d2-local'
alias d2r='d2-render'
alias d2v='d2-validate'
