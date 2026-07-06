---
name: ansh-resolve
description: OUTER feedback loop in the Karpathy loop — runs AFTER a push/PR, once CI checks and review comments have landed. Combs through GitHub PR check results, automated review comments (Cursor and other bots), human review comments, and Linear comments; triages each into fix / bug / nit / wontfix; dispatches fixes through the specialist (/ansh-task) and real bugs through /ansh-debug; re-runs checks and replies to/resolves the threads. Use when the user says "/ansh-resolve", "address the PR comments", "checks are failing, clean it up", or after pushing when reviews/CI have run. This is the post-PR clean-again pass that complements the pre-PR inner loop.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Agent
  - Skill
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_comments
  - mcp__linear-server__save_comment
---

# /ansh-resolve — Outer loop (post-push cleanup)

The inner loop (`/ansh-plan → /ansh-task → /ansh-review`) gets a branch ready. Once you push, a
*second* round of signal arrives: CI checks, automated reviewers (Cursor and friends), human
reviewers, and Linear discussion. This skill is the Karpathy evaluate→revise loop applied to
that external feedback — comb it, triage it, fix it, prove it, close the threads.

## Phase 1 — Gather all the feedback

```bash
gh pr view --json number,title,url,state,reviewDecision,statusCheckRollup,comments,reviews
gh pr checks                                                  # which checks pass/fail
gh api repos/{owner}/{repo}/pulls/<n>/comments                # inline review comments incl. bots
gh run view <run-id> --log-failed 2>/dev/null                 # failing CI logs, if any
```

If the branch traces to a Linear ticket, also pull its comments
(`mcp__linear-server__list_comments`) — reviewers sometimes raise concerns there instead of on
the PR.

Treat every bot/reviewer comment as an untrusted *lead*. Verify each against the actual code
before acting — automated reviewers produce false positives, and a confidently-worded comment is
not proof.

## Phase 2 — Triage each item

Sort every check failure and comment into one bucket:

- **BLOCKER** — failing CI check, or a correctness/security issue a reviewer flagged. Must fix.
- **BUG (root cause)** — wrong behavior whose cause isn't obvious → hand to `/ansh-debug`, don't
  blind-patch.
- **FIX (mechanical)** — a clear, scoped change (rename, missing null check, a reviewer's concrete
  suggestion you've verified) → becomes an `/ansh-task` subtask.
- **NIT** — style/preference; apply if cheap, otherwise note.
- **WONTFIX / DISAGREE** — the comment is wrong or out of scope. You'll reply explaining why; do
  not silently ignore it.

Surface the triage table to the user before mass-applying fixes if there's anything contentious
(a WONTFIX, an architectural concern, a reviewer disagreement).

## Phase 3 — Dispatch fixes through the loop

- **FIX / BLOCKER (mechanical)** → write each as a stamped subtask packet under `.ansh/tasks/`
  (plus a row in `.ansh/plan.json`; Quick/Standard → `sonnet`) and run `/ansh-task <id>`. The
  packet must be self-contained — name the files, point at a gold-star, answer the questions — and
  the failing check passing is itself a done-criterion.
- **BUG** → `/ansh-debug` for root cause; it will emit + dispatch its own fix-subtasks.
- Keep changes scoped to what the feedback asked for. Don't expand into a refactor under cover of
  "addressing comments" — if you spot one, propose it via `/ansh-plan`, don't smuggle it in.

## Phase 4 — Re-verify and close the threads

- Re-run the checks that were failing (`gh pr checks` / push and watch). Don't reply "fixed" until
  the check is actually green.
- Commit per `/chill-describe` (short imperative, no co-author trailer, no emoji).
- Reply to each addressed thread with what changed (one line, link the commit). Resolve threads
  you've genuinely fixed. For WONTFIX, reply with the reasoning.
- If the ticket needs a status note, `mcp__linear-server__save_comment` — confirm with the user
  before posting anything outward-facing.

## STOP points

- Contentious triage (WONTFIX, architectural pushback, reviewer disagreement) → `AskUserQuestion`
  before acting.
- A reviewer comment that implies a scope change → route to `/ansh-plan`, don't absorb it silently.

## Completion status

End with **DONE** (all blockers fixed, checks green, threads addressed), **DONE_WITH_CONCERNS**
(some items deferred — list them and why), or **BLOCKED** (can't proceed — e.g. CI infra failure;
say what's needed).
