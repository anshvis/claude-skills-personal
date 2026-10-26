---
name: ansh-small-loop
description: "Take one scoped ticket or task to a merged, verified PR with no human in the loop. Use for /ansh-small-loop or any single bounded goal; project-scale goals go to /ansh-loop."
---

# /ansh-small-loop

**Goal:** one scoped ticket in, one merged and verified PR (or a small stack) out.

**Uses:** `/ansh-plan`, `/ansh-task`, `/ansh-review`, `/ansh-debug`, `/ansh-pr-loop`, `/ansh-loop`,
`effort-dial`, `chill-describe`, `gold-star`, `lightweight-sql`, `linear-sync`,
[autonomy](../_shared/autonomy.md), [verification](../_shared/verification.md),
[stacking](../_shared/stacking.md), [runtime](../_shared/runtime.md),
[ledger](../_shared/ledger.md), [principles](../_shared/principles.md).

You conduct. Planning, code and review each run in their own skill.

## Steps

1. **Scope gate.** Run it before anything else. Hand the goal to `/ansh-loop` if any one holds:
   - It's a Linear project, spans several parent tickets, or reads as an initiative.
   - Decomposing it needs a call that shapes everything downstream: a new data model, a new
     subsystem or service boundary, a cross-team dependency, a build-vs-buy or sequencing call
     with no obvious answer.
   - It's genuinely multi-week, not a few PRs.
   - Most tasks would fail `/ansh-plan` readiness because the shape isn't settled, not for lack of
     research.

   Deep on the effort dial is difficulty, not scale. A gnarly bug or a tricky migration stays here.
2. **Right-size.** Run `effort-dial` on the whole goal. State the tier in one line and log it.
   - Quick: `/ansh-plan` writes one packet. One `/ansh-task`, one `/ansh-review`, then ship.
   - Standard: the full loop below.
   - Deep: the full loop, with `/ansh-review` biased to fresh-context and cross-model eyes.
3. **Plan.** Run `/ansh-plan`. Go on once the packets exist and the challenge has run.
4. **Task and review, per task in dependency order.** Each round is a fresh subagent (autonomy).
   - `/ansh-task <id>`. NEEDS_REPLAN: `/ansh-plan` re-entry, then dispatch the reframed task again.
   - `/ansh-review <id>` on its result.
     - PASS: take the next task. The task already committed what review judged.
     - REVISE: send the blockers to `/ansh-task`, or to `/ansh-plan` when the finding is
       architectural.
     - DEBUG: `/ansh-debug` finds the root cause and writes fix tasks into the plan. They rejoin
       this step.
   - Rounds follow the budget in autonomy's stop conditions: 3, one replan, 3 more, then BLOCKED
     with each attempt's evidence.
5. **Whole-goal evaluation.** `/ansh-review` against `definition_of_done` and every AC, re-running
   verification at the head SHA, with a cross-model independent pass. Auth, payments, migrations,
   destructive work or a high blast radius add the deep lane (autonomy). Failures become new tasks
   through `/ansh-plan` and go back to step 4. Two evaluations at most.
6. **Ship.** Follow the topology and linking rules below and stacking for every base. Run
   `chill-describe` before every commit, `gh pr create` and `gh pr edit --body`. If a PR template
   gets injected, overwrite it with the chill-describe body. Then check each linked ticket shows the
   PR and the parent doesn't (unless linked by rule). Fix gaps with `save_issue` links and say so.
7. **Drive to merge.** Right after each PR opens, run `/ansh-pr-loop <n> via=ansh-small-loop`.
   It merges under the merge rule in autonomy. When a dependency merges, retarget and merge up the
   stack (stacking). The umbrella merges last, under the same rule.
8. **Wrap up.** Optionally run `linear-sync`. Log the final status.

## Rules for the whole run

- **Worktrees and commits** follow [worktrees](../_shared/worktrees.md).
- **Topology.** A single-PR goal targets `main` and `Closes` its ticket. Otherwise the ticket's
  branch is a long-lived integration branch with one umbrella PR to `main`, opened once, titled
  after the parent and linked `Closes <PARENT>`. The work lands as small section PRs into the
  integration branch, small-first in dependency order. A section PR doesn't have to ship against
  `main` alone. Size test: more than ~8-10 files or mixed layers means split it.
- **Branches, PR links and ticket status** follow [tickets](../_shared/tickets.md).
- **`.ansh/` stays local.** Use the local exclude from `/ansh-plan` step 6, never the tracked
  `.gitignore`. Same for any agent scratch.

## Edge cases

| case | do |
|---|---|
| Scope gate trips | Invoke `/ansh-loop` with the goal. Don't plan here. |
| A task stamps Deep | Split it through `/ansh-plan` before dispatch. If the planner returned it as irreducible (DONE_WITH_CONCERNS), run it on Astra with the deep lane. |
| `/ansh-task` returns BLOCKED on a missing dependency or base | Fix the base per stacking, then dispatch again. Never rebuild the dependency. |
| BLOCKED on a missing tool or credential | Keep working everything else. Stop only when nothing can move, naming the missing piece. |
| A sub-skill has a question gate | Answer it per autonomy and log the answer. |
| Diff touches SQL or Drizzle | The specialist applies `lightweight-sql`. |
| A `gold-star` reference is named | Packets point at it; review reports divergence. |
| Task or PR is `parked_at_merge` | Drive it to green; `/ansh-pr-loop` parks it per autonomy. Keep going on everything that doesn't depend on it. |
| A dependency is open or parked | Build and verify dependents stacked on it. They merge only after it does. |
| Branch protection needs a non-author approval | `/ansh-pr-loop` requests it. Report `awaiting_approval`. |
| A tool wants to rebase or force-push a shared branch | Don't. Follow stacking's merge-only rule. |
| Verification plateaus | Change approach. Never relax a check to pass. |

## Output

Status: **DONE** (every PR merged, verified at its head SHA, tickets linked),
**DONE_WITH_CONCERNS** (merged, open items listed), **PARKED** (everything mergeable merged; the
rest is parked or `awaiting_approval`), or **BLOCKED** (the cap or a missing piece; each attempt's
evidence).

Report, short: inferred ACs first, PR URLs and their state, parked items with the exact command I'd
run, agent defaults, and a link to `.ansh/decisions.md`.
