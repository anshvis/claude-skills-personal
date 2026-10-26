---
name: ansh-retro
description: Read the /ansh iteration ledger and stage small, measured edits to the /ansh skills themselves for Ansh to approve; use /ansh-retro weekly or on demand.
---

# /ansh-retro

**Goal:** cut what doesn't change outcomes and fix what keeps costing rounds, with the numbers behind each edit.

**Uses:** [ledger](../_shared/ledger.md), [autonomy](../_shared/autonomy.md), [principles](../_shared/principles.md),
[runtime](../_shared/runtime.md), [memory](../_shared/memory.md) (`../_shared/ansh-memory`), `/ansh-correct`, `/ansh-verify`, `/chill-describe`, the scorer
reports (`~/.agentic-workflow/scorer/reports/<date>.md`).

## Steps

1. **Window.** Default: since the last retro report in `~/.agentic-workflow/ansh/retros/`, else
   the last 7 days. Read `~/.agentic-workflow/ansh/events.jsonl` (or `ANSH_LEDGER`) for that
   window, plus the newest scorer report inside it when one exists.
2. **Check the last retro.** Each earlier proposal named a metric and a direction. Recompute it.
   Report `moved`, `flat` or `worse`. A merged edit that made its metric worse gets a revert proposal.
3. **Compute the metrics.** Group by task, goal, milestone and surface. Show `n` next to every
   number. Each metric needs at least 5 events behind it to drive a proposal.

   | Metric | From |
   |---|---|
   | Rounds to PASS per task | `/ansh-review` verdicts per `task` until the first PASS. Median, p90, max. |
   | Revise reasons | `reason` counts on `REVISE`, `DEBUG` and `/ansh-resolve` fix events. |
   | Phases that never changed the outcome | `skill` + `phase` whose verdict was always PASS across the window. Candidates to cut or gate on risk. |
   | Escape rate by surface | `escaped` per `merged`, split by the four `surface` values (aliases folded in). Track milestones with a ui half separately (it decides when to commit the feature map, see `/ansh-verify`). |
   | Misclassification rate | `wrong-surface` events per reviewed milestone. |
   | Agent defaults overridden | `agent-default` events later followed by `human-correction` on the same goal or ids. |
   | Parked | `parked` count, by why. |
   | Iterations per milestone kind | `attempt` per milestone, split by `surface`. |

   Cross-check with the scorer: user messages per merged PR, corrections, and the audit pattern
   counts (`restate`, `rigor`, `ci_conflicts`, `scope_surface`).
4. **Route each finding.**
   - The skill text or flow causes it (a phase that never fires, a gate that keeps missing the same thing, a default Ansh keeps overriding): propose a skill edit here.
   - Code in a product repo causes it (a lint, type or test gap): hand it to `/ansh-correct`.
   - A one-off: drop it.
5. **Write proposals.** Each one: the edit, the file, the numbers behind it, the metric it should
   move and in which direction. Prefer deletion. Prefer gating a phase on risk over adding a new one.
   An edit must keep every shared doc the single owner of its rule.
6. **Stage, don't apply.** In `~/personal-skills`, add a worktree off `origin/main` at
   `../personal-skills-retro-<date>` on a local branch `ansh-retro-<date>`. Never switch or
   edit the live checkout. One small commit per proposal, written per `/chill-describe`. Don't
   push the branch. Stop and report. When Ansh says go, rebase it onto `origin/main`, push straight
   to `main` (this repo doesn't use PRs), and remove the worktree.
7. **Memory queue.** Work `ansh-memory pending` per [memory](../_shared/memory.md#review):
   approve, reject or correct each candidate. Save a `workflow` or `convention` memory for each
   repo-level pattern the metrics show. List stale memories, including classes `/ansh-correct`
   turned into checks. This is local, so it doesn't wait for Ansh.
8. **Save and log.** Write the report to `~/.agentic-workflow/ansh/retros/<date>.md`. Log
   `ansh-log ansh-retro report DONE --note "<k> proposals"`.

## Edge cases

| case | do |
|---|---|
| Ledger missing or empty for the window | Report `NONE` with the event count. Nothing staged. |
| Fewer than 5 events behind a metric | Show it as `low-n`. No proposal from it. |
| Malformed ledger lines | Skip them, count them, report the count. |
| Scorer report missing | Use the ledger alone. Say so. |
| A phase looks redundant but guards an irreversible step | Don't cut it. Propose a risk gate instead, or nothing. |
| An earlier retro branch is still unapplied | Add new commits to it. Don't start a second one. |
| Finding is a code mistake class | Hand it to `/ansh-correct`. Not this branch. |
| Proposal would restate a shared doc inside a skill | Edit the shared doc instead, and link to it. |
| Live checkout has uncommitted edits or another branch | Leave it alone. The worktree is off `origin/main`. |
| Visible escape rate dropped across two retros since the map was set up | Propose committing the feature map, per `/ansh-verify`. |

## Output

A short report:

```
Window: <from> -> <to> | events: <n> | scorer: <report or none>
Last retro: <proposal -> metric moved | flat | worse>
Metrics: <table, n beside every number>
Proposals: <edit> | <file> | <numbers> | should move <metric> <direction>
Handed to /ansh-correct: <class, count>
Memory: <approved n, rejected n, corrected n, stale ids>
Staged: <worktree path, commit count>
```

Status: `DONE` with the staged branch, `NONE` with why, or `BLOCKED` with the missing piece.
