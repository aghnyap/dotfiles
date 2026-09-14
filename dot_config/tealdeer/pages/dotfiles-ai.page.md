# dotfiles-ai

> Local and cloud AI tooling: aider (shell + Neovim), cursor-agent, Codex,
> and codecompanion.nvim/Claude inside Neovim. See dotfiles-nvim for the
> full keybinding tables.
> More information: <https://github.com/aghnyap/dotfiles>.

- aider on the local Ollama model -- no key, no network. Model must be
  passed explicitly at a shell (Neovim's `:AiModel` sets it per session):

`aider --model {{ollama_chat/qwen2.5-coder:7b}}`

- aider, acting on `AI!`/`AI?` comments as you save, no editor plugin needed:

`aider --watch-files`

- Ollama service and model management:

`brew services start ollama`

`ollama ls`

`ollama pull {{qwen2.5-coder:7b|qwen3-coder:30b}}`

`ollama rm {{tag}}`

- cursor-agent as a cloud CLI agent, or scripted one-shot:

`cursor-agent`

`cursor-agent -p {{"prompt"}}`

- Verify cursor-agent's login actually has model access (not just `status`):

`cursor-agent --list-models`

- Codex CLI agent in a project-root terminal split (inside Neovim: `<leader>Ax`):

`codex`

- litellm's OpenAI-compatible proxy, for codecompanion's `litellm` adapter:

`litellm --config {{path/to/config.yaml}}`
