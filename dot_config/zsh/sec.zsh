# ╭──────────────────────────────────────────────────────────────────────────╮
# │  Security research helpers                                               │
# │                                                                          │
# │  For applications you are authorized to test. Everything here operates   │
# │  on a local file, a local emulator, or a device you have attached --     │
# │  nothing scans a remote host by default.                                 │
# ╰──────────────────────────────────────────────────────────────────────────╯

# ── Static analysis / secrets ───────────────────────────────────────────────
alias sg='semgrep --config p/security-audit'
alias sgci='semgrep ci'
alias leaks='gitleaks detect --no-banner --redact --verbose'
alias leakslog='gitleaks detect --no-banner --redact --log-opts="--all"'
alias vuln='trivy fs --scanners vuln,secret,misconfig .'
alias osv='osv-scanner scan source -r .'
alias sbom='syft . -o cyclonedx-json'

# scan [dir] -- the full static pass over a repo, in one command.
scan() {
  local dir="${1:-.}"
  print -P "%F{blue}▸ semgrep%f"   ; semgrep --config p/security-audit --quiet "$dir" || true
  print -P "%F{blue}▸ gitleaks%f"  ; gitleaks detect --no-banner --redact -s "$dir" || true
  print -P "%F{blue}▸ trivy%f"     ; trivy fs --scanners vuln,secret --quiet "$dir" || true
}

# ── Android APK analysis ────────────────────────────────────────────────────

# apkscan <app.apk> -- decompile, then run the static passes over the sources.
# Output goes to a sibling directory, never into the current repo.
apkscan() {
  local apk="${1:?usage: apkscan <file.apk>}"
  [[ -f $apk ]] || { print -u2 "apkscan: no such file: $apk"; return 1; }

  local base out
  base="${apk:t:r}"
  out="${TMPDIR:-/tmp}/apkscan-${base}-$(date +%s)"
  mkdir -p "$out"

  print -P "%F{blue}▸ jadx%f  -> $out/src"
  jadx --no-debug-info --output-dir "$out/src" "$apk" >/dev/null 2>&1 || \
    print -u2 "  jadx reported errors (partial output is usual)"

  print -P "%F{blue}▸ apktool%f (manifest + resources) -> $out/res"
  apktool d -f -o "$out/res" "$apk" >/dev/null 2>&1 || true

  if [[ -f $out/res/AndroidManifest.xml ]]; then
    print -P "%F{blue}▸ manifest flags%f"
    rg -o 'android:(debuggable|allowBackup|usesCleartextTraffic)="[^"]*"' \
      "$out/res/AndroidManifest.xml" || print "  none of the risky flags set"
    print -P "%F{blue}▸ exported components%f"
    rg -c 'android:exported="true"' "$out/res/AndroidManifest.xml" 2>/dev/null || print "  0"
  fi

  print -P "%F{blue}▸ gitleaks over decompiled sources%f"
  gitleaks detect --no-banner --redact --no-git -s "$out/src" 2>&1 | tail -30 || true

  print -P "%F{blue}▸ semgrep (mobile rules)%f"
  semgrep --config p/mobile-security --quiet "$out/src" 2>&1 | tail -40 || true

  print -P "%F{green}▸ done%f  $out"
}

# ── Emulator / device proxying ──────────────────────────────────────────────
# Point the attached device at the local mitmproxy, and back again.
# Requires the mitmproxy CA installed on the device for HTTPS.
proxyon() {
  local host="${1:-$(ipconfig getifaddr en0)}" port="${2:-8080}"
  adb shell settings put global http_proxy "${host}:${port}" || return 1
  print -P "%F{green}proxy on%f  ${host}:${port}   (start it with: mitmweb)"
}
proxyoff() {
  adb shell settings put global http_proxy :0
  adb shell settings delete global http_proxy 2>/dev/null
  print -P "%F{yellow}proxy off%f"
}
alias mitm='mitmweb --listen-host 127.0.0.1 --listen-port 8080'
# Install the mitmproxy CA into an emulator's system store (emulator only --
# a physical device needs a rooted /system or a user-store workaround).
mitmca() {
  local cert="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
  [[ -f $cert ]] || { print -u2 "mitmca: run mitmproxy once first to generate $cert"; return 1; }
  local hash
  hash=$(openssl x509 -inform PEM -subject_hash_old -in "$cert" | head -1)
  adb root && adb remount || { print -u2 "mitmca: emulator must be rooted/writable"; return 1; }
  adb push "$cert" "/system/etc/security/cacerts/${hash}.0"
  adb shell chmod 644 "/system/etc/security/cacerts/${hash}.0"
  print -P "%F{green}CA installed%f as ${hash}.0 — reboot the emulator"
}

# ── Frida ───────────────────────────────────────────────────────────────────
alias fps='frida-ps -U'
alias fpsa='frida-ps -Uai'   # installed apps only

# fridago <package> -- spawn an app under Frida, optionally with a script.
fridago() {
  local pkg="${1:?usage: fridago <package> [script.js]}"
  if [[ -n ${2:-} ]]; then
    frida -U -f "$pkg" -l "$2"
  else
    frida -U -f "$pkg"
  fi
}

# fridaserver -- push and start frida-server matching the installed frida.
fridaserver() {
  local ver arch
  ver=$(frida --version 2>/dev/null) || { print -u2 "frida not installed"; return 1; }
  arch=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
  case "$arch" in
    arm64*) arch=arm64 ;; armeabi*) arch=arm ;; x86_64) arch=x86_64 ;; x86) arch=x86 ;;
  esac
  local name="frida-server-${ver}-android-${arch}"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/frida"
  mkdir -p "$cache"
  if [[ ! -f $cache/$name ]]; then
    print "downloading $name…"
    curl -fsSL "https://github.com/frida/frida/releases/download/${ver}/${name}.xz" \
      | xz -d > "$cache/$name" || { print -u2 "download failed"; return 1; }
  fi
  adb push "$cache/$name" /data/local/tmp/frida-server
  adb shell chmod 755 /data/local/tmp/frida-server
  adb shell "su -c '/data/local/tmp/frida-server &'" 2>/dev/null \
    || adb shell "/data/local/tmp/frida-server &"
  print -P "%F{green}frida-server started%f ($name)"
}

# ── Network / web ───────────────────────────────────────────────────────────
# Scoped to explicit targets only; no shorthand that scans a whole range.
alias nmapq='nmap -sV -sC -T4'
alias nucl='nuclei -silent'
alias jwtd='jwt decode'
