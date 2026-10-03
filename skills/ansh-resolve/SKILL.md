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
  - mcp__claude_ai_Linear__get_issue
  - mcp__claude_ai_Linear__list_comments
  - mcp__claude_ai_Linear__save_comment
---

# /ansh-resolve — Outer loop (post-push cleanup)

The inner loop (`/ansh-plan → /ansh-task → /ansh-review`) gets a branch ready. Once you push, a
*second* round of signal arrives: CI checks, automated reviewers (Cursor and friends), human
reviewers, and Linear discussion. This skill is the Karpathy evaluate→revise loop applied to
that external feedback — comb it, triage it, fix it, prove it, close the threads.

**Worktree hygiene (pre-flight).** Resolve in the worktree that already tracks this PR's branch
(sibling of `web-app`, `bun install` run in it) — create one if none exists for this branch, reuse
it if one does. Do not resolve one PR's comments from a different branch's worktree; worktrees
isolate files/branches but NOT conversation context, so editing an unrelated branch from the wrong
worktree is how streams drift into each other. (See memory `feedback-worktree-and-session-per-task`.)

## Phase 1 — Gather all the feedback

```bash
gh pr view --json number,title,url,state,reviewDecision,statusCheckRollup,comments,reviews
gh pr checks                                                  # which checks pass/fail
gh api repos/{owner}/{repo}/pulls/<n>/comments                # inline review comments incl. bots
gh run view <run-id> --log-failed 2>/dev/null                 # failing GitHub Actions logs, if any
```

**Buildkite checks need `bk`, not `gh`.** Most CI here (`buildkite/database-pr-db-tests`,
`buildkite/white-check-mark-pr-checks`, `buildkite/robot-face-pr-review`, …) runs on Buildkite —
`gh run view` cannot read those logs. Source `~/.config/ansh-cli/env.sh`, then:

```bash
bk build list -p <pipeline> --branch <branch>    # find the build
bk build view <n> -p <pipeline> --log            # the REAL failing-step log (the actual error)
```

Note the difference between a `reviewDecision: CHANGES_REQUESTED` **required-review block** (e.g.
`clearpath-it` / `robot-face-pr-review` — resolved by pushing the fix so the bot re-reviews) and a
genuinely red check. A `bun install --frozen-lockfile` exit-1 is usually the Playwright postinstall
flake — verify locally (`bun install --frozen-lockfile`, exit 0 ⇒ retry, don't touch the lockfile).
Full arsenal + recipes: `~/.claude/skills/ANSH-cli-tools.md`.

If the branch traces to a Linear ticket, also pull its comments
(`mcp__claude_ai_Linear__list_comments`) — reviewers sometimes raise concerns there instead of on
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
- **NIT** — style/preference; apply if cheap, otherwise decline. Either way it gets an outward
  reply (see the disposition invariant below) — "otherwise note" means reply on the thread, not a
  private mental note.
- **WONTFIX / DISAGREE** — the comment is wrong or out of scope. You'll reply explaining why; do
  not silently ignore it.

**Every triaged comment maps to an outward disposition — no bucket is silent.** BLOCKER/FIX/BUG →
reply with what changed + resolve; NIT → reply (applied, or declined-because); WONTFIX → reply with
reasoning. There is no bucket whose correct outcome is "leave the thread with no response."

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

**Disposition invariant: no comment is left untraced.** Every review comment — human or bot,
inline thread or PR-level, in every triage bucket — must end this pass with a visible disposition
so anyone reading the PR can tell, comment-by-comment, which were answered and how. A comment is
"traced" when it has EITHER a reply that names its outcome OR a resolved thread (ideally both for
anything you fixed). Silence is never an acceptable end state — not for NITs, not for bot
comments, not for a comment you decided needs no code change (that decision itself is the reply).
Before declaring done, enumerate every comment and confirm each has its trace (see the coverage
check in Completion status).

- Re-run the checks that were failing (`gh pr checks` / push and watch). Don't reply "fixed" until
  the check is actually green. For a **flaky/infra** Buildkite failure (not a code issue), retry the
  step directly — `bk build retry <n> -p <pipeline>` — instead of pushing an empty commit.
- Commit per `/chill-describe` (short imperative, no co-author trailer, no emoji).
- Reply to each addressed thread with what changed (one line, link the commit). Resolve threads
  you've genuinely fixed. For WONTFIX, reply with the reasoning.
- **Replying is not resolving.** A `gh` reply alone leaves the thread OPEN. Once a finding is
  actually addressed — fixed+pushed, or intentionally declined with a wontfix reply that fully
  settles it — you MUST also resolve the review thread via the GitHub GraphQL `resolveReviewThread`
  mutation. Get the thread node ids from the PR's `reviewThreads` connection
  (`gh api graphql` on `pullRequest.reviewThreads` → each node's `id` + `isResolved`), then
  `mutation { resolveReviewThread(input: { threadId: "<id>" }) { thread { isResolved } } }`. Do
  this for bot reviewers (Cursor / clearpath-it) too, not just humans. NEVER resolve a thread whose
  concern you haven't touched — resolve only once the change is done or the wontfix reply genuinely
  closes it out.
- **Not every review is an inline thread.** A PR-level `CHANGES_REQUESTED` review (clearpath-it /
  a human "Request changes") often has NO `reviewThreads` node to resolve — its findings live in
  the review body / an issue comment. Clear it by (a) fixing every finding it enumerates and
  pushing, then (b) posting one reply comment that maps each finding → what changed (commit sha),
  so the record is explicit. Bot reviewers re-review the new commits and drop the block; for a
  human, re-request review. Either way the `reviewDecision` must not stay `CHANGES_REQUESTED` on a
  concern you've actually addressed.
- If the ticket needs a status note, `mcp__claude_ai_Linear__save_comment` — confirm with the user
  before posting anything outward-facing.

## STOP points

- Contentious triage (WONTFIX, architectural pushback, reviewer disagreement) → `AskUserQuestion`
  before acting.
- A reviewer comment that implies a scope change → route to `/ansh-plan`, don't absorb it silently.

## Completion status

The bar for **DONE** is not "I replied to the comments" — it is: every valid finding is actually
fixed and pushed (or explicitly declined with a settled wontfix), checks are green, AND no change
request stays open on a concern you addressed — every inline thread you touched is
`resolveReviewThread`-resolved and every PR-level `CHANGES_REQUESTED` you addressed is cleared
(`reviewDecision` no longer `CHANGES_REQUESTED`, or re-review requested). Verify this end-state
before declaring DONE — re-query `reviewThreads { isResolved }` and `reviewDecision`; don't trust
that a reply closed anything.

**Disposition coverage check (do this before DONE).** Re-fetch every comment on the PR and confirm
each has a disposition trace per the Phase 4 invariant — none left silent. One way to enumerate the
inline threads and spot untraced ones:

```bash
gh api graphql -f query='query { repository(owner:"<owner>",name:"<repo>") {
  pullRequest(number:<n>) { reviewThreads(first:100) { nodes {
    isResolved path line comments(first:20){ nodes { author{login} body } } } } } }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
    | {path,line,isResolved, lastAuthor:(.comments.nodes[-1].author.login),
       replied:([.comments.nodes[].author.login]|index("<you>")|type=="number")}'
```

A thread is untraced if it is unresolved AND you never replied (no reply and not resolved). Fix
every such thread (reply and/or resolve) before declaring DONE. Report the final tally: N comments,
all traced (X fixed+resolved, Y replied-only, Z wontfix).

End with **DONE** (all findings fixed, checks green, every change request resolved/cleared per
above), **DONE_WITH_CONCERNS** (some items deferred — list them, why, and which threads stay open),
or **BLOCKED** (can't proceed — e.g. CI infra failure; say what's needed).
