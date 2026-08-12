#!/usr/bin/env bash
# Create (or attach to) a tmux session pre-arranged for one kind of work.
#
#   layout.sh <mobile|web|backend|sec|arch> [directory]
#
# Panes are opened with the command typed but NOT executed, so nothing starts
# building or proxying until you press Enter in that pane. Commands that are
# purely informational do run.
set -euo pipefail

layout="${1:?usage: layout.sh <mobile|web|backend|sec> [dir]}"
dir="$(cd "${2:-$PWD}" && pwd)"
name="$(basename "$dir" | tr '.:' '__')-${layout}"

if tmux has-session -t "=${name}" 2>/dev/null; then
  exec tmux "$([[ -n ${TMUX:-} ]] && echo switch-client || echo attach-session)" -t "=${name}"
fi

# type <target> <text>  -- put a command on the prompt without running it
type() { tmux send-keys -t "$1" "$2"; }

tmux new-session -d -s "$name" -n editor -c "$dir"
tmux send-keys -t "${name}:editor" 'nvim' C-m

case "$layout" in
  mobile)
    # Flutter/Android: logs on the left, build tooling on the right.
    tmux new-window -t "$name" -n run -c "$dir"
    tmux split-window -t "${name}:run" -h -c "$dir"
    type "${name}:run.1" 'fvm flutter run --flavor '
    type "${name}:run.2" 'adb logcat -v color'
    tmux new-window -t "$name" -n gradle -c "$dir"
    tmux split-window -t "${name}:gradle" -v -c "$dir"
    type "${name}:gradle.1" './gradlew assembleDebug'
    tmux send-keys -t "${name}:gradle.2" 'adb devices -l' C-m
    ;;
  web)
    tmux new-window -t "$name" -n dev -c "$dir"
    tmux split-window -t "${name}:dev" -h -c "$dir"
    type "${name}:dev.1" 'npm run dev'
    type "${name}:dev.2" 'npm run test -- --watch'
    ;;
  backend)
    # Kotlin/JVM: gradle on top, a shell for http/db probing below.
    tmux new-window -t "$name" -n gradle -c "$dir"
    tmux split-window -t "${name}:gradle" -v -p 40 -c "$dir"
    type "${name}:gradle.1" './gradlew bootRun --debug-jvm'
    type "${name}:gradle.2" 'docker compose up -d'
    ;;
  sec)
    # Interception on the left, device/instrumentation on the right.
    tmux new-window -t "$name" -n proxy -c "$dir"
    tmux split-window -t "${name}:proxy" -h -c "$dir"
    type "${name}:proxy.1" 'mitmweb --listen-host 127.0.0.1 --listen-port 8080'
    type "${name}:proxy.2" 'frida-ps -U'
    tmux new-window -t "$name" -n scan -c "$dir"
    type "${name}:scan" 'semgrep --config p/security-audit .'
    ;;
  arch)
    # C4 modelling: the preview server runs, the export sits ready.
    # c4-local is typed and run rather than left on the prompt -- it is a server,
    # and the point of this layout is having it up while you edit the DSL.
    tmux new-window -t "$name" -n c4 -c "$dir"
    tmux split-window -t "${name}:c4" -v -p 30 -c "$dir"
    tmux send-keys -t "${name}:c4.1" 'c4-local' C-m
    type "${name}:c4.2" 'c4-export'
    ;;
  *)
    tmux kill-session -t "=${name}"
    echo "layout.sh: unknown layout '$layout' (mobile|web|backend|sec|arch)" >&2
    exit 1
    ;;
esac

tmux select-window -t "${name}:editor"
exec tmux "$([[ -n ${TMUX:-} ]] && echo switch-client || echo attach-session)" -t "=${name}"
