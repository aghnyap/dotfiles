# Cursor-like Neovim — keybindings

Built on **LazyVim**. Everything LazyVim binds by default still applies; this
document covers the additions and overrides. `<leader>` is Space — press it and
wait to see which-key list the rest.

Cmd chords are forwarded by `~/.config/ghostty/config` as CSI-u escape
sequences and decoded by Neovim as `<D-...>`. They only work inside Ghostty.

**Most Cmd chords have no `<leader>` twin.** Only the Claude group and the symbol
outline are bound both ways; `Cmd+P`, `Cmd+F`, `Cmd+B`, `Cmd+S`, `Cmd+Z`, `Cmd+A`,
`Cmd+/`, `Cmd+D`, `Cmd+\` and the tab-navigation pair are Ghostty-only. Over SSH
or in another terminal, reach for the plain vim equivalent instead.

Leader groups added on top of LazyVim's: `F` Flutter, `X` Xcode, `r` run,
`h` HTTP, `a` AI (Claude), `A` agents (aider, cursor-agent), `C` c4/Structurizr,
`m` overview/outline, `D` database. Everything else under `<leader>` is
LazyVim's own.

## Files & navigation

| Keys | Action |
| --- | --- |
| `Cmd+P` | Quick open (files, recent, buffers) |
| `Cmd+Shift+P` | Command palette |
| `Cmd+Shift+F` | Search across project |
| `Cmd+F` | Find in current file |
| `Cmd+Shift+O` | Go to symbol in file |
| `Cmd+B` | Toggle explorer sidebar |
| `Cmd+Shift+E` | Focus explorer |
| `Cmd+Shift+]` / `Cmd+Shift+[` | Next / previous editor tab |
| `Tab` / `Shift+Tab` (normal mode) | Next / previous editor tab |
| `Cmd+S` | Save (also formats) |
| `Cmd+\` | Split editor right |
| `Cmd+,` | Open config files |

## Editing

| Keys | Action |
| --- | --- |
| `Cmd+Z` / `Cmd+Shift+Z` | Undo / redo |
| `Cmd+A` | Select all |
| `Cmd+/` | Toggle comment |
| `Cmd+D` | Add cursor at next occurrence |
| `Cmd+Shift+D` | Select all occurrences |
| `Cmd+Alt+Up` / `Cmd+Alt+Down` | Add cursor above / below |
| `Esc` or `Ctrl+C` | Collapse back to one cursor |
| `Alt+Up` / `Alt+Down` | Move line up / down |
| `Alt+Shift+Up` / `Alt+Shift+Down` | Duplicate line, or the selection in visual mode |
| `<leader>ms` | Skip the next match when adding cursors |
| `Cmd+Shift+K` | Delete line |
| `Shift+Alt+F` | Format document |
| `Tab` / `Shift+Tab` (visual) | Indent / outdent |

## Code intelligence

| Keys | Action |
| --- | --- |
| `F12` / `gd` | Go to definition |
| `Shift+F12` / `gr` | Find all references |
| `gI` / `gy` | Go to implementation / type definition |
| `F2` / `<leader>cr` | Rename symbol |
| `Cmd+.` / `<leader>ca` | Quick fix (code action) |
| `K` | Hover docs |
| `[d` / `]d` | Previous / next diagnostic |
| `Cmd+Shift+M` | Problems panel |
| `<leader>ch` | Toggle inlay hints |

## Panels

| Keys | Action |
| --- | --- |
| ``Cmd+` `` or `Cmd+J` | Toggle bottom terminal |
| `Cmd+Shift+G` | Git UI (lazygit) |
| `<leader>mm` | Toggle the overview scrollbar |
| `<leader>mr` | Redraw the overview scrollbar |
| `Cmd+Shift+U` or `<leader>mo` | Toggle the symbol outline (aerial) |
| `<leader>mf` | Toggle the outline and jump into it |
| `[c` | Jump up to the enclosing scope (sticky scroll) |
| `Esc Esc` (in terminal) | Leave terminal mode |
| `Ctrl+h/j/k/l` | Move between panes — **and across the tmux boundary** |

`Ctrl+h/j/k/l` is handled by vim-tmux-navigator: the same chord moves between
Neovim splits and tmux panes with no prefix and no mode change. It needs the
matching plugin in `~/.config/tmux/tmux.conf`, which is installed.

## Debug (nvim-dap)

Breakpoints work in Dart, Kotlin/Java, JS/TS, React Native, Go and Swift.

| Keys | Action |
| --- | --- |
| `F5` | Continue / start debugging |
| `F9` | Toggle breakpoint |
| `F10` / `F11` / `Shift+F11` | Step over / into / out |
| `<leader>dA` | Attach to a JVM on `:5005` directly |
| `<leader>d…` | LazyVim's full debug group (UI, REPL, conditional breakpoints) |

For the **Kotlin backend**, start the service with `./gradlew bootRun --debug-jvm`
(aliased to `gwdebug`); it waits on `:5005`. Then `F5` and pick
*Attach to JVM on :5005*.

For **React**, launch Chrome with `--remote-debugging-port=9222` and pick
*Attach to Chrome*. For **React Native**, Metro exposes Hermes on `:8081`.

## Swift / iOS

| Keys | Action |
| --- | --- |
| `<leader>Xb` / `<leader>Xr` | Build / build and run |
| `<leader>Xt` / `<leader>XT` | Run tests / this test class |
| `<leader>Xd` / `<leader>Xs` | Select device / scheme |
| `<leader>Xl` | Toggle build logs |
| `<leader>Xc` | Toggle code coverage |
| `<leader>XX` | Xcode action picker |

`sourcekit-lsp` comes from Xcode itself, located via `xcrun --find` — there is
nothing to install. `:XcodebuildSetup` once per project generates
`buildServer.json`, which is what makes the LSP understand the build graph.

## React Native

| Keys | Action |
| --- | --- |
| `<leader>rnm` | Metro bundler |
| `<leader>rni` / `<leader>rna` | `run-ios` / `run-android` |
| `<leader>rnp` | `pod install --repo-update` |
| `<leader>rnc` | Nuke the Metro/haste caches and restart |

## Flutter

| Keys | Action |
| --- | --- |
| `<leader>Fd` | Pick device |
| `<leader>Fe` | Pick emulator |
| `<leader>Fr` | Hot reload |
| `<leader>FR` | Hot restart |
| `<leader>Fq` | Quit running app |
| `<leader>Fo` | Widget outline |
| `<leader>Fl` | Dev log |
| `<leader>FD` | Start DevTools |

## Tests

| Keys | Action |
| --- | --- |
| `<leader>tt` | Run nearest test |
| `<leader>tf` | Run tests in this file |
| `<leader>tl` | Re-run last test |
| `<leader>ts` | Test summary panel |
| `<leader>to` | Test output |

## Run

| Keys | Action |
| --- | --- |
| `<leader>rr` | Run the Flutter app (`fvm flutter run --flavor …`) |
| `<leader>rl` | `adb logcat`, filtered to the app's pid — raw stream in a terminal |
| `<leader>rL` | Logcat **panel**: same stream as a real buffer. `<CR>` jumps to the source under the cursor (Dart `package:` URIs and JVM frames both resolve), `l` cycles the minimum level, `f` filters by text, `p` pauses, `F` toggles follow, `c` clears, `q` closes. Filters are retroactive — they apply to what already scrolled past. Also `:Logcat [package]`. |
| `<leader>rm` | Pick and run a melos script from `melos.yaml` |
| `<leader>rg` | Run a `./gradlew` task |
| `<leader>ra` | Clear the app id, so the next run re-detects it |
| `<leader>rf` | Re-pick the flavour |

The app id and flavour are read out of `android/app/build.gradle` at runtime —
the base `applicationId` plus the selected flavour's `applicationIdSuffix`.
Nothing is hardcoded, so this works in any Flutter/Android repo.

A typical Android setup resolves to `com.example.app` for `production` and
`com.example.app.<flavour>` for the rest; run `<leader>rf` to see what the
repo in front of you actually yields.


Both are overridable. The id is prompted with the detected value prefilled, so
a build type adding its own suffix is a one-key correction:

| Where | How |
| --- | --- |
| Permanently | `vim.g.android_app_id` / `vim.g.android_flavor` in `lua/config/options.lua` |
| This session | `:AndroidAppId com.example.app`, `:AndroidFlavor staging` |
| Reset | `:AndroidAppId` / `:AndroidFlavor` with no argument |

## HTTP (kulala)

Open any `.http` file. Requests live in the repo as text, so they diff and
review like code.

> **First run downloads a backend.** kulala fetches `kulala-core` (~20s) the
> first time you send a request, and until it finishes `<leader>hs` looks like
> it did nothing at all. It is not broken -- send the request again once
> "Backend installed successfully" appears. This happens once per machine.

| Keys | Action |
| --- | --- |
| `<leader>hs` | Send request under the cursor |
| `<leader>ha` | Send all requests in the file |
| `<leader>hr` | Replay last request |
| `<leader>ht` | Toggle body / headers view |
| `<leader>he` | Pick environment |
| `<leader>hc` | Copy as curl |

## Architecture — C4 / Structurizr

Open any `workspace.dsl`. Syntax highlighting and the `structurizr` filetype are
**built into Neovim** -- nothing is installed for this, and the plugin most
guides name (`jfcherng/vim-structurizr`) does not exist.

> **There is no language server.** The nvim-lspconfig PR for one was rejected and
> mason has no package, so nothing checks the DSL as you type. `<leader>Cv` is
> the substitute: it runs `structurizr validate` and puts violations in the
> quickfix list. Expect to press it.

| Keys | Action |
| --- | --- |
| `<leader>Cs` | Serve the model in a terminal split (`c4-local`) |
| `<leader>Cb` | Open `http://localhost:8081` in the browser |
| `<leader>Ce` | Export every view to Mermaid |
| `<leader>Cr` / `<leader>CR` | Render every view as an image — svg / png |
| `<leader>Cv` | Validate, violations into the quickfix list |
| `<leader>Ca` | Toggle Mermaid export on save |

`<leader>C`, not `<leader>c`: LazyVim owns `<leader>c` for code actions, rename
and inlay hints, and `cp`/`cu` went to package-info. Capital prefixes are how
this config groups a toolchain -- `<leader>X` Xcode, `<leader>F` Flutter.

Export on save is **off by default**, because each export starts a JVM. Turn it
on per session with `<leader>Ca` or `:C4AutoExport`; a burst of `:w` is debounced
into one run.

## Commands

| Command | Action |
| --- | --- |
| `:Logcat [package]` | Logcat panel, optionally scoped to one app |
| `:AndroidAppId [id]` | Override the detected app id (no argument resets) |
| `:AndroidFlavor [name]` | Override the detected flavour (no argument resets) |
| `:Semgrep [config]` | Scan into the problems panel. Defaults to `p/security-audit`. |
| `:Gitleaks` / `:Gitleaks!` | Secrets in the working tree / including git history |
| `:Trivy` | Dependency vulnerabilities, misconfig and secrets |
| `:OsvScan` | Lockfiles against the OSV advisory database |
| `:ApkDecompile [file]` | jadx an APK into a scratch dir and open it in the explorer |
| `:ApkManifest [file]` | apktool an APK's manifest and open it as XML |
| `:KotlinLspInstall` | Download the JetBrains Kotlin LSP |
| `:KotlinLspLegacy` | Fall back to fwcd's Kotlin server for this session |
| `:FormatToggle` | Turn format-on-save off for the session |
| `:DBUIToggle` (`<leader>D`) | Database client |

All the scanners share one shape: shell out, parse JSON, build a quickfix list,
open it in Trouble. None of them run on save — a scan over this monorepo takes
seconds and would stall every write. `:Gitleaks` reports rule and location only
and never prints the matched secret into a buffer.

Decompiler output goes to `stdpath('cache')/apk/`, never into the repo you have
open.

## Claude

| Keys | Action |
| --- | --- |
| `Cmd+L` | Toggle the Claude panel |
| `Cmd+Shift+L` | Add selection (visual) or current file (normal) to the chat |
| `Cmd+K` | **Inline edit.** Sends the selection (or the file, from normal mode), asks for the instruction in a float, and returns the answer as an inline diff over the selection — you never leave the buffer. Accept `<leader>ay`, reject `<leader>an`. `<leader>ak` is the old behaviour: jump into the Claude terminal and type freely. |
| `<leader>ac` / `<leader>af` | Toggle / focus Claude |
| `<leader>ar` / `<leader>aC` | Resume session / continue last conversation |
| `<leader>as` | Send selection |
| `<leader>ab` | Add current buffer |
| `<leader>ai` (in explorer) | Add the highlighted file |
| `<leader>am` | Pick model |
| `<leader>ay` / `<leader>an` | Accept / reject a proposed diff |
| `<leader>at` | Connection status |

Claude sees your active buffer and selection automatically, `@`-mentions
resolve against real files, and edits arrive as native Neovim diffs.

## Local AI — Ollama / Avante

Avante talks to the local Ollama server on `127.0.0.1:11434`. The active model is
global inside Neovim: `_G.ai_model` is set at startup from `vim.uv.get_total_memory()`,
so one config gets the largest model each machine can actually hold.

| RAM | Default | `<leader>aM` |
| --- | --- | --- |
| 32 GB+ | `qwen3-coder:30b` @ 16k | `qwen2.5-coder:7b` @ 16k |
| 16 GB | `qwen2.5-coder:7b` @ 16k | `qwen2.5-coder:14b` @ 8k |

The context window is a property of the model, not the tier, so the same tag gets
the same window in Avante and in aider. The tiers and the arithmetic behind those
numbers are in `lua/util/ai_model.lua`; the matching aider windows are in
`~/.aider.model.settings.yml`. Change one, change the other.

The 16 GB Air leads with the 7b even though the 14b fits at 8k: the M3 has half an
M1 Pro's memory bandwidth and no fan, so the 14b runs near 9 tok/s against the 7b's
18-20, and aider's `whole` format re-sends entire files on every edit.

| Keys | Action |
| --- | --- |
| `<leader>aa` | Avante: ask / open the sidebar |
| `<leader>aA` | Avante: refresh context |
| `<leader>aM` | Cycle the local model for Avante and the active aider session |
| `<leader>aR` | AI memory check — active model, macOS RAM and swap guard |
| `<leader>avn` | Avante: new ask |
| `<leader>ave` / `<leader>avf` | Avante: edit / focus |
| `<leader>avs` / `<leader>avz` | Avante: stop / zen mode |
| `<leader>avt` / `<leader>avd` | Avante: toggle sidebar / debug |
| `<leader>avg` / `<leader>avr` / `<leader>avv` | Avante: suggestion / repo map / selection toggles |
| `<leader>avc` / `<leader>avB` | Avante: add current file / all buffers |
| `<leader>avm` / `<leader>avh` | Avante: select model / history |
| `<leader>avM` / `<leader>avp` | Avante: select ACP model / mode |

## Agents — aider and cursor-agent

Both drive a CLI in a terminal split on the right. That is a different thing from
the Claude integration above: claudecode.nvim makes Neovim the editor Claude Code
*drives* — it sees the buffer, resolves `@`-mentions against real files and
returns native diffs. These two edit files on disk and the buffer reloads.

`<leader>A`, not `<leader>a`, because the AI group holds Claude and Avante
bindings and this keeps that muscle memory intact.

| Keys | Action |
| --- | --- |
| `<leader>Aa` | aider: toggle the session |
| `<leader>Ao` | aider: toggle the same session; first open uses a float |
| `<leader>Am` | aider: command menu (fuzzy over its slash-commands) |
| `<leader>Ab` / `<leader>Ad` | aider: add / drop this buffer |
| `<leader>AO` | aider: add this buffer read-only |
| `<leader>As` | aider: send selection (visual) or buffer |
| `<leader>AR` | aider: reset the session |
| `<leader>AH` | aider: health check — run this first if something looks wrong |
| `<leader>Aw` | aider: **watch-files mode** |
| `<leader>Ac` | cursor-agent: toggle |
| `<leader>Ar` | cursor-agent: resume the last session |

**Watch-files mode is the interesting one, and it needs no plugin at all.**
`aider --watch-files` watches files on disk for one-line comments ending in `AI`,
`AI!` or `AI?` — in any comment syntax. Leave notes as you work, then trigger:

```lua
-- rename this to something honest AI
local function doStuff() end  -- AI! apply the renames above
```

Saving the file is what fires it. `AI?` asks a question instead of editing. This
is upstream's own editor-integration story and works in any editor; the plugin
is convenience on top of it.

> **Neither is set up until you add a key.** aider needs `ANTHROPIC_API_KEY` in
> `~/.config/zsh/local/*.zsh`, and cursor-agent needs `cursor-agent login` once
> per machine. Both are machine-local by design and neither is in this repo.

## Trade-offs to know about

Ghostty forwards these chords to *whatever* is running, and only Neovim parses
CSI-u. At a zsh prompt they are silent (`~/.config/zsh/csiu.zsh` binds them to a
no-op widget); in another TUI they arrive as raw escape bytes.
Reassigned: `Cmd+K` (was clear screen), `Cmd+A` (was select all), `Cmd+D` (was
split), `Cmd+,` (was open config).

`Cmd+W` used to be on that list and was given back to Ghostty — it is
`close_surface` again. A prompt printed its escape bytes, and closing a
split/tab is the one Cmd meaning that is universal on macOS. Use `<leader>bd` to
close a buffer.

Also claimed, though it was not a Ghostty default: `Cmd+Shift+U` (symbol
outline).

Still available: `Cmd+C`, `Cmd+V`, `Cmd+T`, `Cmd+N`, `Cmd+Q`, plus
`Cmd+Shift+W` (close window), `Cmd+Shift+T` (new tab), `Cmd+Shift+N` (new
window), `Cmd+Shift+,` (open config), `Cmd+Shift+R` (reload config).

To give any chord back to the terminal, delete its `keybind` line from
`~/.config/ghostty/config` and press `Cmd+Shift+R`.

## Behaviour notes

- **The overview scrollbar** (satellite.nvim) is a 2-column gutter on the right
  edge of each editor window, marking git signs, diagnostics, search hits,
  quickfix entries and the cursor position. It replaced a real minimap
  (neominimap): terminals draw one glyph per cell at one font size, so a
  terminal minimap can only ever be braille dots — a density silhouette, never
  VS Code's small text. The marks were the useful part, so they stayed and the
  silhouette went.
- **Sticky scroll** (nvim-treesitter-context) pins the enclosing class, method
  and block to the top of the window as you scroll past their opening lines, up
  to four deep — VS Code's feature of the same name. `[c` jumps back up to the
  innermost one. It is the honest answer to what a minimap was for: it says
  *where you are* without spending a single column on it.
- **The symbol outline** (`Cmd+Shift+U` / `<leader>mo`, aerial.nvim) is the
  navigable stand-in for a minimap: functions, types and methods nested by scope
  in a right-edge column, following the cursor, `<CR>` to jump. LSP first,
  treesitter where no server is attached. It gets a Cmd chord because `<leader>`
  is a space, and space is unreachable in the windows you tend to sit in — a
  terminal sends it to the shell, neo-tree binds it to `toggle_node`. aerial
  outlines whatever window is *focused*, so the chord steps into the editor pane
  before toggling.
- **A text minimap was tried and removed.** It subsampled the file into a
  30-column strip of real, treesitter-coloured source. It worked, and it still
  was not worth the width: once a file is longer than the window each row stands
  for ten or more lines, and a one-in-ten sample of code is texture, not
  information. Sticky scroll and the outline replaced it. Do not rebuild it.
- **Dart** is served by `dartls`, started by flutter-tools through FVM (there
  is no `flutter` on PATH). In a melos repo it roots at the workspace, not the
  nearest `pubspec.yaml`, so goto-definition crosses package boundaries.
  Formatting goes through the LSP rather than the `dart format` CLI.
- **Kotlin** gets treesitter highlighting and ktlint formatting automatically.
  The LSP is now JetBrains' official `kotlin-lsp`, which — unlike fwcd's
  server — does not shell out to the Gradle CLI per module. Run
  `:KotlinLspInstall` once to fetch it. fwcd's server is still installed and
  reachable via `:KotlinLspLegacy` if the JetBrains one misbehaves; it is
  pre-1.0. For context on why the swap happened: fwcd's server resolves every
  Gradle module's classpath through the Gradle CLI, and with ~60 Flutter
  plugin modules it never finished initialising (measured: no attach after
  90s, one Gradle daemon per module).
- **Auto-save** writes about 1s after you stop typing, like VS Code's
  `files.autoSave: afterDelay`.
- **Format on save** runs only on *manual* saves (`Cmd+S`, `:w`,
  `Shift+Alt+F`), never on auto-saves, so the cursor never jumps mid-keystroke.
  `:FormatToggle` disables it for the session.
- **`vim.ui.select` / `vim.ui.input` are pinned to snacks explicitly** at the
  bottom of `lua/config/autocmds.lua`. Setting `picker.ui_select = true` and
  `input.enabled = true` is *not* sufficient on its own — something later in
  the load order puts Neovim's builtins back, and `:checkhealth snacks` will
  tell you. This matters because the flavour picker, app-id prompt, melos
  picker and gradle prompt all route through `vim.ui.*`. If those ever start
  rendering as a plain numbered list at the bottom of the screen, that hook
  is what broke.
- **One spec per `config`/`init`.** lazy.nvim keeps only ONE `config` and one
  `init` per plugin across all spec files — it does not chain them. That is
  why every scanner command lives in `plugins/scanners.lua` (a single `init`
  on trouble.nvim) and every task runner, Flutter and React Native alike,
  lives in `plugins/tasks.lua` (a single `config` on toggleterm). Splitting
  them across files silently drops one set.
- **`:checkhealth snacks` reports three errors** about `mmdc`, `pdflatex` and
  the kitty graphics protocol. Those are `snacks.image`, which is disabled and
  unused; the health check runs regardless. They are expected.
- The pre-LazyVim config and its plugin state have been deleted; the only copy
  now is the chezmoi git history. `~/.config/nvim.pre-lazyvim`,
  `~/.local/{share,state}/nvim.pre-lazyvim`, `~/.config/nvim.bak` and
  `nvim.backup-*` are all gone, so nothing here needs cleaning up.
