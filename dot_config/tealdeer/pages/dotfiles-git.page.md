# dotfiles-git

> This repo's own git helpers, on top of oh-my-zsh's ~197 `g*` aliases
> (dot_config/zsh/git-aliases.zsh is a vendored fallback, used only when
> oh-my-zsh itself is absent). See also the `chezmoi` patch page for
> chezmoi-specific git-style aliases.
> More information: <https://github.com/aghnyap/dotfiles>.

- Short status:

`gs`

- Pretty one-line log (all branches):

`gla`

- Pull, rebasing on top of local work:

`gpl`

- Open lazygit in the current repo:

`lg`

- Fuzzy-pick and switch to a local or remote branch:

`gbf`

- Fuzzy-browse commits, then act on the one selected:

`gfc`

- Note: `gwt` is deliberately not a worktree alias here -- oh-my-zsh's git
  plugin already claims it (`git whatchanged --patch`). Use `git worktree`
  directly.
