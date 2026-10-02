#!/usr/bin/env bash
# Symlink the ansh-* skills and ANSH*.md docs from this repo into ~/.claude/skills.
# Safe to re-run. Existing real (non-symlink) copies are moved to ~/.claude/skills/.backup-<timestamp>/.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills"
BACKUP="$DEST/.backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$DEST"

link() {
  local src="$1" target="$DEST/$(basename "$1")"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mkdir -p "$BACKUP"
    mv "$target" "$BACKUP/"
    echo "backed up $(basename "$target") -> $BACKUP/"
  fi
  ln -sfn "$src" "$target"
  echo "linked $(basename "$src")"
}

for d in "$REPO"/skills/ansh-*; do link "$d"; done
for f in "$REPO"/ANSH*.md; do link "$f"; done
