# Cheatsheet

One page for the whole environment: Ghostty, tmux, Neovim, vim itself, the
shell, the security toolchain, and the terminal browser.

> **Keep this current.** Any change to a keybinding, alias, command or tool in
> this repo must be reflected here in the same commit. `dot_config/nvim/KEYBINDINGS.md`
> stays the exhaustive Neovim reference; this file is the quick one across
> *all* tools. See "Maintaining this file" at the bottom.

Leader is <kbd>Space</kbd>. tmux prefix is <kbd>Ctrl</kbd>+<kbd>a</kbd>.

---

## The one thing to know

The Cmd chords are **not** real Cmd keys by the time Neovim sees them. Ghostty
re-encodes each one as a CSI-u escape sequence, because macOS terminals swallow
Cmd. They deliberately avoid the Super bit — tmux has no Super modifier and
collapses it onto Meta, which killed every one of them inside a pane. So:

| You press | Ghostty sends | Neovim sees |
| --- | --- | --- |
| `Cmd+X` | `\E[<code>;6u` | `<C-S-X>` → aliased to `<D-x>` |
| `Cmd+Shift+X` | `\E[<code>;8u` | `<M-C-S-X>` → aliased to `<D-S-x>` |
| `Cmd+Alt+Arrow` | `\E[1;7A/B` | `<M-C-Arrow>` → aliased to `<M-D-Arrow>` |

Five ride a different letter on the wire, because Ctrl+that key *is* an ASCII
control code (`Ctrl+J`=NL, `Ctrl+M`=CR, `Ctrl+[`=Esc, ``Ctrl+` ``=NUL):
`Cmd+J`→`n`, ``Cmd+` ``→`q`, ``Cmd+Shift+` ``→`q` (mods 8), `Cmd+Shift+M`→`r`,
`Cmd+Shift+[`→`t`.
The key you press never changes. Full derivation in `dot_config/ghostty/config`.

**Consequence:** these chords are sent to whatever is running, and only Neovim
parses CSI-u. At a zsh prompt they are silent — `zsh/csiu.zsh` binds the family
to a no-op — but in **another TUI** they still arrive as raw escape bytes, so
prefer that TUI's own Ctrl/Alt bindings over the ⌘ equivalents its documentation
suggests.

---

## Ghostty (terminal)

| Keys | Action |
| --- | --- |
| `Cmd+Enter` or `Cmd+Ctrl+F` | Toggle fullscreen |
| `Cmd+Escape` | Drop-down quick terminal (**global** — works from any app) |
| `Cmd+C` / `Cmd+V` | Copy / paste |
| `Cmd+N` / `Cmd+T` / `Cmd+Q` | New window / new tab / quit |
| `Cmd+W` | Close split, else tab, else window (`close_surface`) |
| `Cmd+Alt+W` / `Cmd+Shift+W` | Close tab / close window |
| `Cmd+Shift+N` / `Cmd+Shift+T` | New window / new tab (reclaimed) |
| `Cmd+Shift+,` | Open Ghostty config |
| `Cmd+Shift+R` | Reload Ghostty config |
| `Cmd+Up` / `Cmd+Down` | Jump to top / bottom of Ghostty scrollback |

Scroll needs a real `scrollback-limit` (never `0`) **and** a surface created
after that setting. With `window-save-state = always`, Cmd+Q can restore old
no-scrollback tabs — open a new tab, or delete
`~/Library/Saved Application State/com.mitchellh.ghostty.savedState` and
relaunch, after changing the limit.

**Working directory:** standalone Ghostty and Terminal.app open new windows and
tabs in `~`; Ghostty splits inherit the current pane. IDE terminals (Cursor
`` Ctrl+` ``, Neovim ToggleTerm) are unaffected and stay at the project root.

**Ghostty actions this config gives up** to the editor — pressing these does the
Neovim thing, not the terminal thing: `Cmd+F` (was find), `Cmd+K` (clear
screen), `Cmd+A` (select all), `Cmd+D` (new split), `Cmd+Z` (undo), `Cmd+J`
(scroll to selection), `Cmd+,` (open config).

`Cmd+W` is **not** on that list, deliberately. It was, and a bare shell has no
CSI-u parser, so pressing it at a prompt printed the raw escape bytes
(`[119;6u`) instead of doing anything. Its terminal meaning is also the one
that is universal on macOS. Neovim closes buffers with `<leader>bd`.

The rest of the forwarded chords are silent at a prompt rather than printing
their bytes — `dot_config/zsh/csiu.zsh` binds the whole CSI-u family to a no-op
widget. They still work normally inside Neovim.

---

## tmux

Prefix is <kbd>Ctrl</kbd>+<kbd>a</kbd>. `prefix + a` sends a literal Ctrl+a.

| Keys | Action |
| --- | --- |
| `prefix` `\|` / `prefix` `-` | Split right / down (inherits current path) |
| `prefix` `c` | New window |
| `Ctrl+h/j/k/l` | Move between panes **and Neovim splits** — no prefix |
| `prefix` `H/J/K/L` | Resize pane (repeatable) |
| `prefix` `m` | Zoom pane toggle |
| `prefix` `e` | Broadcast typing to every pane in the window (toggle; shows ON/OFF). If input looks duplicated across panes, this is on |
| `prefix` `Ctrl+h` / `Ctrl+l` | Previous / next window |
| `prefix` `Tab` | Last window |
| `prefix` `o` | Session switcher (sesh: live sessions, zoxide dirs, configs) |
| `prefix` `Space` | Last session |
| `prefix` `P` | Project layout picker (mobile / web / backend / sec / arch) |
| `prefix` `X` | Kill session (confirms) |
| `prefix` `r` | Reload tmux.conf |
| `prefix` `u` | fzf over URLs visible in the pane |
| `prefix` `I` / `prefix` `U` | Install / update tmux plugins (tpm) |
| `prefix` `v` | Copy mode (vi keys) |

Copy mode: `v` begin selection, `Ctrl+v` rectangle, `y` copy to clipboard,
`Escape` cancel. Sessions auto-save every 15 min and restore on server start
(resurrect + continuum), including pane contents and Neovim sessions.

---

## Vim fundamentals

The part that is just vim, not this config.

### Motions
| Keys | Move |
| --- | --- |
| `h j k l` | left / down / up / right |
| `w` `b` `e` | word forward / back / end (`W B E` = whitespace-delimited) |
| `0` `^` `$` | line start / first non-blank / end |
| `gg` `G` `{n}G` | file start / end / line n |
| `{` `}` | paragraph back / forward |
| `Ctrl+u` `Ctrl+d` | half page up / down |
| `%` | matching bracket |
| `f{c}` `t{c}` | to next char / before it (`F` `T` backwards, `;` `,` repeat) |
| `*` `#` | search word under cursor forward / back |
| `''` `` `` `` | jump back to previous position |

### Operators — combine with any motion or text object
| Keys | Action |
| --- | --- |
| `d` `c` `y` | delete / change / yank |
| `>` `<` `=` | indent / outdent / auto-indent |
| `gu` `gU` `g~` | lowercase / uppercase / toggle case |
| `gc` | toggle comment (`gcc` = current line) |
| `.` | repeat last change |

### Text objects — `{operator}{i|a}{object}`
`i` = inner (contents), `a` = around (includes delimiters).

| Object | Is |
| --- | --- |
| `w` `s` `p` | word / sentence / paragraph |
| `"` `'` `` ` `` | quoted string |
| `(` `[` `{` `<` | bracket pair (or `b` / `B`) |
| `t` | HTML/XML tag |
| `f` `c` | function / class (treesitter, via mini.ai) |

So `ci"` changes inside quotes, `dap` deletes a paragraph, `yaf` yanks a whole
function.

### Registers, macros, marks
| Keys | Action |
| --- | --- |
| `"{r}y` / `"{r}p` | yank / paste using register r |
| `"+y` / `"+p` | system clipboard (clipboard is unnamedplus here, so plain `y` already syncs) |
| `q{r}` … `q` | record macro into register r |
| `@{r}` / `@@` | play macro / replay last |
| `m{m}` / `` `{m} `` | set mark / jump to it |

### Search and replace
| Keys | Action |
| --- | --- |
| `/` `?` | search forward / back (`n` `N` to repeat) |
| `:%s/old/new/g` | replace in file (`gc` suffix to confirm each) |
| `:%s/old/new/gc` | …with confirmation |

`inccommand=split` is on, so `:s` previews live in a split as you type.

### Visual mode
`v` charwise, `V` linewise, `Ctrl+v` blockwise. `gv` reselects the last
selection. In blockwise, `I` / `A` insert on every line.

---

## Neovim — Cursor-style chords

### Files & navigation
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
| `Tab` / `Shift+Tab` (normal) | Next / previous editor tab |
| `Cmd+S` | Save (also formats) |
| `Cmd+\` | Split current window right (a terminal split reuses the same shell) |
| `<leader>|` | Open an independent empty vertical split (terminal-aware) |
| `Cmd+,` | Open config files |

### Editing
| Keys | Action |
| --- | --- |
| `Cmd+Z` / `Cmd+Shift+Z` | Undo / redo |
| `Cmd+A` | Select all |
| `Cmd+/` | Toggle comment |
| `Cmd+D` / `Cmd+Shift+D` | Add cursor at next occurrence / all occurrences |
| `Cmd+Alt+Up` / `Cmd+Alt+Down` | Add cursor above / below (`Esc` collapses) |
| `Alt+Up` / `Alt+Down` | Move line up / down |
| `Alt+Shift+Up` / `Alt+Shift+Down` | Duplicate line |
| `Cmd+Shift+K` | Delete line |
| `Shift+Alt+F` | Format document |
| `Tab` / `Shift+Tab` (visual) | Indent / outdent |

### Code intelligence
| Keys | Action |
| --- | --- |
| `F12` / `gd` | Go to definition |
| `Shift+F12` / `gr` | Find all references |
| `gI` / `gy` | Implementation / type definition |
| `F2` / `<leader>cr` | Rename symbol |
| `Cmd+.` / `<leader>ca` | Quick fix (code action) |
| `K` | Hover docs |
| `[d` / `]d` | Previous / next diagnostic |
| `Cmd+Shift+M` | Problems panel |
| `<leader>ch` | Toggle inlay hints |

### Panels
| Keys | Action |
| --- | --- |
| ``Cmd+` `` or `Cmd+J` | Toggle bottom terminal |
| ``Cmd+Shift+` `` | Toggle an independent terminal (vertical split, beside the bottom one) |
| `Cmd+Shift+G` | Git UI (lazygit) |
| `Cmd+Shift+U` / `<leader>mo` | Symbol outline (aerial) |
| `<leader>mm` / `<leader>mr` | Toggle / redraw overview scrollbar |
| `[c` | Jump to enclosing scope (sticky scroll) |
| `Esc Esc` (terminal) | Leave terminal mode |
| `Ctrl+h/j/k/l` | Move across splits **and tmux panes** |

---

## Neovim — leader groups

<kbd>Space</kbd> then:

| Group | What |
| --- | --- |
| `f` | find (files, buffers, recent) |
| `s` | search (grep, symbols, help) |
| `c` | code (rename, action, format, inlay hints) |
| `g` | git |
| `b` | buffers |
| `u` | UI toggles |
| `x` | diagnostics / quickfix (Trouble) |
| `d` | debug (nvim-dap) |
| `t` | tests (neotest) |
| `r` | run / tasks |
| `F` | Flutter |
| `X` | Xcode / Swift |
| `h` | HTTP (kulala) |
| `a` | AI / Claude / codecompanion |
| `A` | agents (aider / cursor-agent) |
| `m` | overview & outline |
| `D` | database UI |

### Debug
`F5` continue · `F9` breakpoint · `F10` step over · `F11` step into ·
`Shift+F11` step out · `<leader>d…` full group.

### Tests
`<leader>tt` nearest · `<leader>tf` file · `<leader>tl` last ·
`<leader>ts` summary · `<leader>to` output.

### Run
| Keys | Action |
| --- | --- |
| `<leader>rr` | Run the Flutter app |
| `<leader>rl` | `adb logcat` — raw stream in a terminal |
| `<leader>rL` | Logcat **panel** (filterable, jump-to-source) — see below |
| `<leader>rm` | Pick and run a melos script |
| `<leader>rg` | Run a `./gradlew` task |
| `<leader>ra` / `<leader>rf` | Re-detect app id / re-pick flavour |
| `<leader>rnm` | Metro bundler |
| `<leader>rni` / `<leader>rna` | RN run-ios / run-android |
| `<leader>rnp` / `<leader>rnc` | pod install / reset Metro cache |

**Inside the logcat panel** (`<leader>rL`, or `:Logcat [package]`):
`<CR>` jump to source under cursor · `l` cycle minimum level ·
`f` filter text · `p` pause · `F` toggle follow · `c` clear · `q` close.
Filters are retroactive — they apply to what already scrolled past.

### Flutter
`<leader>Fd` device · `<leader>Fe` emulator · `<leader>Fr` hot reload ·
`<leader>FR` hot restart · `<leader>Fq` quit · `<leader>Fo` widget outline ·
`<leader>Fl` dev log · `<leader>FD` DevTools.

### Swift / iOS
`<leader>Xb` build · `<leader>Xr` build+run · `<leader>Xt` tests ·
`<leader>Xd` device · `<leader>Xs` scheme · `<leader>Xl` logs · `<leader>XX` picker.

### HTTP
`<leader>hs` send under cursor · `<leader>ha` send all · `<leader>hr` replay ·
`<leader>ht` body/headers · `<leader>he` environment · `<leader>hc` copy as curl.

### Cloud AI — Claude
| Keys | Action |
| --- | --- |
| `Cmd+L` | Toggle the Claude panel |
| `Cmd+Shift+L` | Add selection (visual) or file (normal) to the chat |
| `Cmd+K` | **Inline edit** — prompts in a float, returns an inline diff |
| `<leader>ay` / `<leader>an` | Accept / reject a proposed diff |
| `<leader>ak` | Focus the Claude terminal and type freely |
| `<leader>ac` / `<leader>af` | Toggle / focus Claude |
| `<leader>ar` / `<leader>aC` | Resume session / continue last |
| `<leader>as` / `<leader>ab` | Send selection / add buffer |
| `<leader>ai` (in explorer) | Add the highlighted file |
| `<leader>am` / `<leader>at` | Pick model / connection status |

### Local AI — Ollama / codecompanion
codecompanion.nvim replaced Avante in the v12.0-audited migration: an `ollama`
adapter for the local model below, and a `litellm` adapter (OpenAI-compatible,
`127.0.0.1:4000`) for whatever LiteLLM aggregates when that proxy is running.

| Keys | Action |
| --- | --- |
| `<leader>aa` | Toggle the chat |
| `<leader>ai` | Inline prompt (normal buffers; inside the file explorer this is Claude's "add file" instead) |
| `<leader>ax` | Actions menu |
| `<leader>aM` | Select the local model for this Neovim session (`:AiModel`, shared with aider) |
| `<leader>aR` | On-demand AI memory check (selected model + macOS RAM + swap) |

No model is selected at startup and nothing is persisted. The first request
opens the same picker as `:AiModel` / `<leader>aM`, verifies that Ollama serves
the exact tag, then resumes the requested action.

| Model | Ollama `num_ctx` | Prompt budget |
| --- | --- | --- |
| `qwen2.5-coder:7b` | 32,768 | 24,576 |
| `qwen3-coder:30b` | 32,768 | 24,576 |

The selector updates both codecompanion and the next aider launch: unlike
Avante, codecompanion's ollama adapter is a function re-evaluated per
request, so there is no separate cache to refresh. Close aider before
changing the selection — its live `/model` path can discard the managed prompt
budget.

There is **no ambient ghost-text completion**, by choice. `Cmd+K` is the cloud
Claude inline-edit path; `<leader>ai` is the local equivalent.

---

## Neovim commands

| Command | Action |
| --- | --- |
| `:AiModel [tag]` | Pick this session's local model (no argument opens the picker) |
| `:Semgrep [config]` | Scan into the problems panel (default `p/security-audit`) |
| `:Gitleaks` / `:Gitleaks!` | Secrets in the tree / including git history |
| `:Trivy` | Dependency vulns, misconfig, secrets |
| `:OsvScan` | Lockfiles against the OSV database |
| `:ApkDecompile [file]` | jadx an APK into a scratch dir and open it |
| `:ApkManifest [file]` | apktool an APK's manifest, open as XML |
| `:Logcat [package]` | Logcat panel |
| `:AndroidAppId` / `:AndroidFlavor` | Set or clear (no arg = reset) |
| `:KotlinLspInstall` / `:KotlinLspLegacy` | Kotlin LSP management |
| `:FormatToggle` | Format-on-save off for this session |
| `:DBUIToggle` (`<leader>D`) | Database client |

Scanners never run on save — a scan takes seconds and would stall every write.
`:Gitleaks` reports rule and location only, never the matched secret.
Decompiler output goes to `stdpath('cache')/apk/`, never into your repo.

---

## Shell

### Navigation & search
| Keys | Action |
| --- | --- |
| `Ctrl+R` | History search (atuin) |
| `Ctrl+T` | Fuzzy file picker (preview with bat/eza) |
| `Alt+C` | Fuzzy cd |
| `Ctrl+/` | Toggle preview in any fzf window |
| `Ctrl+y` | Copy the highlighted fzf entry |
| `Tab` | fzf-tab completion |
| `cd` | zoxide — frecency-ranked, replaces cd entirely |
| `Backspace` | Delete one character (hold repeats; macOS KeyRepeat is already fast) |
| `Ctrl+Backspace` | Delete whole word |

### Modern replacements — these rebind commands you already type
`ls`/`ll`/`la`/`lt` → eza · `cat` → bat (`catp` pages) · `grep` → **rg** ·
`top` → btop · `du` → dust · `df` → duf · `ps` → procs · `hex` → hexyl ·
`MANPAGER` → bat. `..` `...` `....` walk up; `-` is `cd -`; `v`/`vi`/`vim` → nvim.

**The replacements do not take the same flags, and the errors do not say so.**
The two that bite:

| You type | What happens |
| --- | --- |
| `grep -E 'a\|b'` | rg's `-E` is `--encoding` → `error parsing flag -E: unknown encoding` |
| `cat -v`, `cat -A`, `cat -n` | bat has none of them → `unexpected argument '-v' found` |

Reach for `command grep` / `command cat` when you want the real one — in a
script, in a pipeline you copied from somewhere, or any time the flag error looks
like it is about your data rather than about the alias. `\grep` works too.

### Everyday
`ide [dir]` open a project as an IDE · `tm [name]` bare tmux session ·
`f [query]` fuzzy-find and edit · `rgf <pattern>` ripgrep with preview ·
`mkcd` · `extract <archive>` · `port <n>` · `killport <n>` · `ips` ·
`serve` · `jsonf` · `path` · `reload` · `localip` · `now` ·
`terminal-browser open [url]` terminal browser ·
`term-tab [cmd]` Ghostty tab (never a new window) · `arc-open [url]` same for `$BROWSER`.

Git: `gs` `gla` `gpl` `lg` (lazygit) · `gbf` fuzzy branch switch ·
`gfc` fuzzy commit browser. oh-my-zsh's 197 `g*` aliases are also loaded.

Config: `zc` `zca` `zcd` `vc` `tc` `gc-conf` · `zr` reload shell.
chezmoi: `cm` `cma` `cmr` (re-add) `cmd` (diff) `cme` `cmcd`.

`brewopt` lists the optional package groups, `brewopt <group>` installs one. The
main Brewfile is the baseline every machine gets; these are opt-in per machine
and never installed by `chezmoi apply`:

| Group | Packages |
| --- | --- |
| `backend` | colima, docker, docker-compose, kubectl, hadolint |
| `mobilesec` | zbar (QR/barcodes), chafa (images as ANSI); `adb` is baseline |
| `secrets` | bitwarden-cli, oath-toolkit (`oathtool`, TOTP) |
| `secextra` | trufflehog, grype, dex2jar, ffuf — each overlaps a baseline tool |
| `extras` | unar + sevenzip (for `extract`), watchman, yq, jless, pre-commit, ghorg |

The baseline holds only what the managed workflows call. Ask the rendered file
for its current size rather than maintaining a stale number:

```sh
chezmoi execute-template '{{ includeTemplate "Brewfile" . }}' | grep -cE '^(brew|cask|tap) '
```

`chezmoi apply` also writes macOS system defaults — press-and-hold off and a fast
key repeat (the two that matter for `hjkl`), Finder showing extensions and the
path bar, screenshots to `~/Screenshots` as png. **The keyboard ones need a
logout.** Indentation comes from `~/.editorconfig`, which Android Studio, Xcode
and Cursor read as well as Neovim; the per-language table in
`nvim/lua/config/autocmds.lua` mirrors it and the two must stay in sync.

New machine: `./bootstrap.sh` from the repo root does the whole setup and then
verifies it — no flags, no questions, idempotent, so re-running is safe. It does
not set your git identity: `~/.gitconfig` is yours, hand-written per machine;
only `~/.config/git/config` (pager, editor, delta theme) is managed. See
`INSTALL.md`.

Repository maintenance: `./audit.sh` performs non-mutating syntax, model-budget,
key-ownership, template, Brewfile and gitleaks checks before commit or push.

### Mobile / dev
`fl` = `fvm flutter` · `fld` = `fvm dart` · `fldev` devices · `flr` run · `flc` clean · `flpg`/`flpu`
pub get/upgrade · `flt` test · `fla` analyze · `flgen` build_runner.
`ml` melos · `mlb` bootstrap · `mlc` clean.
Flutter/Dart extras: `fldr` doctor -v · `flgenw` build_runner **watch** ·
`flver` `fvm list` · `fldev` devices.
Gradle wrapper: `gwc` clean · `gwb` build · `gwr` bootRun · `gwtest` test ·
`gwtasks` tasks --all. (`gwt` is deliberately not used — it is a git alias.)
Node: `nrb` `npm run build` · `nrt` `npm run test` · `nx` = `npx`.
`apk-info <apk>` badging via aapt2 · `jdk [version]` switch JDK for the session.
Containers (needs `brewopt backend`): `dps` pretty `docker ps` · `dcu`/`dcd`
compose up -d / down · `dcl` compose logs -f · `k` = `kubectl`.
`gw` gradlew · `gwad` assembleDebug · `gwstop` kill daemons · `gwdebug` bootRun
with debugger on `:5005`.
`adbd` pick device · `logcat [pkg]` · `apkinstall` · `mirror` / `screenrec`
(scrcpy) · `adbr` restart adb.
`simlist` `simboot` `simshutdown` · `pods` `podsclean` · `xcclean`.
`ni` `nr` `nrd` `metro` `rnios` `rnandroid` `rnreset`.

### Security
`scan [dir]` full static pass · `sg` semgrep · `sgci` `semgrep ci` ·
`leaks` gitleaks · `leakslog` gitleaks across all history, redacted ·
`vuln` trivy · `osv` · `sbom` syft.
`apkscan <app.apk>` decompile + scan an APK.
`proxyon` / `proxyoff` point the device at mitmproxy · `mitm` start mitmweb ·
`mitmca` install the CA into an emulator.
`fps` / `fpsa` frida-ps · `fridago <pkg> [script]` · `fridaserver` push and start.
`nmapq` · `nucl` nuclei · `jwtd` decode a JWT.

> Everything here operates on a local file, a local emulator, or a device you
> have attached. For applications you are authorized to test.

### AI agents
`aider` local pair-programming in the terminal · `aider --watch-files` acts on
`AI!` / `AI?` comments when you save, no plugin needed · `cursor-agent` cloud
agent as a CLI, `cursor-agent -p '…'` for a scripted one-shot · `codex` Codex CLI
agent in a project-root terminal split.

In Neovim terminal agents live under `<leader>A` — `Aa` local aider, `Ac` cloud
cursor-agent, `Ax` Codex. Cloud Claude and local codecompanion stay on `<leader>a`;
which-key names the boundary on every request-producing action.

**aider runs a local model, no key and no network.** Neovim uses the model
selected for that process with `:AiModel`; at a shell, pass
`--model ollama_chat/<tag>` explicitly. There is no configured default. Ollama
serves on `127.0.0.1:11434` (loopback only).
`brew services start ollama` · `ollama ls` what is downloaded · `ollama ps`
what is loaded in RAM · `ollama stop <tag>` unload it · `ollama rm <tag>`
delete it.

Expect a real downgrade from a frontier model — roughly 8-16% against Sonnet's
56% on aider's polyglot benchmark. Fine for single-file edits, weak on multi-file
work. Model downloads and the three-file context contract are in README.

cursor-agent still needs `cursor-agent login` once; check it with
`cursor-agent --list-models`, not `status`.

### Architecture — C4 / Structurizr
`c4-init [dir]` scaffold `docs/architecture/{workspace.dsl,structurizr.properties}` ·
`c4-local` (`c4l`, or `c4-lite`) serve the model at `http://localhost:8081` ·
`c4-export` (`c4e`) every view to Mermaid, fenced into `.md` so it renders in a PR ·
`c4-render [svg|png]` (`c4r`) every view as an image into `images/` ·
`c4-validate` (`c4v`) · `c4-inspect`.

`c4-render` goes via PlantUML, which lays out with Graphviz. The exporter has no
`dot` format any more — `-format dot` answers *"Unknown export format"* — and its
PNG/SVG path needs a headless browser (the 1.98 GB container variant). PlantUML
does it locally instead. `plantuml -testdot` checks the pair.

Every command finds `workspace.dsl` in `.`, in `docs/architecture/`, or in either
from the git root — so they work from anywhere in the repo.

Port 8081, not the upstream default of 8080, because `mitm` and the tmux `sec`
layout hold 8080. Override with `C4_PORT=9000 c4-local`.

`c4-init` turns on auto-refresh (2000 ms), so editing the DSL updates the browser
without a reload — upstream ships that off. Layout you drag in the UI is saved to
`workspace.json` beside the DSL; commit it, or you re-drag every box.

There is no Structurizr language server, so `c4-validate` is the only diagnostics
that exist. In Neovim it is `<leader>Cv`, straight into the quickfix list.

---

## terminal-browser (terminal browser)

Replaced chawan in the v12.0-audited migration. Where chawan laid out real
CSS but had no JS runtime, terminal-browser renders actual Chromium (an
Electron app drawn into the terminal via the Kitty graphics protocol), so it
can finish a JS-heavy OAuth/SSO login chawan could not. No config file is
documented upstream — nothing under `dot_config/` for it. `mancha` (reading
man pages through chawan's `man:` scheme) is gone with chawan; there is no
replacement.

### Launching

| Command | Does |
| --- | --- |
| `terminal-browser` | Launch the browser |
| `terminal-browser open <url>` | Open a URL |
| `terminal-browser open --ssh <user@host> <url>` | Route that page's requests through a remote host |
| `terminal-browser --split right` | Open in a split pane to the right |
| `terminal-browser ls` | List open browsers |

Requires a terminal that speaks the Kitty graphics protocol: Ghostty, Kitty,
and a handful of others — covered here since Ghostty is the managed terminal.

### Keys (Linux; macOS swaps Ctrl for Cmd)

| Keys | Action |
| --- | --- |
| `Ctrl+l` | Edit URL |
| `Ctrl+t` | New tab |
| `Ctrl+k` / `Alt+k` | Command palette |
| `Ctrl+r` | Reload |
| `Ctrl+[` / `Ctrl+]` | Back / forward |
| `Ctrl+shift+f` | Find in page |
| `Ctrl+shift+i` / `F12` | Devtools |
| `Ctrl+q` | Quit |

**Same class of collision chawan had.** `Ctrl+l`/`Ctrl+k` are also
vim-tmux-navigator's pane-switch keys; `tmux.conf`'s `@vim_navigator_pattern`
lists the `terminal-browser` process for the same reason it used to list
`cha`, so those keys reach the browser instead of switching tmux panes.
Leave the pane with `prefix + o` or `prefix` + arrow while it's focused.

Neovim still opens Arc, not terminal-browser — `gx`, `:Open`, `<leader>gB`,
markdown preview, and C4 `<leader>Cb` all run `open -a 'Arc'`; the shell
exports `BROWSER=arc-open`. Run `term-tab terminal-browser open <url>` for a
manual terminal-browser tab.

Upstream does not document an authentication mechanism of its own — being a
real Chromium instance is what carries an OAuth SPA through, not a special
SSO feature. No note yet on whether chawan's old Google/GitLab-sign-in quirks
(needing JS forced on, a form control that only submits from a keypress) also
apply here; unverified until someone actually runs an SSO login through it.

---

## SSH remote access

Working on the project from any machine — including one where nothing else
gets installed — using only a terminal and a browser. `dot_config/zsh/functions.zsh`.

**SSO login for a CLI tool** (`gcloud`, `gh`, `aws`) needs no tooling at all —
use the device-code flow they already support: the CLI prints a URL and a
short code, open it in *any* browser (this machine, your phone, doesn't
matter), approve, the CLI polls and picks up the token. Nothing renders
remotely, so there's no pixelation question and no tunnel to set up.

| Command | Does |
| --- | --- |
| `gcloud auth login --no-browser` | Device-code login, prints URL + code |
| `gh auth login` | Auto-offers the device code when no local browser is detected over SSH |
| `glab auth login` | Same device-code flow for GitLab |
| `aws sso login` | Opens a device-code URL the same way |

**Browsing an SSO-gated or VPN-only site through the remote host's network**
needs a real tunneled browser — terminal-browser's own `--ssh` flag (above)
covers a single page; `sshbrowse` below is the persistent-tunnel alternative.

| Command | Does |
| --- | --- |
| `sshsocks <host> [port=1337]` | Open a SOCKS5 tunnel through `<host>` (`ssh -D`) |
| `sshsocks-stop [port=1337]` | Tear it down |
| `sshbrowse <host> [port=1337]` | Tunnel (starting one if needed) + launch a dedicated Firefox profile (`ssh-tunnel`) proxied through it, DNS included |

Firefox, not Arc: a work-managed Arc can have MDM policy blocking custom
launch flags or extensions, and this needs neither — a separate binary and
profile are untouched by any policy aimed at Arc. The `ssh-tunnel` profile
is dedicated to this traffic only; day-to-day browsing (`$BROWSER`, `gx`,
`:Open`) stays on Arc as before.

**Flutter web dev** needs neither of the above — Arc is already on the
remote box (it's a machine built from this same repo), and Flutter DevTools
runs over the Dart VM Service protocol, not Arc's DevTools Protocol, so any
local browser works, corporate Arc included, with no special config.

| Command | Does |
| --- | --- |
| `sshflutter <host> [web-port=8765] [dds-port=8766]` | Plain port-forward (no proxy) for a `flutter run -d web-server` build; open the printed `localhost` URLs in any local browser |

## Maintaining this file

This is a source file in the chezmoi repo, not a generated one. The only templates left are `.chezmoi.toml.tmpl` and the
installer script, neither of which is a config file you edit in $HOME. None of
the repo may name an employer, a person or a project: anything that would goes in `~/.gitconfig`, `~/.config/zsh/local/`, or
the project's own workspace settings.

When you change a keybinding, alias, command, or add a tool, update this file in
the same commit. The places that hold bindings:

Run `./audit.sh` before committing; it enforces the source contracts documented
here without applying the configuration.

| Source | Covers |
| --- | --- |
| `dot_config/ghostty/config` | Cmd chords and their CSI-u encoding |
| `dot_config/tmux/tmux.conf` | prefix, panes, sessions, copy mode |
| `dot_config/nvim/lua/config/keymaps.lua` | Cmd aliases and core editor maps |
| `dot_config/nvim/lua/plugins/*.lua` | per-domain groups and `:Commands` |
| `dot_config/zsh/{aliases,functions,dev,sec,fzf,tools,csiu,c4,zellij}.zsh` | shell |
| `dot_config/zsh/git-aliases.zsh` | fallback only — skipped when oh-my-zsh is present |
| `.chezmoitemplates/Brewfile` | terminal-browser install (macOS cask; no documented config file) |
| `dot_local/bin/executable_term-tab` | Ghostty new-tab launcher |
| `dot_config/nvim/KEYBINDINGS.md` | the exhaustive Neovim reference |
