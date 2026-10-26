#!/usr/bin/env bash
# Install Beacon (local agent telemetry and project memory) and wire it into Claude Code and Codex.
# Local only: never signs in or connects to Beacon Cloud. Safe to re-run; finished steps are skipped.
# usage: beacon/setup.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = --dry-run ] && DRY_RUN=1
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

# 2. Endpoint: collector service plus Claude and Codex hooks. Reads past sessions into the local log.
status="$("$beacon_bin" endpoint status 2>/dev/null || true)"
if printf '%s\n' "$status" | grep -q 'running=true'; then
  say "endpoint running"
else
  run "$beacon_bin" endpoint install --user --harness auto --no-browser < /dev/null
fi

# 3. MCP server so agents can read memory and activity (get_memory_context, search_memory, ...).
if command -v claude > /dev/null 2>&1; then
  if claude mcp get "$MCP_NAME" > /dev/null 2>&1; then
    say "claude mcp $MCP_NAME present"
  else
    run claude mcp add -s user "$MCP_NAME" -- "$BIN/beacon" mcp serve --user --transport stdio
  fi
fi
codex_config="$HOME/.codex/config.toml"
if [ -d "$HOME/.codex" ]; then
  if grep -q "^\[mcp_servers\.$MCP_NAME\]" "$codex_config" 2>/dev/null; then
    say "codex mcp $MCP_NAME present"
  elif [ "$DRY_RUN" -eq 1 ]; then
    say "would add [mcp_servers.$MCP_NAME] to $codex_config"
  else
    printf '\n[mcp_servers.%s]\ncommand = "%s"\nargs = ["mcp", "serve", "--user", "--transport", "stdio"]\n' \
      "$MCP_NAME" "$BIN/beacon" >> "$codex_config"
    say "added $MCP_NAME to $codex_config"
  fi
fi

say "ready. Memory rules: skills/_shared/memory.md"
