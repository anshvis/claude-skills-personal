---
name: ansh-small-loop
description: "Take one scoped ticket or task to a merged, verified PR with no human in the loop. Use for /ansh-small-loop or any single bounded goal; project-scale goals go to /ansh-loop."
---

# /ansh-small-loop

**Goal:** one scoped ticket in, one merged and verified PR (or a small stack) out.

**Uses:** [`/ansh-plan`](../ansh-plan/SKILL.md), [`/ansh-cycle`](../ansh-cycle/SKILL.md),
[`/ansh-review`](../ansh-review/SKILL.md) (`goal`), [`/ansh-ship`](../ansh-ship/SKILL.md),
[`/ansh-pr-loop`](../ansh-pr-loop/SKILL.md), [`/ansh-loop`](../ansh-loop/SKILL.md), `effort-dial`,
`linear-sync`, [autonomy](../_shared/autonomy.md), [worktrees](../_shared/worktrees.md),
[tickets](../_shared/tickets.md), [stacking](../_shared/stacking.md),
[runtime](../_shared/runtime.md), [ledger](../_shared/ledger.md).

You conduct. Every piece of work runs in its own skill. Do it all in the goal's worktree
([worktrees](../_shared/worktrees.md)).

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
   - Quick: `/ansh-plan` writes one packet. One `/ansh-cycle`, then ship.
   - Standard: every step below.
   - Deep: every step below, with `deep` passed to each `/ansh-cycle`.
3. **Plan.** Run `/ansh-plan`. Go on once the packets exist and the challenge has run.
4. **Cycle each task** in dependency order: `/ansh-cycle <id>`. A BLOCKED task holds only what
   depends on it.
5. **Goal review.** Run `/ansh-review goal`. Failures go to `/ansh-plan` as new tasks, then back to
   step 4. The review enforces its own evaluation cap.
6. **Ship.** Run `/ansh-ship via=ansh-small-loop`. It opens each PR and starts `/ansh-pr-loop` on
   it, which drives it to merged, parked or awaiting approval.
7. **Wrap up.** Wait for every PR loop to end. Optionally run `linear-sync`. Log the final status
   and report.

## Edge cases

| case | do |
|---|---|
| Scope gate trips | Invoke `/ansh-loop` with the goal. Don't plan here. |
| A task comes back BLOCKED on a missing tool or credential | Keep working everything else. Stop only when nothing can move, naming the missing piece. |
| `/ansh-review goal` fails its second evaluation | Stop with BLOCKED and each evaluation's evidence (autonomy's stop conditions). |
| `/ansh-ship` skips a PR as not ready | Cycle its remaining tasks, then ship again. |

## Output

Status: **DONE** (every PR merged, verified at its head SHA, tickets linked),
**DONE_WITH_CONCERNS** (merged, open items listed), **PARKED** (everything mergeable merged; the
rest is parked or `awaiting_approval`), or **BLOCKED** (the cap or a missing piece; each attempt's
evidence).

Report, short: inferred ACs first, PR URLs and their state, parked items with the exact command I'd
run, agent defaults, and a link to `.ansh/decisions.md`.
