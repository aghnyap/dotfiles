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

- Toggle the explorer sidebar:

`Cmd+B`

- Toggle the bottom terminal:

`Cmd+J`

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
