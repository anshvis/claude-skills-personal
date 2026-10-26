---
name: ansh-think
description: Walk a problem down a fixed tree (problem, candidate solutions, shape and build tier, comparison, pros and cons, worth it and ROI, blast radius) to a recommendation without writing code; use /ansh-think or when asked to think a problem through.
---

# /ansh-think

**Goal:** turn a problem into a compared set of options and one recommendation. No code.

**Uses:** [principles](../_shared/principles.md), [autonomy](../_shared/autonomy.md), [runtime](../_shared/runtime.md),
[ledger](../_shared/ledger.md), `/effort-dial` (effort tiers), `/ansh-plan` (handoff).

The tree is the value. Don't skip a level. A shortened tree is just a list of options.
Be as terse as the problem allows. Expand only where a tradeoff is close.

## Steps

1. **Problem.** State it precisely: symptom, where it shows up, who or what it affects, and why
   it happens if known. If it's underspecified, settle the fact by reading code, querying or
   reproducing. If it's a product call, state the reading most consistent with the PRD and
   current behavior as `D-n (agent default)` per [autonomy](../_shared/autonomy.md), and go on.
2. **Candidate solutions.** 2 to 4 genuinely distinct mechanisms, not variations of one. Include
   "do nothing or defer" when it's plausible. Run each one through the full sub-tree before the next:
   - **2.1 Shape.** What actually changes for this problem: files, data model, flow, surface.
     Concrete enough that comparison and lift aren't hand-wavy.
   - **2.1.1 Build tier.** Place it and say why:
     - Tier 1: bare minimum. One-off, hardcoded or manual. Fine for a narrow or one-time problem.
     - Tier 2: some automation. Reusable for the same class with config, still needs a person to trigger or extend.
     - Tier 3: autonomous system. Generalizes without per-case work.
     Name the tier the problem warrants. Flag over-built (Tier 3 for a Tier 1 problem) and
     under-built (Tier 1 papering over a recurring problem).
3. **Compare** the candidates against each other on the axes that matter for this problem (for
   example correctness, latency, fit with existing patterns, blast radius, time to ship), not a generic checklist.
   - **Pros and cons.** The ones that would bite in this codebase and team. Skip textbook tradeoffs that don't apply.
   - **Worth it.** Take a position: worth it, worth it only if X, or not worth it.
   - **Lift and ROI.** Size the lift: files and systems touched, effort tier (Quick, Standard,
     Deep), and what makes it bigger than it looks (migrations, cross-team work, backfills).
     Weigh it against the payoff. Say whether it's proportionate to the problem's size and urgency.
4. **Positive reach.** What else this unlocks, simplifies or de-risks. Name the feature or system.
   Include infra: less load on shared DB, cache or queues, a retired duplicate pattern, a reusable primitive.
5. **Blast radius.** What it could break, complicate or add debt to. Include indirect effects
   (perf, data shape, ownership) and infra: new tables, indices, crons or caches to run, new
   failure modes (staleness, invalidation gaps, thundering herds), and who keeps it correct.
   Search for callers and consumers. Prove the one fact safety depends on by running something.
6. **Recommend.** The winner and the one-line reason it wins. What fact or constraint would
   change the pick. The next step: hand to `/ansh-plan` if it becomes work, or stop.

**Prototype instead of speculating.** When a comparison turns on a fact that can be observed
(is the query slow, does the library support it, what does the API return, does the layout
fit), run a throwaway script, query or spike and cite the result. Keep spikes out of the working
tree's commits. Speculation is only for what can't be observed cheaply.

## Edge cases

| case | do |
|---|---|
| Only one solution is viable | Say so and name why the others are non-starters. Don't pad with fake options. |
| Problem statement is ambiguous | Settle facts by running something. Take an agent default on product calls and log it. |
| Claim about other features or infra | Ground it in a search or a read of the call sites. Don't speculate. |
| Two options are close | Prototype the deciding fact. Expand only that part of the tree. |
| Small problem | Resolve each option in a few lines. Keep every level. |
| Called inside a loop | Return the recommendation to the caller. Don't start `/ansh-plan` yourself. |

## Output

The tree as a structured writeup in chat (a doc only if asked for one), ending with
`Recommendation: <option>. Because <reason>. Would change if <fact>. Next: /ansh-plan | stop.`
Log `ansh-log ansh-think recommend DONE` and one `agent-default` event per default taken.
