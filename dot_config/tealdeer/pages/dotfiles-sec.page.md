# dotfiles-sec

> Security toolchain shell aliases (dot_config/zsh/sec.zsh). Moved out of
> the baseline in the v12.0-audited migration -- `brewopt sec` first, plus
> `uv tool install frida-tools objection` by hand (see Brewfile.optional).
> Everything here operates on a local file, emulator, or a device you have
> attached, for applications you are authorized to test.
> More information: <https://github.com/aghnyap/dotfiles>.

- Full static scan of a directory (default: cwd):

`scan {{path/to/dir}}`

- semgrep, with the security-audit ruleset already set (`--config p/security-audit`):

`sg {{extra-args}}`

- semgrep's CI ruleset:

`sgci`

- gitleaks, redacted -- current branch's history (gitleaks scans commits by
  default; this is not a working-tree-only scan):

`leaks`

- gitleaks, redacted -- every branch's history (`--log-opts="--all"`):

`leakslog`

- Dependency/config vulnerabilities (trivy):

`vuln`

- OSV lockfile scan:

`osv`

- SBOM (syft):

`sbom`

- Decompile and scan an APK in one step:

`apkscan {{app.apk}}`

- Point the attached device at mitmproxy:

`proxyon`

- Release the attached device from mitmproxy:

`proxyoff`

- Start mitmweb:

`mitm`

- Install mitmproxy's CA into a running emulator:

`mitmca`

- frida-ps on the attached device:

`fps`

- frida-ps, installed apps only:

`fpsa`

- frida-ps against one package with a script:

`fridago {{package}} {{script}}`

- Push and start frida-server on the device:

`fridaserver`

- Quick nmap scan:

`nmapq {{target}}`

- Run a nuclei template set:

`nucl {{target}}`

- Decode a JWT:

`jwtd {{token}}`
