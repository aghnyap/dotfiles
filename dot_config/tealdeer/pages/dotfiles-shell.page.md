# dotfiles-shell

> Shell aliases, functions, modern-tool replacements, and chezmoi shortcuts
> from this repo's zsh modules (dot_config/zsh/{aliases,functions,dev,tools}.zsh).
> Ctrl+R history (atuin), Ctrl+T fuzzy file picker and Alt+C fuzzy cd are fzf
> keybindings, not commands, and are not listed here.
> More information: <https://github.com/aghnyap/dotfiles>.

- Modern replacements for commands you already type -- same name works;
  `command <name>` or a leading `\` reaches the real one (ls: eza, cat: bat,
  grep: ripgrep, top: btop, du: dust, df: duf, ps: procs):

`ls {{path/to/dir}}`

- Open a project as a zellij session with the right layout guessed from the tree:

`ide {{path/to/project}}`

- Force one project layout (mobile, web, backend, sec, or arch):

`ide -l {{layout}} {{path/to/project}}`

- Bare zellij session, attach-or-create, named after the current directory:

`zj {{name}}`

- Interactive layout + directory picker (same as zellij's own Ctrl+o p):

`zjp`

- Fuzzy-find a file and open it in $EDITOR:

`f {{query}}`

- Ripgrep with a live fzf preview:

`rgf {{pattern}}`

- Make a directory and cd into it in one step:

`mkcd {{path/to/directory}}`

- Extract any archive by its extension (zip, tar.gz, 7z, rar, ...):

`extract {{archive}}`

- Show whatever is listening on a local port:

`port {{number}}`

- Kill whatever is listening on a local port:

`killport {{number}}`

- Open a URL in a new Ghostty tab (terminal-browser), never a new window:

`term-tab terminal-browser open {{url}}`

- List optional Brewfile package groups:

`brewopt`

- Install one optional package group:

`brewopt {{group}}`

- chezmoi: show what would change:

`cmd`

- chezmoi: pull a live edit back into the repo:

`cmr`

- chezmoi: add a new file from $HOME into the repo:

`cma`

- chezmoi: open a managed file's source in $EDITOR, then apply on save:

`cme`

- chezmoi: jump to the source repo:

`cmcd`
