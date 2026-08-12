#!/usr/bin/env python3
"""MCP server exposing this machine's mobile + security toolchain.

Why this exists
---------------
Claude Code already has Bash, so wrapping a CLI adds nothing by itself. What
this adds is a *contract*: each tool returns parsed JSON with a fixed shape, so
findings arrive as data instead of terminal output that has to be re-parsed
from scrollback. It also pins the flags that this repo already learned the hard
way -- the trivy skip-dirs list, gitleaks needing a real --report-path, the
logcat pid resolution -- so they cannot drift between the editor and the agent.

Scope and safety
----------------
Deliberately NOT a shell. Every tool takes a small, validated argument set and
builds an argv list; there is no passthrough of arbitrary flags and no
shell=True anywhere. Everything operates on a local path, a local emulator, or
an attached device -- consistent with the boundary stated in
~/.config/zsh/sec.zsh. It holds no credentials and reads none.

Protocol
--------
MCP over stdio is JSON-RPC 2.0: `initialize`, `notifications/initialized`,
`tools/list`, `tools/call`. That is small and stable enough to implement
against the stdlib, which keeps this file dependency-free -- no `mcp` package,
no node_modules, nothing for `mise` to pin.

Register it once, for every project:

    claude mcp add -s user mobilesec -- ~/.config/claude/mobilesec-mcp.py
"""

import json
import os
import shutil
import subprocess
import sys

PROTOCOL_VERSION = "2024-11-05"
ADB = os.path.expanduser("~/Library/Android/sdk/platform-tools/adb")

# Scanners are addressed by name, never by caller-supplied command. `REPORT` is
# replaced with a temp path for tools that refuse to write JSON to stdout.
SCANNERS = {
    "semgrep": ["semgrep", "--config", "p/security-audit", "--json", "--quiet", "."],
    "gitleaks": [
        "gitleaks", "detect", "--no-git", "--no-banner", "--redact",
        "--report-format", "json", "--report-path", "REPORT", "-s", ".",
    ],
    # Skipping build output is not cosmetic: unscoped, this walks build/,
    # .dart_tool/ and Pods/ and runs for minutes on a Flutter monorepo.
    "trivy": [
        "trivy", "fs", "--scanners", "vuln,secret,misconfig", "--format", "json", "--quiet",
        "--skip-dirs", "build,.dart_tool,.fvm,Pods,node_modules,.gradle,DerivedData", ".",
    ],
    "osv": ["osv-scanner", "scan", "source", "-r", "--format", "json", "."],
}

LEVELS = ["V", "D", "I", "W", "E", "F"]


def adb_bin():
    if os.path.exists(ADB):
        return ADB
    return shutil.which("adb")


def run(argv, cwd=None, timeout=300):
    try:
        p = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except FileNotFoundError:
        return 127, "", f"{argv[0]} is not installed"
    except subprocess.TimeoutExpired:
        return 124, "", f"{argv[0]} timed out after {timeout}s"


# ── tools ──────────────────────────────────────────────────────────────────
def tool_devices(_args):
    adb = adb_bin()
    if not adb:
        return {"error": "adb not found"}
    code, out, err = run([adb, "devices", "-l"], timeout=20)
    if code != 0:
        return {"error": err.strip() or "adb failed"}
    devices = []
    for line in out.splitlines()[1:]:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        entry = {"serial": parts[0], "state": parts[1] if len(parts) > 1 else "?"}
        for p in parts[2:]:
            if ":" in p:
                k, v = p.split(":", 1)
                entry[k] = v
        devices.append(entry)
    return {"devices": devices, "count": len(devices)}


def tool_logcat(args):
    adb = adb_bin()
    if not adb:
        return {"error": "adb not found"}
    package = args.get("package")
    lines = max(1, min(int(args.get("lines", 200)), 2000))
    min_level = str(args.get("min_level", "V")).upper()
    if min_level not in LEVELS:
        return {"error": f"min_level must be one of {LEVELS}"}

    argv = [adb, "logcat", "-d", "-v", "threadtime", "-t", str(lines)]
    scoped = None
    if package:
        code, out, _ = run([adb, "shell", "pidof", "-s", package], timeout=15)
        pid = out.strip()
        if code == 0 and pid:
            argv.append(f"--pid={pid}")
            scoped = pid
    argv.append(f"*:{min_level}")

    code, out, err = run(argv, timeout=60)
    if code != 0:
        return {"error": err.strip() or "logcat failed"}
    entries = []
    for line in out.splitlines():
        parts = line.split(None, 5)
        if len(parts) >= 6 and parts[4] in LEVELS:
            tag, _, msg = parts[5].partition(":")
            entries.append({"level": parts[4], "tag": tag.strip(), "message": msg.strip()})
        elif line.strip():
            entries.append({"level": "I", "tag": "", "message": line.strip()})
    return {
        "entries": entries,
        "count": len(entries),
        "scoped_to_pid": scoped,
        "note": None if scoped or not package else f"{package} is not running; stream is unfiltered",
    }


def tool_scan(args):
    name = args.get("scanner")
    if name not in SCANNERS:
        return {"error": f"scanner must be one of {sorted(SCANNERS)}"}
    path = os.path.abspath(os.path.expanduser(args.get("path", ".")))
    if not os.path.isdir(path):
        return {"error": f"not a directory: {path}"}

    argv = list(SCANNERS[name])
    report = None
    if "REPORT" in argv:
        import tempfile

        fd, report = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        argv = [report if a == "REPORT" else a for a in argv]

    code, out, err = run(argv, cwd=path, timeout=900)
    if report:
        try:
            with open(report) as fh:
                out = fh.read()
        finally:
            os.unlink(report)

    if not out.strip():
        # These exit non-zero *because* they found something, so the exit code
        # is not a usable success signal; emptiness plus a bad code is.
        if code not in (0, 1):
            return {"error": err.strip() or f"{name} exited {code}"}
        return {"scanner": name, "path": path, "findings": [], "clean": True}
    try:
        return {"scanner": name, "path": path, "raw": json.loads(out)}
    except json.JSONDecodeError:
        return {"error": f"{name} produced unparseable output", "stderr": err[-2000:]}


TOOLS = [
    {
        "name": "adb_devices",
        "description": "List attached Android devices and emulators with their properties.",
        "inputSchema": {"type": "object", "properties": {}},
        "handler": tool_devices,
    },
    {
        "name": "logcat",
        "description": (
            "Read recent Android logcat entries as structured data. Scopes to an app's "
            "pid when `package` is given and that app is running."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "package": {"type": "string", "description": "Application id, e.g. com.example.app"},
                "lines": {"type": "integer", "description": "How many recent lines (max 2000)"},
                "min_level": {"type": "string", "enum": LEVELS},
            },
        },
        "handler": tool_logcat,
    },
    {
        "name": "scan",
        "description": (
            "Run a security scanner over a local directory and return its JSON report. "
            "Flags are fixed by the server; only the scanner name and path are accepted."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "scanner": {"type": "string", "enum": sorted(SCANNERS)},
                "path": {"type": "string", "description": "Directory to scan (default: cwd)"},
            },
            "required": ["scanner"],
        },
        "handler": tool_scan,
    },
]
BY_NAME = {t["name"]: t for t in TOOLS}


# ── JSON-RPC plumbing ──────────────────────────────────────────────────────
def reply(msg_id, result=None, error=None):
    msg = {"jsonrpc": "2.0", "id": msg_id}
    if error is not None:
        msg["error"] = error
    else:
        msg["result"] = result
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def handle(msg):
    method, msg_id = msg.get("method"), msg.get("id")

    if method == "initialize":
        return reply(msg_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "mobilesec", "version": "1.0.0"},
        })

    if method in ("notifications/initialized", "notifications/cancelled"):
        return  # notifications carry no id and expect no response

    if method == "tools/list":
        return reply(msg_id, {
            "tools": [{k: t[k] for k in ("name", "description", "inputSchema")} for t in TOOLS]
        })

    if method == "tools/call":
        params = msg.get("params") or {}
        tool = BY_NAME.get(params.get("name"))
        if not tool:
            return reply(msg_id, error={"code": -32602, "message": f"unknown tool: {params.get('name')}"})
        try:
            result = tool["handler"](params.get("arguments") or {})
        except Exception as exc:  # a crashed tool must not kill the server
            result = {"error": f"{type(exc).__name__}: {exc}"}
        return reply(msg_id, {
            "content": [{"type": "text", "text": json.dumps(result, indent=2)}],
            "isError": bool(result.get("error")),
        })

    if msg_id is not None:
        reply(msg_id, error={"code": -32601, "message": f"method not found: {method}"})


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            handle(json.loads(line))
        except json.JSONDecodeError:
            continue


if __name__ == "__main__":
    main()
