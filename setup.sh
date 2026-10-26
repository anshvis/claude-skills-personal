#!/usr/bin/env bash
# Share ANSH source skills between hosts. No hooks, model defaults, or tmux setup.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
PROVIDERS=claude,codex
DRY_RUN=0
usage() {
  echo "Usage: $0 [--providers claude,codex,cursor] [--dry-run]"
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --providers) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PROVIDERS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
# Validate the whole selection before changing anything.
case "$PROVIDERS" in ''|,*|*,|*,,*) usage >&2; exit 2 ;; esac
IFS=',' read -r -a selected <<< "$PROVIDERS"
for provider in "${selected[@]}"; do
  case "$provider" in claude|codex|cursor) ;; *) echo "Unknown provider: $provider" >&2; exit 2 ;; esac
done
BACKUP="$HOME/.local/state/ansh-skills/backups/$(date +%Y%m%d%H%M%S)-$$"

link() {
  local src="$1" target="$2" backup
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    echo "unchanged $target"
    return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would link $target -> $src (back up any existing entry)"
    return
  fi
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    backup="$BACKUP/${target#"$HOME/"}"
    mkdir -p "$(dirname "$backup")"
    mv "$target" "$backup"
    echo "backed up $target -> $backup"
  fi
  ln -s "$src" "$target"
  echo "linked $target"
}

# Codex infers a plugin namespace from the resolved source's .claude-plugin parent.
# Keep a plain local mirror so the public skill names remain $ansh-plan, etc.
for provider in "${selected[@]}"; do
  source_root="$REPO"
  if [ "$provider" = codex ]; then
    source_root="$HOME/.local/share/ansh-skills/plain"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "would refresh plain-name Codex skill mirror at $source_root"
    else
      python3 - "$REPO" "$source_root" <<'PYTHON'
from pathlib import Path
import shutil
import sys
source, target = map(Path, sys.argv[1:])
target.mkdir(parents=True, exist_ok=True)
for name in ('skills', 'agents'):
    shutil.copytree(source / name, target / name, dirs_exist_ok=True)
for path in source.glob('ANSH*.md'):
    shutil.copy2(path, target / path.name)
PYTHON
    fi
  fi
  case "$provider" in
    claude) dest="$HOME/.claude/skills" ;;
    codex) dest="$HOME/.agents/skills" ;;
    cursor) dest="$HOME/.cursor/skills" ;;
  esac
  if [ "$provider" = claude ]; then
    # Retain the existing Claude installation's complete skill catalog.
    for d in "$REPO"/skills/*/; do link "${d%/}" "$dest/$(basename "$d")"; done
    for a in "$REPO"/agents/*.md; do link "$a" "$HOME/.claude/agents/$(basename "$a")"; done
  else
    # Install the complete catalog, including skills invoked by other skills.
    for d in "$REPO"/skills/*/; do
      [ -f "$d/SKILL.md" ] || continue
      link "$source_root/skills/$(basename "$d")" "$dest/$(basename "$d")"
    done
    link "$source_root/skills/_shared" "$dest/_shared"
  fi
  for f in "$REPO"/ANSH*.md; do link "$source_root/$(basename "$f")" "$dest/$(basename "$f")"; done
  # Portable reviewer prompts: these are reference docs, not host-specific agent registrations.
  link "$source_root/agents" "$dest/ANSH-agents"
  echo "$provider skills ready in $dest"
done
