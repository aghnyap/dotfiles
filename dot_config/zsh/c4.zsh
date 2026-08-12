# ── C4 / Structurizr ────────────────────────────────────────────────────────
# Architecture-as-code: the C4 model written as Structurizr DSL, previewed in a
# browser, exported to Mermaid for PR review.
#
# All of this is the one native `structurizr` binary -- no container, no daemon,
# no VM. The two tools most guides still name are both end-of-life: the
# `structurizr-cli` Homebrew formula is deprecated and disables on 2027-02-17,
# and the `structurizr/lite` image is filed under "End of life" upstream. The
# unified binary replaces both: `local` is the preview server, `export` is the
# CLI.

# Host port. 8080 is the upstream default and is where `mitmweb` runs in the
# tmux `sec` layout, so this differs on purpose. Override per shell:
#     C4_PORT=9000 c4-local
: ${C4_PORT:=8081}

# _c4_require -- one check, one message, used by every command below.
_c4_require() {
  if ! command -v structurizr >/dev/null 2>&1; then
    print -u2 "c4: structurizr is not installed -- brew install structurizr"
    print -u2 "    (not structurizr-cli: deprecated, disabled 2027-02-17)"
    return 1
  fi
}

# _c4_structurizr <subcommand> [args...] -- run structurizr on a JVM it accepts.
#
# This wrapper exists because of one character in Homebrew's launcher script:
#
#     export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk/...}"
#
# That is a fallback, not a pin -- it defers to any JAVA_HOME already set. And
# ~/.zshenv exports mise's temurin-17 for Gradle and jdtls, so every structurizr
# call inherited Java 17 and died with:
#
#     UnsupportedClassVersionError: ... class file version 65.0, this version of
#     the Java Runtime only recognizes class file versions up to 61.0
#
# 65.0 is Java 21; 61.0 is Java 17. The war needs 21+. Pointing JAVA_HOME at
# Homebrew's openjdk for this one command fixes it without touching the global
# value -- changing that would break Gradle and the Android toolchain, which need
# 17 exactly.
#
# The version is read from the JDK's `release` file rather than by running
# `java -version`, which would add a JVM start to every call just to find out
# whether the next JVM start will work.
_c4_structurizr() {
  local home major
  home=${HOMEBREW_PREFIX:-/opt/homebrew}/opt/openjdk/libexec/openjdk.jdk/Contents/Home

  if [[ ! -x $home/bin/java ]]; then
    print -u2 "c4: no Homebrew JDK at $home -- brew install openjdk"
    print -u2 "    structurizr needs Java 21+; mise's temurin-17 is too old for it."
    return 1
  fi

  major=${${(M)${(f)"$(<$home/release 2>/dev/null)"}:#JAVA_VERSION=*}#JAVA_VERSION=\"}
  major=${major%%[.\"]*}
  if [[ -n $major ]] && (( major < 21 )); then
    print -u2 "c4: structurizr needs Java 21+, found $major at $home"
    print -u2 "    brew upgrade openjdk"
    return 1
  fi

  JAVA_HOME="$home" structurizr "$@"
}

# _c4_workspace -- echo the directory holding workspace.dsl, or fail loudly.
#
# Checked in order: $PWD, $PWD/docs/architecture, then the same two from the git
# root so the commands work from anywhere in the repo. One resolver for every
# command, so they cannot disagree about which model is live.
_c4_workspace() {
  local d root
  for d in "$PWD" "$PWD/docs/architecture"; do
    [[ -f $d/workspace.dsl ]] && { print -r -- "${d:A}"; return 0 }
  done
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n $root ]]; then
    for d in "$root" "$root/docs/architecture"; do
      [[ -f $d/workspace.dsl ]] && { print -r -- "${d:A}"; return 0 }
    done
  fi
  print -u2 "c4: no workspace.dsl in . or docs/architecture -- run c4-init"
  return 1
}

# _c4_wrap_mermaid <dir> -- turn exported Mermaid into PR-renderable Markdown,
# echoing how many views were wrapped.
#
# GitHub and GitLab render Mermaid only inside a ```mermaid fence in a Markdown
# file; the exporter writes bare diagram definitions, one file per view. This
# wraps each one and removes the original.
#
# Globbed rather than matched on extension: the export docs never state what
# extension Mermaid output uses, and hardcoding a guess is how this breaks
# silently six months from now.
#
# Neovim calls this function too (plugins/structurizr.lua sources this file for
# it), so the fencing has exactly one implementation.
_c4_wrap_mermaid() {
  local out=$1 f base n=0
  [[ -d $out ]] || { print -r -- 0; return 0 }
  for f in "$out"/*(.N); do
    [[ ${f:e} == md ]] && continue
    base=${f:t:r}
    {
      print -r -- "# ${base}"
      print -r --
      print -r -- '```mermaid'
      cat -- "$f"
      # The exporter's output does not end in a newline, so the closing fence
      # lands on the same line as the last statement -- `  end```  -- and the
      # block stops being a block. GitHub renders that as literal text. Only add
      # a newline when one is missing: $(tail -c1) is empty exactly when the last
      # byte already is one, because command substitution strips it.
      [[ -n $(command tail -c1 -- "$f") ]] && print -r --
      print -r -- '```'
    } > "$out/${base}.md"
    rm -f -- "$f"
    (( n++ ))
  done
  print -r -- "$n"
}

# c4-init -- scaffold docs/architecture/.
#
# Writes two files. The template is a complete, valid four-container model
# rather than a stub, so `c4-local` shows real diagrams on the first run: C1
# context, C2 containers, and a C3 component view for each side of the
# frontend/backend boundary.
c4-init() {
  local dir=${1:-docs/architecture}
  if [[ -f $dir/workspace.dsl ]]; then
    print -u2 "c4-init: $dir/workspace.dsl already exists -- refusing to overwrite"
    return 1
  fi
  mkdir -p "$dir" || return 1

  # Auto-refresh is disabled upstream by default, which means editing the DSL
  # does nothing visible until you reload the tab by hand. Two seconds turns the
  # preview into an actual feedback loop. Read at startup only, so changing it
  # needs `local` restarted.
  cat > "$dir/structurizr.properties" <<'PROPS'
structurizr.autoRefreshInterval=2000
PROPS

  cat > "$dir/workspace.dsl" <<'DSL'
workspace "App" "C4 model for the app -- the single source of truth." {

    # Relationships between containers imply the ones between their systems, so
    # the C1 view does not have to restate them.
    !impliedRelationships true

    model {
        customer = person "Customer" "Uses the mobile app."

        app = softwareSystem "App" "The product." {

            mobile = container "Flutter App" "iOS and Android client." "Flutter / Dart" {
                ui         = component "UI"         "Widgets and screens. No business logic, no HTTP." "Flutter"
                bloc       = component "BLoC"       "State and use cases. Knows nothing about widgets or transport." "flutter_bloc"
                mobileRepo = component "Repository" "The only component that talks to the network." "Dart"
            }

            api = container "Backend API" "Serves the mobile client." "Java 17 / Spring Boot" {
                controller = component "REST Controller" "HTTP edge. Validates and maps DTOs. No business rules." "Spring MVC"
                service    = component "Domain Service"  "Business rules. Knows nothing about HTTP or JPA." "Java"
                apiRepo    = component "Repository"      "Persistence boundary." "Spring Data JPA"
            }

            db = container "Database" "Stores application state." "PostgreSQL 16" {
                tags "Database"
            }
        }

        customer -> ui "Uses"
        ui -> bloc "Dispatches events to"
        bloc -> mobileRepo "Requests data from"
        mobileRepo -> controller "Calls" "HTTPS / JSON"
        controller -> service "Delegates to"
        service -> apiRepo "Reads from and writes to"
        apiRepo -> db "Queries" "JDBC"
    }

    views {
        systemContext app "c1" "Level 1 -- system context" {
            include *
            autolayout lr
        }

        container app "c2" "Level 2 -- containers" {
            include *
            autolayout lr
        }

        component mobile "c3-mobile" "Level 3 -- Flutter components" {
            include *
            autolayout lr
        }

        component api "c3-api" "Level 3 -- Java components" {
            include *
            autolayout lr
        }

        styles {
            element "Person" {
                shape person
                background #08427b
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Database" {
                shape cylinder
            }
        }
    }
}
DSL

  print -P "%F{blue}==>%f c4-init: ${dir}/{workspace.dsl,structurizr.properties}"
  print -P "    next: %F{cyan}c4-local%f"
}

# c4-local -- serve the workspace at http://localhost:$C4_PORT.
#
# Successor to Structurizr Lite; upstream calls `local` "equivalent to the
# previous Structurizr Lite tooling". With structurizr.properties in place the
# browser refreshes itself when the DSL changes.
#
# Saving layout in the UI writes workspace.json next to workspace.dsl. That file
# is worth committing -- it is your diagram layout, and losing it means
# re-dragging every box.
c4-local() {
  local dir pid who
  _c4_require || return 1
  dir=$(_c4_workspace) || return 1

  # A bound port is the most common failure here, and the JVM's own error for it
  # does not name what is holding it.
  pid=$(lsof -nP -iTCP:"$C4_PORT" -sTCP:LISTEN -t 2>/dev/null | head -1)
  if [[ -n $pid ]]; then
    # `command ps`, not `ps`: aliases.zsh points ps at procs, which does not
    # accept -o and silently produced an empty name, so the message read
    # "port 8081 is held by  (pid 19353)". Same trap as grep -> rg.
    #
    # :t because macOS `ps -o comm=` prints the absolute executable path, and for
    # anything inside a framework that is 120 characters of Cellar path wrapping
    # over two lines.
    who=$(command ps -o comm= -p "$pid" 2>/dev/null)
    print -u2 "c4-local: port $C4_PORT is held by ${${who:t}:-unknown} (pid $pid)"
    print -u2 "          retry with: C4_PORT=$(( C4_PORT + 1 )) c4-local"
    return 1
  fi

  print -P "%F{blue}==>%f structurizr local  %F{cyan}http://localhost:$C4_PORT%f  (${dir/#$HOME/~})"
  print -P "    edit workspace.dsl and the browser follows.  Ctrl-C to stop."

  # SERVER_PORT, and only SERVER_PORT.
  #
  # The docs give the port as `-Dserver.port=` on the JVM, which would mean
  # JAVA_OPTS -- but Homebrew's launcher is literally
  #
  #     exec "${JAVA_HOME}/bin/java"  -jar "<war>" "$@"
  #
  # with nothing between `java` and `-jar` but the empty gap where a build-time
  # java_opts would have been interpolated. JAVA_OPTS is never read, so setting
  # it looks like it works and silently does nothing. Verified by starting the
  # server with SERVER_PORT=8099: it bound *:8099, which is Spring Boot's relaxed
  # environment binding doing the work instead.
  SERVER_PORT="$C4_PORT" _c4_structurizr local "$dir"
}

# Kept because every tutorial and most muscle memory still says "lite".
alias c4-lite=c4-local

# c4-export -- export every view to Mermaid, wrapped as PR-renderable Markdown.
c4-export() {
  local dir out n
  _c4_require || return 1
  dir=$(_c4_workspace) || return 1

  out="$dir/diagrams"
  mkdir -p "$out" || return 1

  _c4_structurizr export \
    -workspace "$dir/workspace.dsl" \
    -format mermaid \
    -output "$out" || {
    print -u2 "c4-export: export failed -- try 'c4-validate' for the reason"
    return 1
  }

  n=$(_c4_wrap_mermaid "$out")
  print -P "%F{blue}==>%f c4-export: ${n} view(s) -> ${out/#$HOME/~}"
}

# c4-render [svg|png] -- render every view to an image file, locally.
#
# Why this goes through PlantUML rather than anything more direct: the exporter
# has no Graphviz format. `-format dot` is in plenty of guides and in the old
# CLI's docs, and this binary answers "Unknown export format: dot" -- the real
# list is
#
#     plantuml[/structurizr|c4plantuml]|websequencediagrams|mermaid|json|theme|static|fqcn
#
# and its PNG/SVG support is not a format at all: it needs `-url` pointing at a
# rendered diagram page, driven by a headless browser. That is the 1.98 GB
# `-playwright` container variant, which is the whole thing this setup avoids.
#
# So: export PlantUML, then let PlantUML rasterise it. Graphviz is what PlantUML
# lays the boxes out with -- `plantuml -testdot` is the check, and it reports
# "Installation seems OK" when the pair is wired up.
#
# Unlike structurizr, plantuml runs fine on the ambient temurin-17, so it does
# not need the JVM wrapper.
#
# The exporter emits a `-key` file per view as well: that is the diagram legend,
# and it renders like any other view.
c4-render() {
  local fmt=${1:-svg} dir out n
  case $fmt in
    svg|png) ;;
    *) print -u2 "usage: c4-render [svg|png]"; return 1 ;;
  esac

  _c4_require || return 1
  dir=$(_c4_workspace) || return 1

  if ! command -v plantuml >/dev/null 2>&1; then
    print -u2 "c4-render: plantuml is not installed -- brew install plantuml"
    print -u2 "           (it pulls in graphviz, which does the layout)"
    return 1
  fi

  out="$dir/images"
  mkdir -p "$out" || return 1

  _c4_structurizr export \
    -workspace "$dir/workspace.dsl" \
    -format plantuml \
    -output "$out" || {
    print -u2 "c4-render: export failed -- try 'c4-validate' for the reason"
    return 1
  }

  # -nometadata keeps the source out of the image, so re-rendering an unchanged
  # view produces an identical file and does not show up as a diff.
  plantuml -t"$fmt" -nometadata "$out"/*.puml || return 1
  rm -f -- "$out"/*.puml

  n=$(print -rl -- "$out"/*.$fmt(.N) | wc -l | tr -d ' ')
  print -P "%F{blue}==>%f c4-render: ${n} ${fmt} -> ${out/#$HOME/~}"
}

# c4-validate / c4-inspect -- the only diagnostics that exist.
#
# There is no Structurizr language server: the nvim-lspconfig PR for one was
# rejected and mason has no package. So syntax errors surface here, not as you
# type.
_c4_cli() {
  local dir sub=$1
  shift
  _c4_require || return 1
  dir=$(_c4_workspace) || return 1
  _c4_structurizr "$sub" -workspace "$dir/workspace.dsl" "$@"
}

# A success line, because the JVM prints three warnings about Jackson mutating
# final fields on every run (Java 26 tightened that, and the war's dependencies
# have not caught up). Without this, a valid workspace and a broken one both look
# like a wall of WARNING and nothing else. The warnings cannot be silenced from
# here -- the flag they suggest goes in JAVA_OPTS, which the launcher ignores.
c4-validate() {
  _c4_cli validate || return 1
  print -P "%F{blue}==>%f c4-validate: workspace is valid"
}

c4-inspect() { _c4_cli inspect }

alias c4l='c4-local'
alias c4e='c4-export'
alias c4v='c4-validate'
alias c4r='c4-render'
