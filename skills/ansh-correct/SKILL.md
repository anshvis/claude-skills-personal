---
name: ansh-correct
description: Turn a mistake class that keeps recurring into a structural fix (architecture, types, lint or CI check, test) shipped as one small PR for Ansh to review; use /ansh-correct on demand or when a mistake class shows up a second time.
---

# /ansh-correct

**Goal:** make a repeated mistake impossible, so no agent needs a rule to avoid it.

**Uses:** [principles](../_shared/principles.md) (encode lessons in structure), [autonomy](../_shared/autonomy.md),
[ledger](../_shared/ledger.md), [runtime](../_shared/runtime.md), `/chill-describe`, `/ansh-review`,
`/ansh-resolve`, the scorer audit patterns (`~/agentic-workflow/scorer/src/audit/patterns.ts`) and
reports (`~/.agentic-workflow/scorer/reports/`).

Assume every contributor is an agent that sees only the files it opened, copies the nearest
example, and takes the shortest path that compiles. Make the change that looks right from one
file be right for the whole repo.

## Steps

1. **Collect.** Gather mistakes from:
   - ledger events with a `reason` (`missed-edge-case`, `wrong-surface`, `regression`, `lint`, `types`, `review-comment`, `human-correction`, ...) and every `escaped` event;
   - mistake classes `/ansh-review` and `/ansh-resolve` logged (review comments, CI failures);
   - the latest scorer report and its audit patterns: `restate`, `rigor`, `ci_conflicts`, `scope_surface`;
   - Ansh's corrections in the current session;
   - approved `correction` memories ([memory](../_shared/memory.md)) that keep being cited in REVISE.
   Filter to the target repo.
2. **Group into classes** by the ledger's `class` field, merging names that mean the same mistake. A class is one wrong move with one fix, for example "new RPC skips the
   tenant guard" or "copy changed in one editor, not the other two". A class counts once it has
   happened twice. Cite each occurrence (PR, commit, event `ts`, comment link).
3. **Skip what's covered.** Read the repo's agent instructions and existing lint/CI config. If a
   rule exists and nothing enforces it, that's a repeat: fix it structurally in this run.
4. **Pick the highest level that works**, in this order, and say why each higher one didn't:
   1. Architecture: one owner per piece of state, one supported way per task. Hide internals so the wrong import fails. Replace hand-synced lists with one source of truth. Delete the old way an agent would copy.
   2. Types: make the bad state unwritable.
   3. Lint or CI check whose error names the fix (the file, type or function to use). If the pattern is already common, fail only on new additions.
   4. Test that fails when the behavior breaks and survives a refactor.
   5. Docs or agent rules, only for judgment calls nothing can check.
5. **Prove it.** Check out a real past mistake from step 2 (the commit or a minimal replay of it)
   and show the new check fails on it with an error that names the fix. Then show it passes on
   current `main`. Run the same command locally that CI runs. No failing past case: the check is unproven, drop it.
6. **Ship one PR per class** in the target repo, off `main`, in a worktree:
   - the fix, the check, and one row in the rule table (see below);
   - description per `/chill-describe`: the class, its occurrences, the level picked, the proof output;
   - label `ansh-correct` and request Ansh as reviewer;
   - stop. Never merge it, never enable auto-merge.
7. **Log.** `ansh-log ansh-correct pr-opened DONE --pr N --reason <reason> --class <class>`. Once
   the check merges, the class's memory is stale: `/ansh-retro` lists it.

## Rule table

Keep a `rule -> what enforces it` table in the repo's agent instructions (`AGENTS.md` or the
file the repo uses). Change it only inside an `/ansh-correct` PR. Add the row with the fix. Drop
a row once its mistake can't happen any more (the check makes it unwritable).

## Edge cases

| case | do |
|---|---|
| Class seen once | Log it with `--class`. Don't fix yet. |
| Class is a skill or process problem, not code | Hand it to `/ansh-retro`. |
| No past mistake can be replayed | Write a minimal fixture that reproduces the class, cite the original. Still prove fail then pass. |
| Check would flag many existing call sites | Baseline them. Fail only on new additions. List the baseline count in the PR. |
| An exception is needed | Put it on the offending line with a reason. Ansh approves it in review. |
| A PR for this class is already open | Update that PR. Don't open a second one. |
| Fix needs an infra or CI-config change outside the repo | Park it per [autonomy](../_shared/autonomy.md). Report the exact change. |
| Fix touches shared lint or type config many teams use | Keep the rule scoped to the paths the class happened in. |
| `/ansh-pr-loop` picks up the PR | It sees the `ansh-correct` label and doesn't merge. |
| Higher level would be a large refactor | Ship the lint or test now. Note the architecture fix in the PR as a follow-up. |

## Output

`DONE` with one line per class: class, occurrences, level picked and why not higher, proof
(the failing past case), PR link. `NONE` when no class reached two. `BLOCKED` with the missing piece.
