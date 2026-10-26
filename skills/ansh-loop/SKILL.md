---
name: ansh-loop
description: "Take a project (a Linear project or several parent tickets) to merged, verified PRs, running waves in dependency order. Use for /ansh-loop or project-scale goals; one scoped ticket goes to /ansh-small-loop."
---

# /ansh-loop

**Goal:** a whole project shipped as merged, verified PRs, with nothing waiting on me but parked
items.

**Uses:** `/ansh-plan`, `/ansh-task`, `/ansh-review`, `/ansh-debug`, `/ansh-pr-loop`,
`/ansh-small-loop` (rules, topology, linking), `chill-describe`, `gold-star`, `lightweight-sql`,
`linear-sync`, [autonomy](../_shared/autonomy.md), [verification](../_shared/verification.md),
[stacking](../_shared/stacking.md), [runtime](../_shared/runtime.md),
[ledger](../_shared/ledger.md), [principles](../_shared/principles.md).

You conduct. Every rule in `/ansh-small-loop`'s "Rules for the whole run" applies here too.

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
   rules. Each task runs `/ansh-task <id>`, then `/ansh-review <id>`, as one pipeline.
   - Enumerate in plain tool calls before calling Workflow. Scripts have no filesystem access.
     Pass the task and PR lists through `args` as real JSON, never a stringified blob.
   - One `pipeline()` per section (`prs[]` entry). Deps become sequential stages; independent
     tasks in a stage run in `parallel()`. Review of task N overlaps task N+1 where deps allow.
     Sections run concurrently and block only on real deps, never on another section's review.
   - Cap: ~15 agents per Workflow. Past that, one Workflow per wave in dependency order, and
     `log()` what's queued. Never truncate silently.
   - Isolation is for concurrency, not file sensitivity. Worktree-isolate a task only when it runs
     in the same `parallel()` as another task touching overlapping files, and nothing in the run
     depends on it. Run any task with an in-run dependent unisolated, in the shared directory,
     sequenced with its dependent. An isolated agent gets a fresh checkout and can't see another
     agent's changes, so its dependent would find the code missing.
   - A dependency across two Workflow calls reconciles through git, outside the script: commit
     and push the upstream branch, then cut the dependent from it per stacking and confirm the
     code is present. Never copy files across.
   - Hold back any task whose packet names an unlanded prerequisite (a blocking ticket, PR, or
     shared piece like a flag). Dispatch only what's unblocked. Report what you held back and why.
   - A Workflow finishing proves nothing. A task is done only on its `/ansh-review` PASS.
4. **Route verdicts** as in `/ansh-small-loop` step 4, with the same caps. Run NEEDS_REPLAN through
   `/ansh-plan` here in the conversation, never from inside a Workflow. `/ansh-debug`'s fix tasks
   join the next wave.
5. **Between waves:**
   - Check every `exit_criteria` item. One trips: don't start the next wave. Park what it touches
     if parking resolves it, else stop and report.
   - Report each PR's merge state: merged, waiting on #<n>, parked, or `awaiting_approval`, with
     the reason.
   - Check each linked ticket shows its PR and the parent picked up no section PRs.
   - Log the wave.
6. **Whole-goal evaluation.** `/ansh-review` against `acceptance_criteria[]` as written, not a
   paraphrase, re-running verification at the head SHA with a cross-model independent pass. Auth,
   payments, migrations or destructive work add the deep lane (autonomy). Failures become tasks
   through `/ansh-plan` and a new wave. Two evaluations at most.
7. **Ship.** Same topology and linking as `/ansh-small-loop`: integration branch, one section PR
   per `prs[]` entry into it, opened small-first, umbrella PR to `main`. Section PRs link their own
   tickets from `prs[].links`. Only the umbrella links the parent.
8. **Drive every PR to merge.** Right after each PR opens, run `/ansh-pr-loop <n> via=ansh-loop`.
   Don't wait for the rest of the wave. It merges under the merge rule in autonomy. When a PR
   merges, retarget and merge up the PRs stacked on it (stacking); their loops carry on. The
   umbrella runs the same way and merges last, once every section is in.

## Edge cases

| case | do |
|---|---|
| Plan incomplete or unchallenged | Run `/ansh-plan` to backfill. Don't stop, don't improvise criteria. |
| More sections than the fan-out cap | Split into waves in dependency order. Log what's deferred. |
| A task's packet names an unlanded prerequisite | Hold it back and report it. Dispatch the rest. |
| A dependent would be worktree-isolated | Don't. Run the chain unisolated and sequenced. |
| A dependency spans two Workflow calls | Reconcile through git per stacking. |
| Dependent task finds the dependency's code missing | Base or reconcile problem. Fix the base; never rebuild the dependency. |
| No Workflow API | Native delegation in dependency order, else serial. Say which ran. |
| A dependency PR is open or parked | Build, verify and drive dependents stacked on it. Post the waiting-on comment. They merge once it does. |
| A PR is `parked_at_merge` | Drive it to green; `/ansh-pr-loop` parks it per autonomy. Keep going. |
| Branch protection needs a non-author approval | Requested by `/ansh-pr-loop`. Report `awaiting_approval`, keep going. |
| An exit criterion trips | Stop new waves. Park or stop per step 5. |
| BLOCKED on a missing tool or credential | Work everything else. Stop when nothing can move, naming it. |
| A sub-skill has a question gate | Answer it per autonomy and log it. |
| Same verification fails after the cap and a replan | That task is BLOCKED with its evidence. Keep working tasks that don't depend on it. |

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
