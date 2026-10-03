---
name: ansh-pr-loop
description: Recurring PR babysitter — every ~5 minutes, combs the current PR for failing CI, human review comments, and bot review comments (Cursor/vitalize-agent), fixes what it can, re-runs CI, and dismisses a stuck BOT review once its concerns are verifiably addressed. Never dismisses a human review. Loops until CI is green and no review is blocking, then asks the user (never auto-decides) whether to merge. Use when the user says "/ansh-pr-loop", "babysit this PR", "watch this PR and get it mergeable", or wants a standing PR-mergeable-driver instead of a one-shot /ansh-resolve pass.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Agent
  - Skill
  - AskUserQuestion
  - ScheduleWakeup
  - Monitor
  - TaskList
  - PushNotification
  - mcp__claude_ai_Linear__get_issue
  - mcp__claude_ai_Linear__list_comments
  - mcp__claude_ai_Linear__save_comment
---

# /ansh-pr-loop — recurring drive-to-green PR loop

`/ansh-resolve` is one clean-up pass. This is that same pass, run on a ~5-minute cadence,
self-pacing until the PR is actually mergeable — then it stops and asks. It does not merge on
its own initiative, ever.

**Relationship to `/ansh-resolve`:** don't reimplement the comb/triage/dispatch/close logic here.
Each iteration's body is literally `/ansh-resolve`'s Phase 1–4, invoked via the Skill tool against
the PR. This skill only adds: the recurring cadence, the stuck-bot-review escalation
(dismiss-after-verified-fix), the loop's stop condition, and the final merge prompt.

**Worktree hygiene.** Same rule as `/ansh-resolve` — operate from the worktree that already
tracks this PR's branch. Don't drive a PR loop from an unrelated branch's worktree.
(See memory `feedback-worktree-and-session-per-task`.)

## Step 0 — identify the PR, once

If the user didn't name a PR number, resolve it from the current branch: `gh pr view --json
number,url,headRefName`. Confirm the number back to the user in your first status line so it's
unambiguous which PR is being babysat for the rest of the loop.

## Step 1 — each iteration's body

Invoke `/ansh-resolve` (via the Skill tool) scoped to this PR number. Let it gather, triage,
dispatch fixes through `/ansh-task`/`/ansh-debug`, re-run checks, and close threads exactly as
that skill defines. Do not duplicate its GraphQL/`gh`/`bk` recipes here — read
`~/.claude/skills/ansh-resolve/SKILL.md` for the mechanics if you need a reminder.

On top of `/ansh-resolve`'s own output, track two extra things per iteration:

- **Stuck-bot counter** — for each bot reviewer (Cursor `clearpath-it`, `vitalize-agent[bot]`,
  or similar) currently at `CHANGES_REQUESTED`, note whether this iteration's fixes genuinely
  addressed every finding that review enumerated (per `/ansh-resolve`'s Phase 4 disposition
  invariant — fixed+pushed, or a settled wontfix reply). If yes, but the bot hasn't cleared its
  own review to re-review the new commits, increment that bot's stuck-counter.
- **Human-blocker flag** — if a *human* reviewer's `CHANGES_REQUESTED` is not resolvable by a
  mechanical fix this iteration (needs a judgment call, disagreement, or scope question), set the
  human-blocker flag. This is a STOP condition (Step 3), not something to loop past silently.

## Step 2 — stuck-bot escalation: dismiss, never for humans

**Never dismiss a human review, under any condition.** A human `CHANGES_REQUESTED` is either
cleared by the human re-reviewing, or it's a Step 3 STOP for the user to resolve directly — this
skill does not have standing to override a person's review.

A **bot** review (Cursor bugbot, `vitalize-agent[bot]`, or similar) is fair game to dismiss, but
only when ALL of these hold:
1. Every finding in that bot's review has a Phase-4 disposition (fixed+pushed, or wontfix-replied)
   — verified, not assumed.
2. The fix has been pushed for at least one full iteration already (i.e. this is the *second*
   consecutive iteration this bot has stayed `CHANGES_REQUESTED` since the fix landed) — bots
   often just need one more scheduled run; don't dismiss on the same cycle the fix went out.
3. The stuck-counter for that bot is ≥2.

When all three hold, dismiss it:

```bash
gh api graphql -f query='query { repository(owner:"<owner>",name:"<repo>") {
  pullRequest(number:<n>) { reviews(last:20) { nodes { id author{login} state } } } } }'
# find the bot review's node id, then:
gh api graphql -f query='mutation { dismissPullRequestReview(input: {
  pullRequestReviewId: "<id>",
  message: "Findings addressed in <commit shas> — re-review pending, dismissing stale block."
}) { pullRequestReview { state } } }'
```

Post one PR comment naming which review was dismissed, why (commits that addressed it), and that
a human should double check if the bot re-flags anything on its next pass. This keeps the
dismissal auditable — it is not a silent override.

If any of the three conditions doesn't hold yet, don't dismiss — just let the loop continue; the
bot usually clears itself within a cycle or two once it re-scans the new commits.

## Step 3 — decide: continue, STOP, or done

After each iteration, check in this order:

1. **Human-blocker flag set** → STOP the loop (`ScheduleWakeup stop: true`), and surface the
   specific comment/thread to the user via `AskUserQuestion` or plain text — this needs a human
   call, not another cycle.
2. **CI green AND no bot or human review at `CHANGES_REQUESTED` AND no untraced comments** (the
   same bar as `/ansh-resolve`'s Completion status section) → converged. Go to Step 4.
3. **Otherwise** → still work to do. Continue (see Step 5's cadence).

**Safety cap:** if you've run 12 iterations (~1 hour at 5-minute cadence) without converging, stop
and report to the user what's still blocking rather than looping indefinitely — a PR that hasn't
converged in an hour of automated passes needs a human look, not more cycles.

## Step 4 — converged: ask about merge, never auto-merge

Once Step 3 condition 2 is met, stop the recurring loop (`ScheduleWakeup stop: true`) and ask:

```
AskUserQuestion:
  question: "PR #<n> is green and unblocked — merge it now?"
  options:
    - "Merge now" — squash-merge via `gh pr merge <n> --squash` (or the repo's usual merge method)
    - "Not yet" — leave it as is; you'll merge manually when ready
```

Never call `gh pr merge` without this confirmation, even if every check is green. Send a
`PushNotification` alongside the question if the user may be away — this is the payoff moment of
an unattended loop and worth surfacing even if they're not watching the terminal.

## Step 5 — cadence (dynamic self-pacing, same mechanism as `/loop`)

This is a session-scoped recurring loop, not a durable cron job — implement it the way `/loop`'s
dynamic mode does, not via `CronCreate` (fixed cadence, 7-day auto-expire, and no way to carry the
stuck-bot counters/human-blocker state between fires).

1. Run Step 1 now (don't wait for the first tick).
2. If CI is currently running, arm a `Monitor` on the build so a finish wakes the loop immediately
   instead of waiting out the fallback delay. Check `TaskList` first — don't double-arm across
   iterations.
3. Decide continue/STOP/done per Step 3.
4. If continuing, call `ScheduleWakeup` with `delaySeconds: 300` (the user asked for 5 minutes;
   this is a fixed cadence, not an idle-tick default) and `prompt` set to re-invoke this skill
   (`/ansh-pr-loop` — carry the PR number explicitly in the prompt so a fresh fire doesn't have to
   re-derive it) — same pattern as `/loop`'s dynamic mode, just always the same delay rather than
   observation-based pacing.
5. If a `<task-notification>` fires from the armed Monitor before the 5-minute deadline, treat it
   as this iteration's trigger — run Step 1 immediately, then re-arm per Step 3/4.
6. Briefly state, before calling `ScheduleWakeup` each time: current CI/review state, what changed
   this iteration, and what's still blocking. Keep it short — this runs a dozen times, not once.

## STOP points (in addition to the human-blocker flag in Step 3)

- A reviewer comment implying a scope change → route to `/ansh-plan`, don't absorb it silently
  (same rule as `/ansh-resolve`).
- Dismissing a bot review when any of the three Step 2 conditions is uncertain — don't guess;
  treat uncertainty as "not yet" and let another cycle pass instead.
- The safety cap (12 iterations) is hit.

## Completion status

End each Step 4/STOP with one of:
- **DONE** — converged, user answered the merge question (merged or declined).
- **STOPPED_FOR_HUMAN** — human-blocker flag, or safety cap hit; state exactly what's needed.
- **STOPPED_BY_USER** — user asked to cancel mid-loop.
