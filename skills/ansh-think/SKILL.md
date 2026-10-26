---
name: ansh-think
description: "Structured problem-solving think-through — walks a problem down a fixed tree (problem → candidate solutions → each solution's shape, build tier, and reusability → cross-solution comparison → pros/cons → is-it-worth-it/lift-and-ROI → blast radius/infra considerations on the rest of the app, both positive and negative) before recommending a direction. Use when the user says \"/ansh-think\", asks to \"think through\" a problem, or wants a structured options-and-tradeoffs analysis rather than an immediate implementation. Produces a recommendation, not code — hand the chosen solution to /ansh-plan or /ansh-task to execute."
---

# /ansh-think — Structured problem think-through

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

A thinking skill, not an execution skill. It never edits code. It walks a problem down a fixed
tree so the comparison between options is explicit instead of vibes, then ends with a clear
recommendation the user can approve before anything gets planned or built.

Output is a structured writeup (in-chat is fine for a Quick/Standard-tier problem; use an
Artifact only if the user wants something shareable/durable). Don't skip levels of the tree to
save time — the tree *is* the value; a shortened version is just "list some options."

## The tree

### 1. What is the current problem
State it precisely: symptom, where it shows up, who/what is affected, and — if known — why it's
happening. If the "problem" is underspecified, say what's still unclear rather than guessing;
if it's genuinely the user's call, ask (don't invent a problem statement and run with it).

### 2. What are all the different solutions we can do to solve that problem
Generate a real option set — not one solution dressed as several. Aim for 2-4 genuinely distinct
approaches (different mechanisms, not variations on the same one). Include the "do nothing /
defer" option when it's plausible. For each candidate solution, work through the full sub-tree
before moving to the next:

**2.1 — What does the solution look like for this specific problem**
Concrete, not abstract: what would actually change (files, data model, flow, surface). Enough
detail that the next steps (comparison, lift) aren't hand-wavy.

**2.1.1 — What tier of change is this (reusability of code)**
Place it on a 1-3 scale and say why:
- **Tier 1 — bare minimum to work.** One-off, hardcoded, or manual; solves this instance of the
  problem without generalizing. Fine when the problem is narrow or one-time.
- **Tier 2 — some automation.** Reusable for the same class of problem with config/parameters,
  but still needs a human to trigger, tune, or extend it to a new case.
- **Tier 3 — full autonomous system.** Generalizes across cases without per-case intervention
  (e.g. a lattice/invalidation system, a scheduled self-healing pipeline).
Higher tier isn't automatically better — name the tier the problem actually warrants, and flag it
explicitly if a solution is over-built (Tier 3 for a Tier 1 problem) or under-built (Tier 1 papering
over a recurring problem that will resurface).

**2.2 — How do those solutions compare with each other**
Once all candidates have a 2.1, compare them directly against each other on the axes that
actually matter for *this* problem (not a generic checklist) — e.g. correctness, latency,
consistency with existing patterns, blast radius, time-to-ship.

**2.2.1 — What are the pros and cons of this solution practically**
Practical, not theoretical: pros/cons that would actually bite in this codebase/team, not
textbook tradeoffs that don't apply here.

**2.2.2 — Is this solution worth it**
A direct verdict given the pros/cons — worth pursuing, worth it only if X, or not worth it.
Don't leave this open; take a position.

**2.2.2.1 — What is the lift of the solution, and what's the ROI**
Size the lift: rough scope (files/systems touched), effort tier (reuse the `effort-dial`
vocabulary — Quick/Standard/Deep), and anything that would make the lift bigger than it looks
(migrations, cross-team dependencies, data backfill). Then weigh it against the payoff: what does
the lift actually buy (perf headroom, correctness, unblocking other work) versus what it costs
(build time, new surface to maintain, ops burden) — is this lift proportionate to the problem's
actual size and urgency, or is it over/under-investing relative to what's at stake? A cheap
solution to a small problem and an expensive solution to a large, recurring problem can both be
good ROI; a cheap solution that doesn't actually fix the problem, or an expensive one for a
problem that may not recur, are both bad ROI — say which this is.

**2.3 — Can this solution positively impact other features / infra in the app**
Look past the immediate problem: does this unlock, simplify, or de-risk anything else? Name the
specific feature/system, not "could help other things." Include infra considerations directly:
does it reduce load on shared infra (DB, cache, queues), retire a duplicated pattern elsewhere, or
give another system a reusable primitive it didn't have?

**2.4 — Can this solution negatively impact other features / infra in the app — blast radius**
Same, for downside: what could this break, complicate, or add debt to elsewhere? Include indirect
effects (perf, data shape, ownership boundaries), not just direct breakage. Cover infra
considerations explicitly: new tables/indices/crons/caches to operate, new failure modes
(staleness, invalidation gaps, thundering herds), and who owns keeping it correct over time. Grep
for callers/consumers if the claim needs evidence rather than assumption.

### 3. Recommendation
After all candidates have been through the sub-tree, close with:
- The recommended solution and the one-line reason it wins the comparison.
- What would change the recommendation (a fact, constraint, or preference you don't have yet).
- Explicit next step: hand off to `/ansh-plan` (if this becomes real work) or stop here if the
  ask was just to think it through.

## Calibration

- This is a thinking pass, not an essay contest — be as terse as the problem allows. A small
  problem might resolve 2-3 solutions in a few lines each; only expand where the tradeoff is
  genuinely close.
- If mid-tree you find there's really only one viable solution, say so explicitly (name why the
  others are non-starters) rather than padding out fake alternatives to hit a count.
- Ground claims in the actual codebase (grep, read call sites) wherever the comparison depends on
  facts you don't already know — don't speculate about "impact on other features" without
  checking.
- If the problem is genuinely ambiguous at step 1, use `AskUserQuestion` before generating
  solutions — a wrong problem statement invalidates everything below it.
