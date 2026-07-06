---
name: ansh-review
description: EVALUATOR role in the Karpathy loop. Runs at Opus medium/high effort with extended thinking — a thinking role, one step below the planner and well above the cheap specialist. Scores a specialist's output against the subtask's explicit done-criteria, verifies the planner's flagged edge cases were handled, finds gaps/bugs/risks, and decides whether to evaluate in-session or pull in FRESH/CROSS-MODEL eyes. This is the "second agent that evaluates against defined criteria" from the Karpathy loop — it returns structured PASS/FAIL + findings that /ansh-loop uses to decide revise-or-ship. Use when the user says "/ansh-review", after a /ansh-task completes, or when /ansh-loop reaches the evaluation step. Routes to in-session review, review-fresh (no-history parallel agents), or codex (cross-model) per a risk rule.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - Skill
---

# /ansh-review — Evaluator

The evaluator closes the Karpathy loop. It does not edit code; it judges work against the bar
the planner set, then tells the orchestrator one of: **ship it**, **revise these specific
things**, or **this is a bug — hand to `/ansh-debug`**.

**Effort (dial-driven — a thinking role, always one step below the planner and above the
specialist):**
- 🟡 Standard goal/subtask → Opus, medium effort.
- 🔴 Deep / high-blast-radius (auth, payments, migrations, destructive) → Opus, high + extended
  thinking. Match the depth to what the dial said about this work.

Evaluation is where subtle bugs and missed edge cases get caught; it's deliberately more expensive
than `/ansh-task` (cheap execution) or `/ansh-debug` (more procedural root-causing). Even at the
Standard setting, **don't run review on a cheap model** — a shallow evaluator is worse than none,
because it manufactures false confidence.

## Phase 1 — Score against done-criteria (always)

Read the subtask's done-criteria from its packet `.ansh/tasks/<id>.md` (index: `.ansh/plan.json`),
or the criteria you were handed.
For each criterion, return a verdict with evidence:

```
T3 "endpoint returns 422 on missing tenantId"  → PASS (ran curl, got 422 + body {error:...})
T3 "unit test added"                            → FAIL (no test touches this path)
```

Do not pass a criterion on vibes. If you claim "this is safe", cite the line that proves it.
A criterion with no evidence is a FAIL.

**Layering gate — repos vs facades (when the diff adds/edits a repo, facade, service, projector,
resolver, or business-logic function).** The load-bearing rule: **a repo is anything that touches
the DB (Drizzle/SQL); a facade/service is where business logic lives.** They must not blur. Verify
against `.agents/skills/best-practices/references/services-and-layers.md` (§"Repos Are Data-Oriented",
§"Facade Responsibilities", §"Review Smells") + STYLE.md §13. Concretely:

- **Repos** may only: run Drizzle/SQL, find/insert/update/delete, shape query-row types, decode
  self-owned rows, short-circuit empty inputs, translate a table-owned DB constraint into a domain
  tagged error. Method names are data-access (`findById`, `insert`, `setActive`, …).
- **Repos must NOT** (each is a **BLOCKER**): validate auth/permissions; make business decisions or
  branch on user intent/loaded state; tag rows with domain meaning (`source: "rule"|"override"`);
  merge across tables into caller-facing maps; open orchestration transactions; call a foreign repo
  or any facade; publish events/notifications/invalidations; return transport errors.
- **Facades/services** own the business logic: validation needing loaded data, branching/decisions,
  typed domain errors, transaction choice (`withAuthTransaction`), cross-slice composition,
  read→plan→update→publish, merge/plan logic (extracted to a pure helper). A facade calls its own
  repos + sibling facades — **never a foreign slice's repo**.
- **No DB access outside a repo:** a facade/service/projector/handler that reaches for `Drizzle`/SQL
  directly (instead of going through a repo) is a **BLOCKER** — the write/read belongs in a repo
  method the facade calls. (Transaction boundaries are the facade's; the queries inside are the
  repo's.) Ingestion projectors count as orchestration: they call repos, they don't run raw SQL.
- **Placement:** new vertical slices go in `packages/services` (repo + slice facade); extending an
  existing `packages/database` slice is fine — a brand-new slice landing in `packages/database` is a
  non-blocking **issue**, not a merge blocker.

**Naming & tracing (same gate):** service tag === class name; **every effectful repo/facade method
is `Effect.fn("<Tag>.<method>")`** so its span is traceable; feature dir/Facade plural, domain
models singular; files PascalCase. A method whose span name doesn't carry its service tag, a repo
doing business logic, business logic touching the DB outside a repo, or a facade calling a foreign
repo — each is a **BLOCKER**, not cosmetic.

Also check the packet's **"Watch out for"** and **"Tests to write"** sections — the edge cases
the planner identified at the top of the loop. Each should be handled in the code and, where the
packet listed a test, that test must exist and be green. An unhandled edge case the planner called
out is a BLOCKER, not a nit — the smart model already flagged it as load-bearing. Beyond those,
still do your own adversarial pass for edge cases the planner may have missed.

## Phase 2 — Decide the depth of evaluation (the fresh-eyes rule)

The Karpathy loop says the evaluator is *"a second agent, or the same agent with a different
prompt context."* Pick the depth deliberately:

| Condition | Evaluation mode |
|---|---|
| Routine iteration, low blast radius (most subtasks) | **In-session** — you, now, with context. Cheap, fast. |
| Subtask stamped `fresh_eyes: review-fresh`, OR touches auth / payments / migrations / destructive / data-loss | **`review-fresh`** — parallel Claude subagents with NO chat history. Kills tunnel-vision and confirmation bias. Requires a clean working tree (it rebases onto `dev`). |
| Subtask stamped `fresh_eyes: codex`, OR a large diff, OR you want a genuinely orthogonal mind, OR the user said "P1 gate / full review" | **`codex`** — cross-model (OpenAI). Catches what Claude is structurally blind to. |
| In-session and a fresh pass **disagree** | escalate to **`codex`** to break the tie |

Default bias: **iterate in-session; go fresh when the cost of being wrong is high or you're at a
landing gate.** Don't spend a cross-model pass on a one-line Quick subtask. Don't ship an auth
change on in-session review alone.

Always run a quick in-session adversarial pass regardless of mode — think like an attacker and a
chaos engineer for a moment: edge cases, race conditions, nil propagation, silent failure,
resource leaks. It's free and it's where the cheap wins are.

## Phase 3 — Classify findings

Sort everything you found into:
- **BLOCKER** — a done-criterion fails, or a real bug/security issue. Must be fixed before ship.
- **BUG (needs root cause)** — behavior is wrong and the cause isn't obvious → recommend
  `/ansh-debug` rather than a blind patch.
- **NIT** — style/clarity; optional. If a `gold-star` reference applies, note divergence from it.

## Output (what /ansh-loop consumes)

Return a compact verdict block:

```
VERDICT: PASS | REVISE | DEBUG
CRITERIA: <n met> / <n total>
MODE: in-session | review-fresh | codex
BLOCKERS: [ {subtask, finding, suggested fix} ... ]
BUGS: [ {symptom, why root-cause is non-obvious} ... ]   # → /ansh-debug
NITS: [ ... ]
```

- **PASS** → loop may proceed to ship.
- **REVISE** → loop feeds BLOCKERS back to `/ansh-task` (or `/ansh-plan` if architectural).
- **DEBUG** → loop hands BUGS to `/ansh-debug` for root-cause before any fix.

## Completion status

End with **DONE** (verdict emitted) or **BLOCKED** (couldn't evaluate — e.g. dirty tree blocked
`review-fresh`; say what's needed).
