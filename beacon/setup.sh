#!/usr/bin/env bash
# Install Beacon (local agent telemetry and project memory) and wire it into the selected hosts.
# Local only: never signs in or connects to Beacon Cloud. Safe to re-run; finished steps are skipped.
# usage: beacon/setup.sh [--providers claude,codex,cursor] [--dry-run]
set -euo pipefail

DRY_RUN=0
PROVIDERS=claude,codex,cursor
while [ "$#" -gt 0 ]; do
  case "$1" in
    --providers) [ "$#" -ge 2 ] || exit 2; PROVIDERS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Usage: $0 [--providers claude,codex,cursor] [--dry-run]" >&2; exit 2 ;;
  esac
done
case "$PROVIDERS" in ''|,*|*,|*,,*) echo "Invalid providers" >&2; exit 2 ;; esac
IFS=',' read -r -a selected <<< "$PROVIDERS"
for provider in "${selected[@]}"; do
  case "$provider" in claude|codex|cursor) ;; *) echo "Unknown provider: $provider" >&2; exit 2 ;; esac
done
has_provider() { case ",$PROVIDERS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
BIN="$HOME/.local/bin"
RELEASES="https://github.com/asymptote-labs/agent-beacon/releases"
MCP_NAME=aw-beacon

say() { echo "beacon: $*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "would run: $*"; else "$@"; fi; }

# 1. Binaries: the release tarball, checksum-verified, into ~/.local/share/beacon/<version>.
beacon_bin="$(command -v beacon 2>/dev/null || true)"
[ -n "$beacon_bin" ] || { [ -x "$BIN/beacon" ] && beacon_bin="$BIN/beacon"; } || true
if [ -n "$beacon_bin" ]; then
  say "installed ($("$beacon_bin" version 2>/dev/null | head -1))"
else
  case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) say "unsupported OS, skipped"; exit 0 ;; esac
  case "$(uname -m)" in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=amd64 ;; *) say "unsupported arch, skipped"; exit 0 ;; esac
  version="${BEACON_VERSION:-}"
  if [ -z "$version" ]; then
    version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$RELEASES/latest" | sed -E 's#.*/tag/v?##')"
  fi
  [ -n "$version" ] || { say "could not find the latest release, skipped"; exit 0; }
  tarball="beacon_${version}_${os}_${arch}.tar.gz"
  dest="$HOME/.local/share/beacon/$version"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "would download $tarball, verify it against checksums.txt, unpack to $dest, link into $BIN"
  else
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/$tarball" "$RELEASES/download/v$version/$tarball"
    curl -fsSL -o "$tmp/checksums.txt" "$RELEASES/download/v$version/checksums.txt"
    want="$(grep " $tarball\$" "$tmp/checksums.txt" | awk '{print $1}')"
    got="$(shasum -a 256 "$tmp/$tarball" | awk '{print $1}')"
    [ -n "$want" ] && [ "$want" = "$got" ] || { say "checksum mismatch for $tarball, not installed"; exit 1; }
    mkdir -p "$dest" "$BIN"
    tar -xzf "$tmp/$tarball" -C "$dest"
    for b in beacon beacon-hooks beacon-otelcol; do ln -sfn "$dest/$b" "$BIN/$b"; done
    say "installed $version"
  fi
  beacon_bin="$BIN/beacon"
fi
case ":$PATH:" in *":$BIN:"*) ;; *) say "add $BIN to PATH so skills can call beacon" ;; esac

# 2. Refresh the selected hooks even when the collector is already running, so adding a host
# later works. Beacon's install is idempotent; no Cloud connection is requested.
run "$beacon_bin" endpoint install --user --harness "$PROVIDERS" --no-browser < /dev/null

# 3. MCP server so agents can read memory and activity (get_memory_context, search_memory, ...).
if has_provider claude && command -v claude > /dev/null 2>&1; then
  if claude mcp get "$MCP_NAME" > /dev/null 2>&1; then
    say "claude mcp $MCP_NAME present"
  else
    run claude mcp add -s user "$MCP_NAME" -- "$beacon_bin" mcp serve --user --transport stdio
  fi
fi
codex_config="$HOME/.codex/config.toml"
if has_provider codex; then
  if grep -q "^\[mcp_servers\.$MCP_NAME\]" "$codex_config" 2>/dev/null; then
    say "codex mcp $MCP_NAME present"
  elif [ "$DRY_RUN" -eq 1 ]; then
    say "would add [mcp_servers.$MCP_NAME] to $codex_config"
  else
    mkdir -p "$(dirname "$codex_config")"
    printf '\n[mcp_servers.%s]\ncommand = "%s"\nargs = ["mcp", "serve", "--user", "--transport", "stdio"]\n' \
      "$MCP_NAME" "$beacon_bin" >> "$codex_config"
    say "added $MCP_NAME to $codex_config"
  fi
fi

# Cursor uses a global JSON MCP config. Preserve other servers and user customizations.
if has_provider cursor; then
  python3 - "$HOME/.cursor/mcp.json" "$MCP_NAME" "$beacon_bin" "$DRY_RUN" <<'PYTHON'
import json
from pathlib import Path
import shutil
import sys
from datetime import datetime

path = Path(sys.argv[1])
name, binary, dry_run = sys.argv[2:]
try:
    config = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(config, dict) or not isinstance(config.get('mcpServers', {}), dict):
        raise ValueError('expected an object with an mcpServers object')
except (ValueError, OSError) as exc:
    raise SystemExit(f'beacon: cannot read {path}: {exc}; left unchanged')
servers = config.setdefault('mcpServers', {})
if name in servers:
    print(f'beacon: cursor mcp {name} present')
elif dry_run == '1':
    print(f'beacon: would add cursor mcp {name} to {path}')
else:
    if path.exists():
        backup = Path.home() / '.local/state/ansh-skills/backups' / datetime.now().strftime('%Y%m%d%H%M%S%f') / 'cursor-mcp.json'
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup)
    servers[name] = {'command': binary, 'args': ['mcp', 'serve', '--user', '--transport', 'stdio']}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(config, indent=2) + '\n')
    print(f'beacon: added cursor mcp {name} to {path}')
PYTHON
fi

# 4. Nightly memory drafts with the Jev evaluator (beacon/evaluate.sh), only when a key exists.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -s)" = Darwin ]; then
  label=com.ansh.beacon-evaluate
  plist="$HOME/Library/LaunchAgents/$label.plist"
  if ! security find-generic-password -s ansh-jev-api-key > /dev/null 2>&1 && [ -z "${TYPESAFE_API_KEY:-}" ]; then
    say "no Jev key; nightly evaluation not scheduled. Add one with: security add-generic-password -U -a \"\$USER\" -s ansh-jev-api-key -w"
  elif [ "$DRY_RUN" -eq 1 ]; then
    say "would schedule $label daily at 03:00 -> $REPO/beacon/evaluate.sh"
  else
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.local/state/ansh-skills"
    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>$REPO/beacon/evaluate.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>3</integer><key>Minute</key><integer>0</integer></dict>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$BIN:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>StandardOutPath</key><string>$HOME/.local/state/ansh-skills/beacon-eval.log</string>
  <key>StandardErrorPath</key><string>$HOME/.local/state/ansh-skills/beacon-eval.log</string>
</dict></plist>
PLIST
    launchctl bootout "gui/$(id -u)/$label" > /dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$plist" && say "scheduled $label daily at 03:00"
  fi
else
  say "nightly evaluation: add a cron line for $REPO/beacon/evaluate.sh"
fi

say "ready. Memory rules: skills/_shared/memory.md"
