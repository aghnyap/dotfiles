#!/usr/bin/env bash
# Source-level regression checks for this repository. Unlike bootstrap.sh, this
# does not install or apply anything: it proves the source remains internally
# consistent before a commit or push.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0

ok()   { printf '  ok      %s\n' "$1"; }
bad()  { printf '  FAIL    %s\n' "$1" >&2; fail=1; }
skip() { printf '  skip    %s\n' "$1"; }

check() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label"; fi
}

cd "$ROOT" || exit 1
printf '==> source audit\n'

# Shell and template syntax.
check "bootstrap bash syntax" bash -n bootstrap.sh
check "macOS defaults bash syntax" bash -n run_onchange_after_macos-defaults.sh
if rg -q 'Lazy! restore' bootstrap.sh && ! rg -q 'Lazy! sync' bootstrap.sh; then
  ok "bootstrap preserves Neovim lockfile"
else
  bad "bootstrap preserves Neovim lockfile"
fi
for file in dot_zshrc dot_zprofile dot_zshenv dot_config/zsh/*.zsh; do
  check "zsh syntax: $file" zsh -n "$file"
done
if chezmoi execute-template < run_onchange_before_install-packages.sh.tmpl > "$TMP/install.sh" 2>/dev/null; then
  check "rendered installer bash syntax" bash -n "$TMP/install.sh"
else
  bad "render package installer template"
fi
if rg -q 'aider-chat@0\.86\.2$' run_onchange_before_install-packages.sh.tmpl; then
  ok "tested aider version pinned"
else
  bad "tested aider version pinned"
fi
if chezmoi execute-template --init < .chezmoi.toml.tmpl >/dev/null 2>&1 \
  && ! rg -q 'prompt(Bool|String|Int|Choice)' .chezmoi.toml.tmpl; then
  ok "prompt-free chezmoi initialization"
else
  bad "prompt-free chezmoi initialization"
fi

templates=$(rg --files --hidden -g '!.git/**' -g '*.tmpl' | sort)
expected_templates=$(printf '%s\n' .chezmoi.toml.tmpl run_onchange_before_install-packages.sh.tmpl | sort)
if [[ $templates == "$expected_templates" ]]; then
  ok "only non-config templates exist"
else
  bad "only non-config templates exist"
fi

# The explicit zsh module list must cover every module on disk. A missing entry
# fails silently at shell startup, which is why this is an assertion.
{
  printf '%s\n' git-aliases
  sed -n 's/^_mods=(\(.*\))/\1/p' dot_zshrc | tr ' ' '\n'
} | sort -u > "$TMP/expected-modules"
for file in dot_config/zsh/*.zsh; do
  basename "$file" .zsh
done | sort -u > "$TMP/actual-modules"
if diff -u "$TMP/expected-modules" "$TMP/actual-modules" >/dev/null; then
  ok "zsh _mods covers every module"
else
  bad "zsh _mods covers every module"
fi

# Flutter is selected per repository by FVM. A global SDK PATH or pubspec root
# would defeat that pin or spawn one dartls per package in a monorepo.
if awk '!/^[[:space:]]*#/ && /PATH=.*(flutter|dart)/ && $0 !~ /\.fvm_flutter/' dot_zshenv | rg -q .; then
  bad "no global Flutter or Dart PATH"
else
  ok "no global Flutter or Dart PATH"
fi
if rg -q "root_patterns = \\{ 'melos.yaml', '.git' \\}" dot_config/nvim/lua/plugins/lang-flutter.lua \
  && ! rg -q 'root_patterns.*pubspec\\.yaml' dot_config/nvim/lua/plugins/lang-flutter.lua; then
  ok "single dartls root policy"
else
  bad "single dartls root policy"
fi
if rg -q 'return shutil\.which\("adb"\)' dot_config/claude/executable_mobilesec-mcp.py; then
  ok "mobile MCP resolves adb from PATH"
else
  bad "mobile MCP resolves adb from PATH"
fi
if rg -q '^secrets_filter = true$' dot_config/private_atuin/private_config.toml; then
  ok "Atuin secret filtering is explicit"
else
  bad "Atuin secret filtering is explicit"
fi

# Normalize the model contract from its three required client formats.
output_tokens=$(sed -n 's/^local OUTPUT_TOKENS = \([0-9][0-9]*\)$/\1/p' dot_config/nvim/lua/util/ai_model.lua)
if [[ -n $output_tokens ]]; then
  sed -n "s/.*{ model = '\\([^']*\\)', context = \\([0-9][0-9]*\\) }.*/\\1|\\2/p" \
    dot_config/nvim/lua/util/ai_model.lua |
    while IFS='|' read -r model context; do
      printf '%s|%s|%s|%s\n' "$model" "$context" "$((context - output_tokens))" "$output_tokens"
    done | sort > "$TMP/catalog"
else
  : > "$TMP/catalog"
fi

awk '
  /^- name: ollama_chat\// {
    model=$3
    sub(/^ollama_chat\//, "", model)
  }
  /^    num_ctx:/ { print model "|" $2 }
' dot_aider.model.settings.yml | sort > "$TMP/settings"

jq -r '
  to_entries[]
  | [
      (.key | sub("^ollama_chat/"; "")),
      (.value.max_tokens | tostring),
      (.value.max_input_tokens | tostring),
      (.value.max_output_tokens | tostring)
    ]
  | join("|")
' dot_aider.model.metadata.json | sort > "$TMP/metadata"

cut -d'|' -f1,2 "$TMP/catalog" > "$TMP/catalog-settings"
model_count=$(wc -l < "$TMP/catalog" | tr -d ' ')
whole_count=$(rg -c '^  edit_format: whole$' dot_aider.model.settings.yml || true)
if [[ -s $TMP/catalog ]] \
  && diff -u "$TMP/catalog" "$TMP/metadata" >/dev/null \
  && diff -u "$TMP/catalog-settings" "$TMP/settings" >/dev/null \
  && [[ $whole_count == "$model_count" ]]; then
  ok "local AI model/context contract"
else
  bad "local AI model/context contract"
fi

# Baseline and opt-in groups must remain disjoint. Flutter/Dart stay per-project.
rg '^(brew|cask) "' .chezmoitemplates/Brewfile |
  sed -E 's/^(brew|cask) "([^"]+)".*/\2/' | sort -u > "$TMP/baseline"
rg '^(brew|cask) "' .chezmoitemplates/Brewfile.optional |
  sed -E 's/^(brew|cask) "([^"]+)".*/\2/' | sort -u > "$TMP/optional"
if [[ -z $(comm -12 "$TMP/baseline" "$TMP/optional") ]] \
  && ! rg -q '^(brew|cask) "(flutter|dart)"' .chezmoitemplates/Brewfile \
  && rg -q '^cask "android-platform-tools"$' .chezmoitemplates/Brewfile; then
  ok "Brewfile baseline and optional groups are disjoint"
else
  bad "Brewfile baseline and optional groups are disjoint"
fi
if ! rg -q '^brew "luarocks"$' .chezmoitemplates/Brewfile \
  && [[ ! -e dot_config/zsh/completions/_openspec ]] \
  && rg -q '^\.config/zsh/completions/_openspec$' .chezmoiremove; then
  ok "known orphaned tooling remains removed"
else
  bad "known orphaned tooling remains removed"
fi

# Lock in the two lazy.nvim ownership traps that otherwise fail silently.
if ! rg -q 'config =|init =' dot_config/nvim/lua/plugins/structurizr.lua \
  && ! rg -q "cmd = 'Aider'" dot_config/nvim/lua/plugins/agents.lua; then
  ok "single-owner lazy plugin configuration"
else
  bad "single-owner lazy plugin configuration"
fi

# Load the source tree itself (not the currently applied copy) while reusing the
# installed lazy.nvim data directory. This catches Lua/spec errors before apply.
mkdir -p "$TMP/xdg" "$TMP/data/nvim" "$TMP/state" "$TMP/cache"
ln -s "$ROOT/dot_config/nvim" "$TMP/xdg/nvim"
for dir in lazy mason site; do
  [[ -e $HOME/.local/share/nvim/$dir ]] && ln -s "$HOME/.local/share/nvim/$dir" "$TMP/data/nvim/$dir"
done
if command -v nvim >/dev/null 2>&1; then
  if XDG_CONFIG_HOME="$TMP/xdg" XDG_DATA_HOME="$TMP/data" XDG_STATE_HOME="$TMP/state" XDG_CACHE_HOME="$TMP/cache" \
    nvim --headless -i NONE \
    -c 'lua local m=require("util.ai_model"); assert(m.current()==nil); assert(vim.fn.exists(":AiModel")==2)' \
    -c 'Lazy load avante.nvim' \
    -c 'lua assert(vim.fn.maparg("<leader>aM", "n") ~= ""); assert(vim.fn.maparg("<leader>avm", "n") == ""); assert(vim.fn.maparg("<leader>aa", "n", false, true).desc=="Avante (local): ask"); assert(vim.fn.maparg("<leader>ave", "v", false, true).desc=="Avante (local): edit selection"); assert(vim.fn.maparg("<leader>avg", "n", false, true).desc=="Avante (local): toggle suggestions"); assert(vim.fn.exists(":Aider")==0)' \
    -c qa >/dev/null 2>&1; then
    ok "headless Neovim source and AI key ownership"
  else
    bad "headless Neovim source and AI key ownership"
  fi
else
  skip "headless Neovim source and AI key ownership (nvim absent)"
fi

if command -v gitleaks >/dev/null 2>&1; then
  check "gitleaks source scan" gitleaks detect --no-git -s .
else
  bad "gitleaks source scan (gitleaks absent)"
fi

if (( fail == 0 )); then
  printf '==> audit passed\n'
else
  printf '==> audit failed\n' >&2
fi
exit "$fail"
