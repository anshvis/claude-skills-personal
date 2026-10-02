---
name: pr-review
description: Review someone else's PR in a throwaway git worktree without disturbing your current branch or working tree. Given a PR number or URL, creates an isolated worktree, checks out the PR's head commit there, then runs /review-fresh (parallel fresh-eyes subagents vs dev) and /review (gstack structural pre-landing review) against it and merges the findings into one report. Use when the user says "/pr-review", "review this PR", or pastes a GitHub PR URL/number and asks for a review of someone else's branch. Leaves your real checkout untouched and offers to tear the worktree down at the end.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - Skill
  - AskUserQuestion
---

# /pr-review — Review a PR in an isolated worktree

Review another engineer's PR **without touching your current branch or working tree**. The whole
review happens inside a disposable git worktree under `.claude/worktrees/`, so your real checkout —
including any in-progress edits — is never disturbed.

The skill chains the two review skills already in this repo:

- **`/review-fresh`** — parallel, context-free subagents diff `origin/dev..HEAD` and review across
  three lenses (correctness, STYLE.md, tests). Requires a clean tree; rebases onto `origin/dev`.
- **`/review`** (gstack) — structural pre-landing review (SQL safety, trust boundaries, conditional
  side effects, etc.) of the current branch's diff vs base.

Because both skills key off the **persistent shell's working directory and current branch**, the
only trick is to `cd` into the worktree before invoking them. Everything else is bookkeeping.

## Input

A PR number (`11656`) or a GitHub URL (`https://github.com/vitalizecare/web-app/pull/11656` — the
`/changes`, `/files`, etc. suffix is fine). Extract the integer PR number from whatever is passed.

## Steps

### 1. Resolve PR + set up the worktree

Run from the **main repo root** (not an existing worktree). One Bash call:

```bash
set -euo pipefail
PR=<the integer PR number>
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

# PR metadata (also validates the PR exists / is reachable)
gh pr view "$PR" --json number,title,author,headRefName,baseRefName,additions,deletions,changedFiles

BR="pr-${PR}-review"
WT="$ROOT/.claude/worktrees/${BR}"

# Clean up any stale worktree/branch from a previous run of this skill
git worktree remove --force "$WT" 2>/dev/null || true
git branch -D "$BR" 2>/dev/null || true

# pull/N/head works for both same-repo and fork PRs
git fetch origin "pull/${PR}/head:${BR}"
git worktree add "$WT" "$BR"
echo "WORKTREE=$WT"
echo "BRANCH=$BR"
```

If `gh pr view` fails (PR not found / no access), surface the error and stop — don't guess.

### 2. Enter the worktree

```bash
cd <WORKTREE path from step 1>
```

A standalone `cd` to the absolute path keeps it as the persistent cwd for the skill invocations
that follow. **Do not** `cd` inside compound commands after this.

### 3. Run `/review-fresh` first (while the tree is pristine)

Invoke the **`/review-fresh`** skill now, before installing anything — its capture script refuses to
run on a dirty tree, and `bun install` can dirty the lockfile. Pass the PR title as the one-line
intent argument (it's the author's *claim*, not ground truth — `/review-fresh` treats it that way).

`/review-fresh` will fetch + rebase the worktree branch onto `origin/dev` and fan out three parallel
reviewers. If its script exits non-zero (dirty tree, rebase conflict), surface the stderr verbatim
and stop — do not try to repair the state yourself.

### 4. Install deps, then run `/review`

A fresh worktree has no `node_modules`, so cross-package type resolution falls back to the main repo.
Install first so the structural review reasons about the right code:

```bash
bun install
```

Then invoke the **`/review`** (gstack) skill. It reviews the current branch's diff vs base — which is
now this worktree's PR branch.

### 5. Merge findings into one report

Combine the `/review-fresh` and `/review` outputs into a single report:

- **PR header** — number, title, author, base branch, files/+/- changed.
- **Blockers** — anything either skill flagged as blocking, deduped (keep the strictest severity and
  note which skill/lens raised it).
- **Major / Minor findings** — grouped, deduped the same way. Preserve the lens label from
  `/review-fresh` (`correctness` / `style` / `tests`) and the category from `/review`.
- **Consensus vs single-source** — call out findings both skills independently raised (high
  confidence) vs ones only one surfaced.
- **Verdict** — `LGTM` / `LGTM with nits` / `Changes requested`, with a one-line rationale.

**Every finding MUST carry a precise location: `file path:line` (or a line range).** The user reads
this report and types the comments into GitHub themselves, so they need the exact line to find on
the PR's Files-changed tab. If a finding spans a hunk, give the range (`foo.tf:30-41`). Verify the
line numbers against the actual file/diff — don't approximate.

**These are SUGGESTIONS, not actions.** This skill never writes anything to GitHub or anywhere else
— it does not auto-generate, auto-post, or auto-apply review comments, and it does not draft text
"ready to paste" as if it were going to submit it. It hands the user a list of findings (with
locations); the user decides which ones to raise and writes the actual PR comments in their own
words. Do **not** edit any code — this is a review, not a fix.

### 6. Offer teardown

The worktree persists so the user can poke around. Offer to remove it:

```bash
git worktree remove --force "$WT" && git branch -D "$BR"
```

Ask before running it (use `AskUserQuestion`: keep the worktree, or tear it down). Mention the
worktree path either way so they can find it.

## Non-negotiables

- Never operate on or mutate the user's original checkout/branch — all git state changes happen
  inside the worktree.
- Never edit PR code or apply fixes; this skill only reads and reports.
- Never post, draft-for-submission, or auto-generate GitHub review comments. Findings are
  suggestions the user puts in themselves — output the list, never the action.
- Every finding must include a `file:line` location so the user can find it in the GitHub diff.
- If any setup step fails, surface the real error and stop rather than improvising repairs.
