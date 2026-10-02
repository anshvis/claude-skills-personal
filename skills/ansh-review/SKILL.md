---
name: ansh-review
description: EVALUATOR role in the Karpathy loop. Runs at Opus medium/high effort with extended thinking — a thinking role, one step below the planner and well above the cheap specialist. Scores a specialist's output against the subtask's explicit done-criteria, verifies the planner's flagged edge cases were handled, finds gaps/bugs/risks, and always pulls in CROSS-MODEL (codex) eyes for the bug hunt. This is the "second agent that evaluates against defined criteria" from the Karpathy loop — it returns structured PASS/FAIL + findings that the orchestrator (/ansh-small-loop or /ansh-loop) uses to decide revise-or-ship. Runs a cross-model codex review pass on EVERY evaluation by default (the strongest "second agent" is a different model — it catches bugs Claude is structurally blind to), with a free in-session adversarial pass alongside, and adds review-fresh (no-history parallel Claude agents) or thermo-nuclear (strict maintainability swarm) on top for high-risk diffs. Use when the user says "/ansh-review", after a /ansh-task completes, or when /ansh-small-loop or /ansh-loop reaches the evaluation step.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - Skill
  - Workflow
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

## Phase 0 — Ground yourself in the codebase's patterns (always, before judging)

Do not evaluate against generic taste — evaluate against **this repo's** written standards and
prior art. Before scoring, load (skim headings, read the sections the diff touches):

- Root `AGENTS.md`, then the nearest nested `AGENTS.md` for the touched packages.
- `.agents/skills/best-practices/references/` — the canonical pattern docs:
  `services-and-layers.md` (repo/facade split), `vertical-slices.md` (slice ownership and
  placement), `contracts-and-domain.md` (schemas, branded IDs, domain types), `errors.md`
  (tagged errors, no silent failure), `testing-and-review.md`, `dates.md` (ZDT/temporal),
  `repo-hygiene.md`, `migration.md`, `accessibility.md`.
- For Effect idioms: `bunx effect-solutions show <topic>` and `submodules/effect` — never invent
  a pattern the codebase hasn't blessed.
- **Prior art beats doctrine:** before flagging "wrong pattern", grep for how the nearest sibling
  slice does it (e.g. an existing Repo + Facade pair, an existing projector). A diff consistent
  with its best-in-class neighbor is not a finding; a diff consistent with a *known-bad* neighbor
  still is — cite the reference doc, not the neighbor.

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
prompt context."* The strongest version of "a second agent" is a **different model** — a mind
that is structurally blind to different things than Claude is. So:

**Codex is the default review pass on every evaluation.** Run the codex CLI directly in **review
mode**, scoped to this subtask's diff and its done-criteria, on every `/ansh-review` — not just
the big or risky ones. The binary/auth check, exact invocation, gate parsing, and presentation
format all live in `~/.claude/skills/ANSH-codex.md`; read it rather than guessing the command. A
cross-model fresh opinion is where the real bugs get caught — this is the whole point of the
evaluator role. Feed Codex the subtask's done-criteria and the packet's "Watch out for" edge cases
so it grades against the same bar you do.

Run the free in-session adversarial pass alongside it (always — see below); its findings and
Codex's findings both flow into the same Phase 3 verdict. Then layer on the heavier modes when the
stakes justify them:

| Condition | Add this on top of the Codex pass |
|---|---|
| Every evaluation (default) | **`codex`** — cross-model review of the diff vs done-criteria. This is the baseline, always run. |
| Subtask stamped `fresh_eyes: review-fresh`, OR touches auth / payments / migrations / destructive / data-loss | **`review-fresh`** — parallel Claude subagents with NO chat history. Kills tunnel-vision and confirmation bias. Requires a clean working tree (it rebases onto `dev`). Runs in ADDITION to Codex, not instead of it. |
| User said "thermo-nuclear" / "thermonuclear", OR the diff is a large structural change (new slice, consolidation merge, refactor touching >~10 files), OR a file is at risk of crossing 1k lines | **`thermo-nuclear`** — strict maintainability audit + verification swarm (below), on top of the Codex pass |
| Codex and your in-session read **disagree** on a finding | resolve it explicitly — re-read the cited code, and if still unresolved, escalate to `review-fresh` to break the tie. Never silently drop a Codex finding. |

If Codex is genuinely unavailable (the binary/auth check in `ANSH-codex.md` comes back
`CODEX_UNAVAILABLE`), fall back to `review-fresh` for that evaluation and note in the verdict that
the cross-model pass was skipped. Do not silently downgrade to in-session-only; a skipped
cross-model pass is a concern the loop should see.

**`thermo-nuclear` mode.** Two halves, run together:

1. **Standards + doctrine:** invoke the `thermo-nuclear-code-quality-review` skill
   (`~/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md` — read it directly if the
   Skill tool doesn't list it this session) and apply its full bar — code-judo ambition, the
   1k-line rule, spaghetti-growth blockers, boundary/type cleanliness — **on top of** this
   skill's Phase 0 pattern grounding and Phase 1 layering gate, not instead of them.
2. **Swarm + adversarial verify:** when the diff is big enough to exceed one honest read (or the
   user asked for a swarm), fan out via the Workflow tool: one reviewer per dimension
   (`pr-review-code-reviewer`, `pr-review-silent-failure-hunter`, `pr-review-test-analyzer`,
   `pr-review-type-analyzer`, `pr-review-comment-analyzer`, `pr-review-simplifier`), each
   returning structured findings scoped to *this diff only*; then an adversarial verifier per
   finding that tries to REFUTE it against the actual code (default to refuted when uncertain).
   Only verified findings enter Phase 3 — unverified reviewer output is noise, not evidence.
   Merge-consolidation diffs get an extra instruction: hunt semantic merge errors in the
   conflict-resolved files (code kept from one side assuming state the other side removed,
   dead imports/state, stale comments describing removed behavior).

Always run a quick in-session adversarial pass regardless of mode — think like an attacker and a
chaos engineer for a moment: edge cases, race conditions, nil propagation, silent failure,
resource leaks. It's free and it's where the cheap wins are.

## Phase 3 — Classify findings

Sort everything you found into:
- **BLOCKER** — a done-criterion fails, or a real bug/security issue. Must be fixed before ship.
- **BUG (needs root cause)** — behavior is wrong and the cause isn't obvious → recommend
  `/ansh-debug` rather than a blind patch.
- **NIT** — style/clarity; optional. If a `gold-star` reference applies, note divergence from it.

## Output (what the orchestrator — /ansh-small-loop or /ansh-loop — consumes)

Return a compact verdict block:

```
VERDICT: PASS | REVISE | DEBUG
CRITERIA: <n met> / <n total>
MODE: codex (default) [+ in-session] [+ review-fresh] [+ thermo-nuclear]   # codex always present unless it says CODEX_SKIPPED (unavailable)
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
