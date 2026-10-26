---
name: ansh-cycle
description: "Drive one task packet to a review PASS: dispatch /ansh-task, judge it with /ansh-review task, and route every verdict within the round budget. Use for /ansh-cycle <task-id>, or per task from /ansh-small-loop and /ansh-loop."
---

# /ansh-cycle

**Goal:** one task id in, a reviewed PASS at a committed head SHA out, or BLOCKED with every
round's evidence.

**Uses:** [`/ansh-task`](../ansh-task/SKILL.md), [`/ansh-review`](../ansh-review/SKILL.md),
[`/ansh-debug`](../ansh-debug/SKILL.md), [`/ansh-plan`](../ansh-plan/SKILL.md),
[autonomy](../_shared/autonomy.md), [runtime](../_shared/runtime.md),
[stacking](../_shared/stacking.md), [ledger](../_shared/ledger.md) (`../_shared/ansh-log`), [memory](../_shared/memory.md),
[plan.json](../ansh-plan/references/plan-json.md).

Arguments: `/ansh-cycle <task-id> [deep] [node]`. `deep` comes from a Deep conductor tier. `node`
means it runs inside a Workflow script (see step 5).

## Steps

1. **Load.** Read the task's row in `.ansh/plan.json` and its packet. `status: done` already:
   return PASS with its SHA. Read `rounds` and `replans` so the budget survives a resume.
2. **Size check.** A Deep stamp goes to `/ansh-plan` re-entry to split before dispatch. If the
   planner returned it as irreducible (DONE_WITH_CONCERNS naming it), run it on Astra and treat
   it as `deep`.
3. **Do.** Dispatch `/ansh-task <id>` in a fresh subagent for every round, briefed per autonomy's
   [subagent rules](../_shared/autonomy.md#subagents), with the model and effort from the stamp
   (runtime).
   - DONE: go to step 4.
   - NEEDS_REPLAN: a round. Route to `/ansh-plan` re-entry (step 5), then dispatch again.
   - BLOCKED on a base or missing dependency: fix the base per stacking and dispatch again. Not a
     round. Never rebuild the dependency.
   - BLOCKED on a tool or credential: return BLOCKED, naming it.
4. **Judge.** Run `/ansh-review task <id>` at the task's head SHA. On `deep`, ask it for the deep
   lane: fresh-context and cross-model eyes.
5. **Route the verdict.**
   - PASS: set `status: done`. Log and return PASS with the SHA. An approach that worked and wasn't
     in memory or the packet's gold-star becomes a `workflow` draft with `--task` per
     [memory](../_shared/memory.md).
   - REVISE with `ACT_ON` routed to `ansh-task`: a round. Back to step 3 with the findings.
   - REVISE routed to `ansh-plan` (architectural, or `PLAN_GAP: large`): a round. `/ansh-plan`
     re-entry, then step 3.
   - DEBUG: a round. Run `/ansh-debug` with `BUGS`. Run `/ansh-cycle` on each fix packet it writes
     (each has its own budget), then review this task again (step 4). If it returns NEEDS_REPLAN,
     treat it as a plan re-entry.
   - `node`: never run `/ansh-plan` or `/ansh-debug` inside a Workflow. Return the verdict, the
     findings and the round count to the conductor, which runs them in the conversation and
     re-runs `/ansh-cycle` in the next wave.
6. **Budget.** Count rounds per autonomy's stop conditions and write `rounds` and `replans` to
   `plan.json` after each one. At the round cap, one `/ansh-plan` re-entry buys the second
   allowance. When that runs out, log BLOCKED and return BLOCKED with each round's evidence. A
   plateau means a new approach through re-entry, never a relaxed check (autonomy).
7. **Log** each round: `ansh-log ansh-cycle round <PASS|REVISE|DEBUG|NEEDS_REPLAN|BLOCKED> --task <id>
   --attempt <n> --reason <reason>`. A REVISE class seen for the second time in this goal is saved
   as a `correction` candidate per [memory](../_shared/memory.md).

## Edge cases

| case | do |
|---|---|
| Task's packet names an unlanded prerequisite | Return BLOCKED naming it. The conductor holds it back. |
| `/ansh-review` returns BLOCKED (no fresh context for the deep lane) | Return BLOCKED with what's needed. |
| A model looks too weak after a failed round | Escalate per runtime and log it to `.ansh/decisions.md`. |
| Task is `parked_at_merge` | Drive it to PASS like any other. Parking happens at merge. |
| A resumed run finds `status: needs_replan` | Run `/ansh-plan` re-entry first. It's already counted. |

## Output

```
CYCLE: PASS | BLOCKED | HANDED_UP
TASK: <id>   SHA: <head sha>   ROUNDS: <n> (replans: <n>)
HISTORY: <round: verdict, reason, evidence path> ...
```

- **PASS**: `/ansh-review` passed the task at that SHA. The commit is ready for `/ansh-ship`.
- **BLOCKED**: budget spent, a missing tool, or no fresh context. Each round's evidence.
- **HANDED_UP**: `node` mode only. The conductor runs the replan or debug.
