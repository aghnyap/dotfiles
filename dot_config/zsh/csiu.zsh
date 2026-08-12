# ── Swallow the Cmd chords at a shell prompt ─────────────────────────────────
#
# ~/.config/ghostty/config re-encodes about thirty Cmd chords as CSI-u escape
# sequences (`\e[<codepoint>;<mods>u`) so that Neovim can see keys macOS
# terminals would otherwise eat. That works because Neovim parses CSI-u.
#
# A bare shell prompt does not. ZLE has no CSI-u parser, so an unrecognised
# sequence falls through to self-insert and the escape bytes are simply printed
# onto the command line -- press Cmd+A at a prompt and you get `[97;6u` as
# literal text. It looks like a corrupted keymap; it is just an editor keystroke
# arriving somewhere that cannot read it.
#
# So bind the whole family to a widget that does nothing. Cmd chords then stay
# silent at a prompt and keep working inside Neovim.
#
# The range is deliberate rather than a transcription of the Ghostty file. Any
# `;6u` (ctrl+shift) or `;8u` (ctrl+shift+alt) sequence over printable ASCII is
# one of these forwards -- nothing else in this setup emits them, and a real
# Ctrl+Shift+key does not produce CSI-u unless a keybind says so. Enumerating
# the range means adding a chord in Ghostty needs no matching edit here.
_csiu_ignore() { }
zle -N _csiu_ignore

() {
  local cp
  # 32..126: space through ~, the printable ASCII any chord can ride on.
  for (( cp = 32; cp <= 126; cp++ )); do
    bindkey -- "\e[${cp};6u" _csiu_ignore   # Cmd+X       -> ctrl+shift
    bindkey -- "\e[${cp};8u" _csiu_ignore   # Cmd+Shift+X -> ctrl+shift+alt
  done
}

# Cmd+Alt+Up / Cmd+Alt+Down ride the arrow encoding, not CSI-u, so they are
# named individually. These are the multicursor stacking chords.
bindkey -- '\e[1;7A' _csiu_ignore
bindkey -- '\e[1;7B' _csiu_ignore
