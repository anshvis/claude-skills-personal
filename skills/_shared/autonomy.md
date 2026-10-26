# Autonomy

Every `/ansh` skill runs without a human in the loop. My input is feature success: the numbered
acceptance criteria (ACs) in the PRD or TDD. Everything after that is yours.

## Never block on me

- **A fact gets settled by running something.** Behavior, timing, layout, output, perf, whether a
  query is slow: prototype it, query it, or test it. Don't ask.
- **A product or preference call gets a default.** Pick the option most consistent with the PRD
  and current behavior. Record it in `.ansh/decisions.md` as `D-n (agent default): <call>. You could
  tell me instead: <alternative>.` Keep going. The final report lists every agent default.
- **Missing ACs get inferred.** Derive them from the ticket and PRD, mark each `inferred`, and keep
  going. The final report lists inferred ACs first.
- **No `AskUserQuestion`, no "waiting for review" pauses, no "should I" messages.** If a skill
  you call has a question gate, answer it yourself per the rules above and log the answer.

## Never do (park instead)

These are irreversible, so the loop never does them. It does everything else around them.

- Run writes against prod data, or run a backfill outside a test or branch database.
- Deploy, or apply infra (Terraform, k8s, Argo, DNS).
- Force-push a shared branch. Rewrite merged history.
- Merge someone else's PR. Dismiss a human review.
- Message customers or post outside my own PRs, my tickets, and my DMs.
- Merge a PR whose merge itself destroys or rewrites data (a destructive migration or backfill
  that runs on deploy).

When work hits one of these, **park it**: open the PR, verify it fully, leave it unmerged with a
PR comment that says why, log a `parked` event, and keep working everything that doesn't depend on
it. Parked items go in the final report with the exact command or click I'd need to do.

## Merge rule

My own PRs squash-merge when all of these hold on the head SHA:
1. The verification contract passes (see [verification](verification.md)), with evidence.
2. CI is green.
3. `/ansh-review` returned PASS and no review blocks.
4. It isn't parked.

A high blast radius doesn't stop a merge. It adds the deep lane: a fresh-context review plus an
independent re-run of the verification, both at the head SHA. If branch protection needs a
non-author approval, request it from the CODEOWNERS and report `awaiting_approval`.

`/ansh-correct` PRs never merge from the loop. They request me as reviewer and stop.

## Stop conditions

Stop and report only when:
- the goal's exit check passes (done), or
- nothing left can move without a parked item, or
- the round budget runs out, with each attempt's evidence. A task gets 3 rounds (each REVISE,
  DEBUG or NEEDS_REPLAN is one), then one `/ansh-plan` re-entry that buys 3 more, then BLOCKED.
  The whole goal gets 2 evaluations. `plan.json` `termination` mirrors these numbers, or
- a tool or credential is missing and nothing else can move (name the missing piece).

A plateau isn't a stop. Change approach. Never relax a verification to declare success.

## Subagents

- Give each new round to a fresh subagent with the full scope: original packet, every later
  decision, and the previous agent's report and branch. Resume an old agent only when the work
  needs state that lives in it (its uncommitted changes, a dev server it runs).
- You own every subagent's output. Read its diff and write your own summary.
- A subagent never re-enters the loop or spawns its own reviewers unless its packet says so.

## Decision trail

Append every agent default, park, model escalation and skipped step to `.ansh/decisions.md`
(one line each: time, task, what, why). Log the same as ledger events. The final report links it.
