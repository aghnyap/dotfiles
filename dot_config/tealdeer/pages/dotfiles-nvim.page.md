# dotfiles-nvim

> Neovim keybindings and commands on top of LazyVim's own defaults. Leader
> is Space. Cmd chords work only inside Ghostty (CSI-u forwarded, see
> dot_config/ghostty/config); over SSH or another terminal use the plain
> vim/leader equivalent instead. This page is a summary, not exhaustive --
> press `<leader>` then wait for which-key to list the rest.
> More information: <https://github.com/aghnyap/dotfiles>.

- Quick open files (recent, buffers):

`Cmd+P`

- Command palette:

`Cmd+Shift+P`

- Search across the project:

`Cmd+Shift+F`

- Find in the current file:

`Cmd+F`

- Toggle the full-height left sidebar (Explorer → OPEN EDITORS → OPEN SHELLS).
  Each tabpage owns its panels and focus; file and shell lists include buffers
  from all tabpages. Shell visibility dots refer to the current tabpage:

`Cmd+B`

- OPEN EDITORS: the panel under the explorer listing open file buffers.
  Inside it, `<CR>`/`l` opens the buffer, `d` closes it:

`Ctrl+j` from the explorer, or click into the panel

- Close the last editor pane: closes that file (kept listed if unsaved) and
  reopens the next one from OPEN EDITORS, or an empty pane after the last
  file; closing that empty pane quits. `:qa` still quits outright:

`<C-w>q`, `:q` or `:wq`

- OPEN SHELLS: the panel under OPEN EDITORS listing every open terminal --
  toggleterm task runners, ad hoc terminals, and the Claude/cursor-agent/
  Codex/aider panels. Inside it, `<CR>`/`l` focuses or reopens the shell, `d`
  kills the job and closes it:

`Ctrl+j` twice from the explorer, or click into the panel

- Explorer: switch source via the winbar tabs (Files / Open / Git), or:

`:Neotree source=filesystem|buffers|git_status`

- Toggle the bottom terminal, between the sidebar and the full-height AI
  column on the right, whichever opened first. Cmd+backtick and task
  terminals use the same layout. OPEN SHELLS reopens hidden shells with their
  existing jobs:

`Cmd+J`

- Leave terminal mode in a ToggleTerm or AI terminal with one Escape (other
  terminals still receive Escape; use `Ctrl+\ Ctrl+n` there):

`<Esc>`

- Git UI (lazygit):

`Cmd+Shift+G`

- Go to definition:

`F12`

- Find all references:

`Shift+F12`

- Rename symbol:

`<leader>cr`

- Quick fix / code action:

`<leader>ca`

- Hover docs:

`K`

- Move across Neovim splits (LazyVim's own default binding; the plugin that
  used to carry this across the tmux pane boundary too was dropped along
  with tmux -- zellij's own pane-crossing key is Alt+arrow instead):

`Ctrl+h/j/k/l`

- Cloud Claude: toggle the panel:

`Cmd+L`

- Cloud Claude: inline edit (float prompt, inline diff):

`Cmd+K`

- Cloud Claude: accept a proposed diff:

`<leader>ay`

- Cloud Claude: reject a proposed diff:

`<leader>an`

- Local/aggregated AI (codecompanion): toggle chat:

`<leader>aa`

- codecompanion: inline prompt:

`<leader>ai`

- codecompanion: actions menu:

`<leader>ax`

- Select this session's AI model, local or OpenRouter, shared with aider
  (`:AiModel`):

`<leader>aM`

- Murmur: dictate into buffer (needs a local whisper-server running, see
  `plugins/murmur.lua`):

`<leader>vd`

- Murmur: health check:

`<leader>vh`

- Terminal agent: toggle local aider:

`<leader>Aa`

- Terminal agent: toggle cloud cursor-agent:

`<leader>Ac`

- Terminal agent: toggle Codex:

`<leader>Ax`

- Run the Flutter app:

`<leader>rr`

- Attach the debugger to a JVM on :5005:

`<leader>dA`

- Run the nearest test:

`<leader>tt`

- Scan into the problems panel with semgrep:

`:Semgrep {{config}}`

- Scan for secrets in the working tree:

`:Gitleaks`

- Scan for secrets across the full git history:

`:Gitleaks!`

- Dependency vulns, misconfig, secrets:

`:Trivy`

- Lockfiles against the OSV database:

`:OsvScan`

- Validate the C4/d2 model, straight into the quickfix list:

`<leader>Cv`

- Decompile an APK (jadx) into a scratch dir and open it:

`:ApkDecompile {{path/to/app.apk}}`

- Open just an APK's manifest (apktool), as XML:

`:ApkManifest {{path/to/app.apk}}`

- Filterable, jump-to-source logcat panel for one package:

`:Logcat {{package}}`
