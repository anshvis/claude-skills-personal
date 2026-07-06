# /ansh — Ansh's curated skill arsenal

The authoritative, precise list of the skills I drive my work with. Everything under the
`/ansh-` prefix is **mine — edited, current, and trustworthy**. Skills without the prefix
(gstack, project skills) are dependencies these call by name; I keep `/ansh-` as the master set.

Architecture: the **Karpathy loop** — a planner decomposes, cheap specialists execute, an
evaluator scores against explicit criteria, and the loop revises until a quality bar is met.
Reference: generator → evaluator → revise, with role separation by model.

## The set

Effort ladder — thinking is most expensive where it has the most leverage: **planner > reviewer >
debug ≈ specialist.** Every level is **dial-driven**: `effort-dial` (run at `/ansh-loop` Step 0,
re-diagnosable per subtask) picks the Standard or Deep setting. The ordering holds at every tier;
the absolute level slides with the goal.

| Command | Role | Model / effort (Standard → Deep) | One-liner |
|---|---|---|---|
| **`/ansh-loop`** | Orchestrator (super) | Opus, conductor | The one command. Runs plan→execute→evaluate→revise→ship→resolve as a closed loop with explicit termination. |
| **`/ansh-plan`** | Planner | **Opus high → Opus high + extended thinking** (top) | Goal (Linear OR prose) → machine-readable subtask list, each stamped with model + effort + done-criteria + edge cases. Linear-optional. |
| **`/ansh-review`** | Evaluator | **Opus medium → Opus high + thinking** (one below planner) | Thinking role; never cheap. Scores output vs done-criteria, verifies flagged edge cases; decides in-session vs fresh-eyes vs cross-model. Returns PASS / REVISE / DEBUG. |
| **`/ansh-debug`** | Bug feedback loop | **Sonnet medium → Opus med/high** (only climbs when stuck) | Starts cheap — review/comments already handed it a lead. Root-causes, emits fix-subtasks, dispatches through `/ansh-task`. 3-strike rule = escalation trigger. |
| **`/ansh-task`** | Specialist | **Sonnet low → Sonnet medium** (cheap execution) | Executes ONE scoped subtask, self-verifies against its done-criteria, stops. Minimal ceremony. Kicks back if low-conviction. |
| **`/ansh-resolve`** | Outer loop | Sonnet/Opus, medium | Post-push: combs CI checks + bot/human review comments + Linear; triages; dispatches fixes; closes threads. |
| **`/ansh-save`** | Handoff / context-freeze | Sonnet, cheap | Stopping mid-stream: freezes the chat-only context (goal, done/not-done, repo state, decisions + why, landmines, next steps) into a resumable `.ansh/saves/<date>-<slug>.md`. A fresh session resumes cold from it. Not memory, not a plan. |

## The plan→task contract (self-contained packets + conviction gate)

The planner does the expensive thinking once and bakes it into disk so the cheap specialists need
almost nothing else. Working state lives in `.ansh/` (gitignored):

- **`.ansh/plan.md`** — the Opus-level high context (problem, architecture, decisions, DoD). The
  durable understanding; the orchestrator and evaluator read it, specialists usually don't need to.
- **`.ansh/plan.json`** — machine index: subtask ids, stamps, deps, status, packet path.
- **`.ansh/tasks/<id>.md`** — one **self-contained packet** per subtask: objective, context, exact
  files to change, gold-star references to mirror, all questions already answered, **edge cases /
  "watch out for" + tests to write** (the planner's edge-case thinking, pushed down per subtask),
  and testable done-criteria. A fresh Sonnet agent executes from this alone; `/ansh-review` checks
  the edge cases were handled.
- **`.ansh/discoveries.md`** — append-only log where specialists report things that need
  higher-level context. Raw signal for the planner; not a place anyone proposes solutions.

Two rules enforce the contract:
- **Conviction gate** — `/ansh-task` reads its packet and, if it lacks high conviction it can
  finish from the packet alone, does NOT start. It writes the gap to `.ansh/discoveries.md` and
  returns `NEEDS_REPLAN`.
- **No redirect by the cheap agent** — specialists never change direction. All direction and
  changes of direction are owned by `/ansh-plan` or the human. The planner folds discoveries into
  the durable context and reframes; genuine judgment calls escalate to the human via
  `AskUserQuestion`.

## The fresh-eyes rule (when to bring in an outside perspective)

The evaluator is *"a second agent, or the same agent with a different prompt context."* Pick depth
deliberately:

- **In-session** (default) — routine iteration, low blast radius. Cheap, has context.
- **`review-fresh`** — auth / payments / migrations / destructive / data-loss. Parallel Claude
  agents with NO chat history; kills tunnel-vision. Needs a clean tree (rebases onto `dev`).
- **`codex`** — large diff, or you want a genuinely orthogonal (cross-model) mind, or "P1 gate".
- Disagreement between in-session and fresh → escalate to cross-model to break the tie.

Bias: **iterate in-session; go fresh when the cost of being wrong is high or you're at a landing gate.**

## Glue skills (kept as-is, called by name — NOT forked)

These are cross-cutting helpers the `/ansh-` skills invoke. They're good as they are; do not
duplicate them under `/ansh-`:

- **`effort-dial`** — 5-axis tier diagnostic. `/ansh-plan` reuses it to stamp each subtask; `/ansh-loop` uses it to right-size the whole goal. (🟢 Quick→sonnet/low, 🟡 Standard→sonnet/med, 🔴 Deep→opus/high.)
- **`chill-describe`** — commit/PR style. Mandatory before every git/gh write.
- **`gold-star`** — hold work to a named reference implementation. Surface divergence in review.
- **`linear-sync`** — reconcile a ticket with reality after shipping.
- **`lightweight-sql`** — minimize DB load on any SQL/Drizzle diff.

## Relationship to /solve-linear-ticket

`/solve-linear-ticket` is the linear (non-looping) predecessor. Its genuinely useful parts —
fetching ticket context, clarifying scope, the In-Progress transition — now live in `/ansh-plan`,
which works **with or without** a Linear ticket. Reach for `/ansh-loop` as the canonical
end-to-end runner; `/solve-linear-ticket` stays available but isn't the default.

## How a session typically flows

```
/ansh-loop "REV-712: availability requests drop the timezone on overnight shifts"
  → effort-dial: Deep (touches shared scheduling + tz)
  → /ansh-plan       → 4 subtasks, T1-T2 Quick, T3-T4 Standard, T3 flagged review-fresh
  → /ansh-task T1    → done; /ansh-review T1 → PASS
  → /ansh-task T3    → done; /ansh-review T3 (review-fresh, tz/shared) → DEBUG (off-by-one at DST)
  → /ansh-debug      → root cause confirmed, writes T5 (fix + regression test), dispatches /ansh-task T5
  → /ansh-review T5  → PASS
  → whole-goal eval (codex, landing gate) → PASS
  → /ship (chill-describe) → PR up
  → /ansh-resolve    → Cursor flagged a nil case; /ansh-task fixes it; checks green; threads closed
  → DONE
```

## Keeping this list current

When I change how I work, I edit the `/ansh-` skill, then update its row here. This file is the
index; the SKILL.md files are the source of truth. New curated skill → add `/ansh-<name>`, add a
row. Retired → remove both.
