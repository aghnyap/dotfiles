-- ╭──────────────────────────────────────────────────────────────╮
-- │  murmur.nvim -- hotkey voice-to-buffer dictation               │
-- │                                                                │
-- │  Needs a whisper.cpp SERVER running locally, not just the CLI  │
-- │  the Brewfile installs -- `whisper-cpp` (the formula) ships    │
-- │  the `whisper-server` example binary too; start it by hand:    │
-- │      whisper-server --host 127.0.0.1 --port 8009 -m <model>    │
-- │  There is no managed brew-services unit for it here (unlike    │
-- │  ollama), because model choice/quantisation is a per-machine   │
-- │  decision this repo does not make for you.                     │
-- │                                                                │
-- │  Recording goes through sox (Brewfile), which the plugin       │
-- │  auto-detects alongside arecord/ffmpeg.                        │
-- │                                                                │
-- │  Config shape verified against the upstream README. The repo    │
-- │  the README's own install example names, mecattaf/murmur.nvim, │
-- │  no longer exists (checked: 404) -- jspkay/murmur.nvim is a     │
-- │  fork of it that does, and is what this actually installs.     │
-- ╰──────────────────────────────────────────────────────────────╯
return {
  {
    'jspkay/murmur.nvim',
    event = 'VeryLazy',
    opts = {
      server = {
        host = '127.0.0.1',
        port = 8009,
        model = 'whisper-small',
      },
      recording = {
        command = nil, -- auto-detect: sox is what the Brewfile actually installs
      },
    },
    keys = {
      -- <leader>a is claude/codecompanion's group; <leader>v for "voice"
      -- avoids colliding with either.
      { '<leader>vd', '<cmd>Murmur<cr>', mode = { 'n', 'v' }, desc = 'Murmur: dictate' },
      { '<leader>vh', '<cmd>MurmurHealth<cr>', desc = 'Murmur: health check' },
    },
  },
}
