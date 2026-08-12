#!/usr/bin/env bash
# Download the JetBrains Kotlin LSP into Neovim's data dir.
#
# Mason does not package this yet. JetBrains distributes it as a VS Code
# extension (.vsix) on their CDN -- a .vsix is just a zip, and the server
# launcher lives inside it. There is no standalone archive: the release on
# GitHub carries zero assets and only links to these CDN files, so the URL is
# derived from the release notes rather than guessed.
#
# Pinned rather than tracking latest, because this server is pre-1.0 and its
# behaviour on a Flutter-embedded Gradle build is exactly what broke fwcd's
# server. Bump deliberately:
#   KOTLIN_LSP_VERSION=<build> KOTLIN_LSP_EXT=<extver> bash install-kotlin-lsp.sh
# Current versions come from https://github.com/Kotlin/kotlin-lsp/releases
set -euo pipefail

KOTLIN_LSP_VERSION="${KOTLIN_LSP_VERSION:-262.9593.0}"
KOTLIN_LSP_EXT="${KOTLIN_LSP_EXT:-0.0.6}"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) PLATFORM="mac-aarch64" ;;
  Darwin-x86_64) PLATFORM="mac-amd64" ;;
  Linux-aarch64) PLATFORM="linux-aarch64" ;;
  Linux-x86_64) PLATFORM="linux-amd64" ;;
  *) echo "unsupported platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

DEST="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/kotlin-lsp"
URL="https://download-cdn.jetbrains.com/language-server/kotlin-server/${KOTLIN_LSP_VERSION}/kotlin-server-${KOTLIN_LSP_EXT}-${PLATFORM}.vsix"

command -v java >/dev/null 2>&1 || {
  echo "java is required (JAVA_HOME=${JAVA_HOME:-unset})" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "downloading kotlin-lsp ${KOTLIN_LSP_VERSION} (${PLATFORM})…"
if ! curl -fsSL --max-time 600 -o "$tmp/kotlin-lsp.vsix" "$URL"; then
  cat >&2 <<EOF
Download failed: $URL

JetBrains changes both the build number and the extension version between
releases. Check the release notes for the current pair:
  https://github.com/Kotlin/kotlin-lsp/releases/latest
then re-run with both set, e.g.:
  KOTLIN_LSP_VERSION=262.9593.0 KOTLIN_LSP_EXT=0.0.6 bash "$0"
EOF
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
unzip -q "$tmp/kotlin-lsp.vsix" -d "$DEST"

# Prefer bin/intellij-server. The older kotlin-lsp.sh still ships but prints
#   "kotlin-lsp.sh is deprecated and will be removed in a future release"
# on every start, which Neovim surfaces as LSP stderr noise.
launcher="$(find "$DEST" -type f -name 'intellij-server' -perm -u+x 2>/dev/null | head -1)"
if [[ -z $launcher ]]; then
  launcher="$(find "$DEST" -name 'kotlin-lsp.sh' -type f 2>/dev/null | head -1)"
fi
if [[ -z $launcher ]]; then
  echo "unpacked to $DEST but found no launcher. Contents:" >&2
  find "$DEST" -maxdepth 4 -type d | head -20 >&2
  exit 1
fi

chmod +x "$launcher"
# Stable path for the Neovim spec, independent of the vsix's internal layout.
ln -sf "$launcher" "$DEST/kotlin-lsp"

echo "installed: $DEST/kotlin-lsp -> $launcher"
"$launcher" --version 2>&1 | head -2
