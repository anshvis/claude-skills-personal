---
name: ansh-loop
description: "Take a project (a Linear project or several parent tickets) to merged, verified PRs, running waves in dependency order. Use for /ansh-loop or project-scale goals; one scoped ticket goes to /ansh-small-loop."
---

# /ansh-loop

**Goal:** a whole project shipped as merged, verified PRs, with nothing waiting on me but parked
items.

**Uses:** [`/ansh-plan`](../ansh-plan/SKILL.md), [`/ansh-cycle`](../ansh-cycle/SKILL.md),
[`/ansh-debug`](../ansh-debug/SKILL.md), [`/ansh-review`](../ansh-review/SKILL.md) (`goal`),
[`/ansh-ship`](../ansh-ship/SKILL.md), [`/ansh-pr-loop`](../ansh-pr-loop/SKILL.md),
[`/ansh-small-loop`](../ansh-small-loop/SKILL.md) (scope gate), `linear-sync`,
[autonomy](../_shared/autonomy.md), [worktrees](../_shared/worktrees.md),
[tickets](../_shared/tickets.md), [stacking](../_shared/stacking.md),
[runtime](../_shared/runtime.md), [ledger](../_shared/ledger.md).

You conduct. Every piece of work runs in its own skill.

## Steps

1. **Inverse scope gate.** If none of `/ansh-small-loop`'s scope-gate triggers hold, this is one
   scoped ticket. Invoke `/ansh-small-loop` with it instead.
2. **Require a complete plan.** Read `.ansh/plan.json` and `.ansh/plan.md`. Run `/ansh-plan` when:
   - there's no plan;
   - `guardrails`, `acceptance_criteria` or `exit_criteria` are missing, or packets lack a
     Verification block (backfill);
   - most tasks fail readiness because the shape is unsettled (re-entry);
   - the plan was never challenged.

   Don't write the criteria yourself. Don't run `effort-dial` on the goal: the plan stamped each task.
3. **Run waves.** A wave is every task whose deps are done. Dispatch per runtime's orchestration
   rules. Each Workflow node runs `/ansh-cycle <id> node`.
   - Enumerate in plain tool calls before calling Workflow. Scripts have no filesystem access.
     Pass the task and PR lists through `args` as real JSON, never a stringified blob.
   - One `pipeline()` per section (`prs[]` entry). Deps become sequential stages; independent
     tasks in a stage run in `parallel()`. Sections run concurrently and block only on real deps.
   - Cap: ~15 agents per Workflow. Past that, one Workflow per wave in dependency order, and
     `log()` what's queued. Never truncate silently.
   - Isolation is for concurrency, not file sensitivity. Worktree-isolate a task only when it runs
     in the same `parallel()` as another task touching overlapping files, and nothing in the run
     depends on it. Run any task with an in-run dependent unisolated, in the shared directory,
     sequenced with its dependent. An isolated agent gets a fresh checkout and can't see another
     agent's changes, so its dependent would find the code missing.
   - A dependency across two Workflow calls reconciles through git, outside the script: run
     `/ansh-ship <PR id> push-only` on the upstream section, then the dependent's `/ansh-task` cuts
     from it per stacking. Never copy files across.
   - Hold back any task whose packet names an unlanded prerequisite (a blocking ticket, PR, or
     shared piece like a flag). Dispatch only what's unblocked. Report what you held back and why.
   - A Workflow finishing proves nothing. A task is done only on its `/ansh-cycle` PASS.
4. **Handed-up verdicts.** A node that returns HANDED_UP gets its `/ansh-plan` re-entry or
   `/ansh-debug` run here in the conversation. The task and any fix packets join the next wave.
5. **Between waves:**
   - Check every `exit_criteria` item. One trips: don't start the next wave. Park what it touches
     if parking resolves it, else stop and report.
   - Report each PR's merge state: merged, waiting on #<n>, parked, or `awaiting_approval`, with
     the reason.
   - Log the wave.
6. **Goal review.** Run `/ansh-review goal`. Failures go to `/ansh-plan` as new tasks and a new
   wave. The review enforces its own evaluation cap.
7. **Ship.** Run `/ansh-ship via=ansh-loop`. It opens every section PR small-first and the umbrella,
   and starts `/ansh-pr-loop` on each as it opens. Each loop merges, parks or holds its PR and
   merges up the stack when a dependency lands.
8. **Wrap up.** Wait for every PR loop to end. Optionally run `linear-sync`. Log the final status
   and report.

## Edge cases

| case | do |
|---|---|
| Plan incomplete or unchallenged | Run `/ansh-plan` to backfill. Don't stop, don't improvise criteria. |
| More sections than the fan-out cap | Split into waves in dependency order. Log what's deferred. |
| A task's packet names an unlanded prerequisite | Hold it back and report it. Dispatch the rest. |
| A dependent would be worktree-isolated | Don't. Run the chain unisolated and sequenced. |
| Dependent task finds the dependency's code missing | Base or reconcile problem. Fix the base per stacking; never rebuild the dependency. |
| No Workflow API | `/ansh-cycle` per task through native delegation in dependency order, else serially. Say which ran. |
| An exit criterion trips | Stop new waves. Park or stop per step 5. |
| A task returns BLOCKED (budget spent) | Keep working tasks that don't depend on it. |
| BLOCKED on a missing tool or credential | Work everything else. Stop when nothing can move, naming it. |
| `/ansh-review goal` fails its second evaluation | Stop with BLOCKED and each evaluation's evidence. |

## Output

Status:
- **DONE**: every PR merged, every AC verified at the head SHA, tickets linked.
- **DONE_WITH_CONCERNS**: merged, with open items listed against the ACs.
- **PARKED**: everything that could merge has merged. The rest is parked or `awaiting_approval`,
  each with what depends on it.
- **BLOCKED**: nothing else can move. Name the cap, exit criterion or missing piece, with evidence.

Report, short:
1. Inferred ACs.
2. Shipped PRs: URL, tickets, merge state.
3. Parked items: why, what depends on them, and the exact command or click I'd do.
4. Agent defaults (D-n), each with what I could say instead.
5. The exit criterion that ended the loop, if it wasn't full completion.
6. Link to `.ansh/decisions.md`.
