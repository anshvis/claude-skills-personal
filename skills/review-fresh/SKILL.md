---
name: review-fresh
description: Fresh-eyes review of the current branch's committed changes vs `main`, run by parallel subagents that have no access to this conversation's history. Rebases the branch onto `main` before reviewing — requires a clean working tree. Optionally pass a one-line description of intent as an argument.
---

# Review Fresh

Run a context-free review of the current branch's **committed changes vs `main`** by delegating to parallel subagents. Subagents only see the prompt you hand them, so the review is not biased by anything in this conversation.

> **⚠️ This command fetches `origin/main` and rebases your current branch onto it.** Rebase rewrites history. If your branch is already pushed, you'll need to force-push afterward. The script refuses to run if your working tree isn't clean — commit (or stash) all in-progress work first. Network access is required (the fetch will fail offline).
>
> **Why fetch + rebase against `origin/main`?** It guarantees `git diff origin/main..HEAD` shows only this branch's exclusive commits, against the current state of `main` on the remote. Without the fetch, a stale local `main` ref silently contaminates the diff with PRs that have already landed. Without the rebase, when sibling PRs are squash-merged into `main`, the original branch commits remain reachable from `HEAD` (but not from post-squash `main`), so they re-surface in the diff as if newly authored.

## Steps

1. **Capture diff, SHA, and intent.**

   Run a single Bash call from the repo root: `~/.claude/skills/review-fresh/capture.sh`

   The script:
   - Refuses to run if the working tree is dirty, you're on `main` itself, or you're on detached HEAD — and prints exactly what to fix on stderr.
   - Fetches `origin/main`, then rebases the current branch onto `origin/main`. If conflicts occur, the rebase is aborted and the user is told to resolve manually.
   - Captures `git diff origin/main..HEAD` (only this branch's commits, post-rebase) into a `mktemp` patch file.

   It prints three lines on stdout:

   ```
   PATCH=<absolute path to patch file>
   SHA=<HEAD sha after rebase>
   BYTES=<patch size in bytes>
   ```

   Parse those three values. **If the script exits non-zero, surface its stderr verbatim to the user** — it spells out exactly what they need to do (commit changes, switch branches, resolve conflicts) and stop. Do not try to fix the underlying state yourself. If `BYTES=0`, tell the user the branch has no commits beyond `main`, so there's nothing to review.

   Wrapping the capture in one script keeps the permission allowlist down to a single entry (`Bash(~/.claude/skills/review-fresh/capture.sh *)`).

   **Intent line.** If the user passed an argument to `/review-fresh`, capture it verbatim as the **intent line** — a short claim of what this change is meant to do. If no argument was passed, set intent to `(none provided)`. Do **not** infer intent from this conversation; that leaks exactly the bias a fresh-eyes review is meant to avoid.

2. **Launch three reviewers in parallel** — a single message with three `Agent` tool calls (`subagent_type: "general-purpose"`). Each prompt must be fully self-contained — no references to "the conversation" or "what we discussed".

   Pass each agent:
   - Absolute path to the diff file. Use it as a **change map**, not the only input — read full files, follow callers, and check related types/tests when it sharpens reasoning about the diff. Three lines of hunk context is rarely enough.
   - The HEAD SHA from step 1 (so all three reason about the same commit).
   - Absolute path to `STYLE.md` at the repo root.
   - The **intent line** from step 1, framed as the author's claim — not ground truth. Part of the reviewer's job is to assess whether the diff actually delivers on it. If intent is `(none provided)`, evaluate the diff on its own merits.
   - The lens (one of the three below).
   - The output rubric (see below).
   - Hard rule: do not edit code, run tests, or stage anything.

   The three lenses:

   **Reviewer A — Correctness & Risk.** Bugs, regressions, off-by-one errors, missing null/error handling, race conditions, data loss, security issues, broken invariants, unsafe types (`any`, unsafe casts), invalid states made representable.

   **Reviewer B — STYLE.md adherence.** Read `STYLE.md` first. Architectural drift, mixed responsibilities, wrong abstraction, Effect/async violations, React/component/data-fetching placement, function design (size, side effects, positional args), file structure, naming, imports. Every finding must cite a STYLE.md section.

   **Reviewer C — Tests & Verification.** Missing tests, weak assertions, tests at the wrong layer (per the test pyramid in STYLE.md §3), tests that would not catch the bug being fixed, gaps in edge cases. Comment on whether the diff is testable as written.

3. **Summarize.** Once all three return, merge findings using the rubric below. Collapse near-duplicates into one stronger finding, keeping the strictest severity. Preserve the `Lens` label so the user can see which reviewer flagged it.

## Output rubric

### Findings

List in priority order. Each finding:

- `Severity`: `blocker` | `major` | `minor`
- `Lens`: `correctness` | `style` | `tests`
- `Where`: file path and symbol or code area
- `Standard`: STYLE.md section, concrete bug class, or test gap
- `Problem`: what is wrong
- `Why it matters`: bug risk, maintainability risk, test gap, or reviewability issue
- `Actionable fix`: smallest concrete change that resolves it

Rules:

- Real findings only — no taste-based feedback.
- Style findings must cite a STYLE.md section.
- If two reviewers raised the same issue, keep the stronger framing and note both lenses.

### Proposed Fix Plan

Group related fixes, sequence in safe order, call out test additions, keep scope tight to this PR. Explicitly mark anything that should be a follow-up.

### If Clean

If no findings, say so explicitly. Then list:

- Residual risks
- Testing gaps
- Assumptions made while reviewing

## Non-negotiables

- Do not make code changes.
- Do not apply fixes, format files, or stage anything.
- Do not give taste-based feedback.
- Do not let parent-conversation context leak into subagent prompts.
