# ╭──────────────────────────────────────────────────────────────────────────╮
# │  Per-domain development helpers                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

# ── Flutter / Dart ──────────────────────────────────────────────────────────
# Always via `fvm`. Flutter is pinned per-repository by the clone's .fvm/, so
# there is deliberately no global flutter/dart on PATH -- a global SDK would
# shadow the per-repo pin and silently build against the wrong version.
alias fl='fvm flutter'
alias fld='fvm dart'
alias flr='fvm flutter run'
alias flc='fvm flutter clean'
alias flpg='fvm flutter pub get'
alias flpu='fvm flutter pub upgrade'
alias flt='fvm flutter test'
alias fla='fvm flutter analyze'
alias fldr='fvm flutter doctor -v'
alias fldev='fvm flutter devices'
# build_runner is the single most-repeated command in a codegen-heavy project.
alias flgen='fvm dart run build_runner build --delete-conflicting-outputs'
alias flgenw='fvm dart run build_runner watch --delete-conflicting-outputs'
alias flver='fvm list'

# melos (monorepo orchestration)
alias ml='fvm dart run melos'
alias mlb='fvm dart run melos bootstrap'
alias mlc='fvm dart run melos clean'

# ── Android ─────────────────────────────────────────────────────────────────
alias gw='./gradlew'
alias gwc='./gradlew clean'
alias gwb='./gradlew build'
alias gwad='./gradlew assembleDebug'
alias gwstop='./gradlew --stop'                 # kill wedged daemons
alias adbr='adb kill-server && adb start-server'
alias apkinstall='adb install -r'
alias screenrec='scrcpy --stay-awake --turn-screen-off'
alias mirror='scrcpy'

# adbd -- pick a device when several are attached, export ANDROID_SERIAL.
adbd() {
  local dev
  dev=$(adb devices -l | awk 'NR>1 && NF {print $0}' | fzf --header='select device') || return
  [[ -n $dev ]] || return
  export ANDROID_SERIAL=${dev%% *}
  print -P "%F{green}ANDROID_SERIAL%f = $ANDROID_SERIAL"
}

# logcat [package] -- colorized logcat, scoped to one app's pid when given.
logcat() {
  if [[ -n $1 ]]; then
    local pid
    pid=$(adb shell pidof -s "$1" 2>/dev/null | tr -d '\r')
    if [[ -z $pid ]]; then
      print -u2 "logcat: '$1' is not running on the device"
      return 1
    fi
    print -P "%F{cyan}$1%f -> pid $pid"
    adb logcat --pid="$pid" -v color
  else
    adb logcat -v color
  fi
}

# apk-info <apk> -- package name, version, min/target SDK, permissions.
apk-info() {
  [[ -f $1 ]] || { print -u2 "usage: apk-info <file.apk>"; return 1; }
  local aapt
  aapt=$(find "$ANDROID_HOME/build-tools" -name aapt2 -type f 2>/dev/null | sort -V | tail -1)
  [[ -n $aapt ]] || { print -u2 "apk-info: no aapt2 found in \$ANDROID_HOME/build-tools"; return 1; }
  "$aapt" dump badging "$1" | rg '^(package|sdkVersion|targetSdkVersion|application-label|uses-permission)'
}

# ── iOS / macOS ─────────────────────────────────────────────────────────────
alias pods='pod install --repo-update'
alias podsclean='rm -rf Pods Podfile.lock && pod install --repo-update'
alias xcclean='rm -rf ~/Library/Developer/Xcode/DerivedData/*'
alias simlist='xcrun simctl list devices available'
alias simshutdown='xcrun simctl shutdown all'

# simboot -- fuzzy-pick a simulator, boot it, open Simulator.app.
simboot() {
  local sim udid
  sim=$(xcrun simctl list devices available \
    | rg '^\s+\w.*\([0-9A-F-]{36}\)' \
    | fzf --header='select simulator') || return
  [[ -n $sim ]] || return
  udid=$(print "$sim" | sd '.*\(([0-9A-F-]{36})\).*' '$1')
  xcrun simctl boot "$udid" 2>/dev/null
  open -a Simulator
}

# ── Web / React / React Native ──────────────────────────────────────────────
alias ni='npm install'
alias nr='npm run'
alias nrd='npm run dev'
alias nrb='npm run build'
alias nrt='npm run test'
alias nx='npx'
alias metro='npx react-native start'
alias rnios='npx react-native run-ios'
alias rnandroid='npx react-native run-android'
# Metro's cache is the usual suspect for "works on my machine" RN failures.
alias rnreset='watchman watch-del-all 2>/dev/null; rm -rf $TMPDIR/metro-* $TMPDIR/haste-map-*; npx react-native start --reset-cache'

# ── Kotlin / JVM ────────────────────────────────────────────────────────────
alias gwr='./gradlew bootRun'
alias gwtest='./gradlew test'   # not `gwt`: that is oh-my-zsh's git worktree
alias gwdebug='./gradlew bootRun --debug-jvm'    # waits on :5005 for the DAP attach
alias gwtasks='./gradlew tasks --all'

# jdk [version] -- switch the active JDK via mise; no argument lists them.
jdk() {
  if [[ -z $1 ]]; then
    mise ls java
    return
  fi
  mise use -g "java@$1" && print -P "%F{green}JAVA_HOME%f = $(mise where java)"
}

# ── Docker / k8s ────────────────────────────────────────────────────────────
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias k='kubectl'
