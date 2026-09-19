# dotfiles-chezmoi

> This repo's chezmoi + justfile workflow. See the `chezmoi` and `just`
> patch pages for generic upstream usage this page does not repeat, and
> CLAUDE.md for the full templating and git-safety conventions.
> More information: <https://github.com/aghnyap/dotfiles>.

- List every recipe this repo's justfile provides:

`just --list`

- Everything to run before committing (audit + gitleaks):

`just check`

- Preview what applying would change, without changing anything:

`just diff`

`just dry-run`

- Apply the source state to $HOME, then restore nvim plugins -- confirms
  first, the one recipe here that writes outside the repo:

`just apply`

- Pull a live edit (`~/.zshrc`, anything in `~/.config/nvim`) back into the
  repo -- the rule that catches everyone: `apply` without this first
  overwrites the edit:

`just readd`

- Everything to run before pushing to the public remote (checks, domain
  gate, drift, and an employer-name scan when `EMPLOYER_DOMAIN` is exported
  from `~/.config/zsh/local/`):

`just pre-push`

- Fail on any hostname or email domain not listed in `.domain-allowlist`:

`just domains`

- Applied-machine verification (fonts, glyphs, shell startup, plugin state):

`just verify`

- List optional package groups, then install one (never installed by `apply`):

`brewopt`

`brewopt {{group}}`

- Render a custom tealdeer page for a syntax check:

`just tldr-test`

- Check Neovim sidebar layout and buffer cycling against source (uses installed plugins):

`just nvim-sidebar-test`
