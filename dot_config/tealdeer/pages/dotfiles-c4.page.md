# dotfiles-c4

> C4/Structurizr architecture-as-code shell aliases (dot_config/zsh/c4.zsh).
> Not in the v12.0-audited manifest (d2 in the baseline covers
> architecture_and_diagrams instead) -- `brewopt arch` first. Every command
> finds `workspace.dsl` in `.`, `docs/architecture/`, or either from the git
> root, so they work from anywhere in the repo.
> More information: <https://github.com/aghnyap/dotfiles>.

- Scaffold `docs/architecture/{workspace.dsl,structurizr.properties}`:

`c4-init {{path/to/dir}}`

- Serve the model at http://localhost:8081 (override with `C4_PORT`):

`c4-local`

- Export every view to Mermaid, fenced into markdown for PR review:

`c4-export`

- Render every view as an image (svg or png) into `images/`:

`c4-render {{svg|png}}`

- Validate the DSL -- the only diagnostics that exist for it:

`c4-validate`

- Short alias for `c4-local`:

`c4l`

- Short alias for `c4-export`:

`c4e`

- Short alias for `c4-render`:

`c4r`

- Short alias for `c4-validate`:

`c4v`
