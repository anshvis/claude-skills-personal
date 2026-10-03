#!/usr/bin/env bash
# Capture the current branch's committed changes vs `origin/main` for
# /review-fresh.
#
# REQUIRES a clean working tree and network access. The script fetches the
# latest `origin/main`, REBASES the current branch onto it, and diffs against
# `origin/main` — so a stale local `main` ref can't contaminate the review.
# Rebase rewrites history; if the branch is already pushed, expect to
# force-push afterward.
#
# Refuses to run when:
#   - working tree has staged or unstaged changes (commit or stash first)
#   - currently on `main` itself, or on detached HEAD
#   - rebase onto `origin/main` hits conflicts (resolve manually, then re-run)
#   - `git fetch` fails (typically: no network, or no `origin` remote)
#
# Prints three lines on stdout:
#   PATCH=<absolute path to patch file>
#   SHA=<HEAD sha after rebase>
#   BYTES=<patch size in bytes; 0 means this branch == origin/main>
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
  {
    echo "review-fresh: working tree is not clean."
    echo "Commit (or stash) all changes first, then re-run /review-fresh."
    echo
    echo "git status --short:"
    git status --short
  } >&2
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "HEAD" ]; then
  echo "review-fresh: refuse to run on '$BRANCH' — need a feature branch." >&2
  exit 1
fi

git fetch origin main

if ! git rebase origin/main; then
  git rebase --abort 2>/dev/null || true
  {
    echo "review-fresh: rebase onto 'origin/main' hit conflicts and was aborted."
    echo "Resolve manually:"
    echo "  git rebase origin/main"
    echo "  # fix conflicts, git add, git rebase --continue"
    echo "Then re-run /review-fresh."
  } >&2
  exit 1
fi

PATCH=$(mktemp -t review-fresh.XXXXXX.patch)
git diff origin/main..HEAD > "$PATCH"

SHA=$(git rev-parse HEAD)
BYTES=$(wc -c < "$PATCH" | tr -d ' ')

printf 'PATCH=%s\n' "$PATCH"
printf 'SHA=%s\n'   "$SHA"
printf 'BYTES=%s\n' "$BYTES"
