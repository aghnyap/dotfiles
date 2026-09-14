# dotfiles-d2

> d2 architecture-as-code shell aliases (dot_config/zsh/d2.zsh), replacing
> the old Structurizr/C4 toolchain -- d2 is baseline, no `brewopt` group
> needed. Every command finds `workspace.d2` in `.`, `docs/architecture/`,
> or either from the git root, so they work from anywhere in the repo.
> More information: <https://github.com/aghnyap/dotfiles>.

- Scaffold `docs/architecture/workspace.d2` (C1/C2 as d2 layers):

`d2-init {{path/to/dir}}`

- Live-preview at http://localhost:8081 (override with `D2_PORT`):

`d2-local`

- Render every layer straight to an image (svg, png, or pdf) -- no export step:

`d2-render {{svg|png|pdf}}`

- Validate -- the only diagnostics that exist for it:

`d2-validate`

- Canonicalise workspace.d2 in place (d2's own formatter):

`d2-fmt`

- Short alias for `d2-local`:

`d2l`

- Short alias for `d2-render`:

`d2r`

- Short alias for `d2-validate`:

`d2v`
