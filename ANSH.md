# /ansh — Ansh's curated skill arsenal

The authoritative, precise list of the skills I drive my work with. Everything under the
`/ansh-` prefix is **mine — edited, current, and trustworthy**. Non-`/ansh-` project skills
(`/chill-describe`, `/gold-star`, `/linear-sync`, `/lightweight-sql`, `/effort-dial`,
`/review-fresh`, `/loop`) are dependencies these call by
name; I keep `/ansh-` as the master set. I don't lean on gstack day-to-day anymore, so the
`/ansh-` skills describe their own logic directly (codex CLI invocation, PR creation, etc.)
rather than delegating to gstack skills.

Architecture: the **Karpathy loop** — a planner decomposes, cheap specialists execute, an
evaluator scores against explicit criteria, and the loop revises until a quality bar is met.
Reference: generator → evaluator → revise, with role separation by model.

## The set

Effort ladder — thinking is most expensive where it has the most leverage: **planner > reviewer >
debug ≈ specialist.** Every level is **dial-driven**: `effort-dial` (run at `/ansh-small-loop` Step 0,
re-diagnosable per subtask) picks the Standard or Deep setting. The ordering holds at every tier;
the absolute level slides with the goal.

| Command | Role | Model / effort (Standard → Deep) | One-liner |
|---|---|---|---|
| **`/ansh-small-loop`** | Orchestrator (small) | Opus, conductor | For small, scoped tickets only. Runs plan→execute→evaluate→revise→ship→resolve as a closed loop with explicit termination. A project-scale goal (spans a Linear project, needs a real architecture/product call, shape not settled) gets handed off to `/ansh-loop` at Step -1. |
| **`/ansh-loop`** | Orchestrator (project) | Opus, conductor | For project-scale goals only — spans a Linear project/multiple parent tickets. Runs strictly after `/ansh-plan` has produced guardrails + acceptance_criteria + exit_criteria; gates on an explicit human sign-off of those three lists (`AskUserQuestion`, no auto-pick) before any execution; then fans out subtasks/sections via dynamic **Workflows** (`pipeline()`/`parallel()`) instead of a serial walk. A single scoped ticket gets redirected to `/ansh-small-loop`. |
| **`/ansh-plan`** | Planner | **Opus high → Opus high + extended thinking** (top) | Goal (Linear OR prose) → machine-readable subtask list, each stamped with model + effort + done-criteria + edge cases. Then a **codex CLI challenge pass** attacks the plan (missing subtasks, bad ordering, weak criteria, missed edge cases) before hand-off. Linear-optional. |
| **`/ansh-review`** | Evaluator | **Opus medium → Opus high + thinking** (one below planner) | Thinking role; never cheap. Scores output vs done-criteria, verifies flagged edge cases. Runs a **cross-model codex CLI review pass on every evaluation** as the baseline bug hunt; adds review-fresh / swarm on top for high-risk. Returns PASS / REVISE / DEBUG. |
| **`/ansh-debug`** | Bug feedback loop | **Sonnet medium → Opus med/high** (only climbs when stuck) | Starts cheap — review/comments already handed it a lead. Root-causes, emits fix-subtasks, dispatches through `/ansh-task`. 3-strike rule = escalation trigger. |
| **`/ansh-task`** | Specialist | **Sonnet low → Sonnet medium** (cheap execution) | Executes ONE scoped subtask, self-verifies against its done-criteria, stops. Minimal ceremony. Kicks back if low-conviction. |
| **`/ansh-resolve`** | Outer loop | Sonnet/Opus, medium | Post-push: combs CI checks + bot/human review comments + Linear; triages; dispatches fixes; closes threads. |
| **`/ansh-pr-loop`** | Recurring outer loop | Sonnet/Opus, medium | Runs `/ansh-resolve` on a ~5-min self-pacing cadence until CI is green and no review blocks — dismisses a stuck BOT review once its findings are verifiably fixed (never dismisses a human review), then asks before merging. Use to babysit a PR to mergeable instead of one manual `/ansh-resolve` pass. |
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

The evaluator is *"a second agent, or the same agent with a different prompt context."* The
strongest second agent is a different model:

- **`codex`** (default, every evaluation) — cross-model review of the diff vs done-criteria. An
  orthogonal mind catches what Claude is structurally blind to; this is the baseline bug-finding
  pass, always run.
- **in-session adversarial** — always run alongside Codex, free; its findings feed the same verdict.
- **`review-fresh`** — auth / payments / migrations / destructive / data-loss. Parallel Claude
  agents with NO chat history; kills tunnel-vision. Runs ON TOP of the Codex pass. Needs a clean
  tree (rebases onto `main`).
- **`swarm`**: a Workflow swarm of pr-review-* dimension reviewers (in `agents/`) with
  adversarial verification of every finding. On top of the Codex pass, for large structural
  diffs, consolidation merges, or when asked for a swarm.
- Codex vs in-session disagreement → re-read the cited code; if unresolved, escalate to
  `review-fresh` to break the tie. Never silently drop a Codex finding.

If Codex is unavailable, fall back to `review-fresh` and flag the skipped cross-model pass — never
silently downgrade to in-session-only.

## Glue skills (kept as-is, called by name — NOT forked)

These are cross-cutting helpers the `/ansh-` skills invoke. They're good as they are; do not
duplicate them under `/ansh-`:

- **`effort-dial`** — 5-axis tier diagnostic. `/ansh-plan` reuses it to stamp each subtask; `/ansh-small-loop` uses it to right-size the whole goal (`/ansh-loop` doesn't re-run it at the goal level — the plan it requires already stamped every subtask). (🟢 Quick→sonnet/low, 🟡 Standard→sonnet/med, 🔴 Deep→opus/high.)
- **`chill-describe`** — commit/PR style. Mandatory before every git/gh write.
- **`gold-star`** — hold work to a named reference implementation. Surface divergence in review.
- **`linear-sync`** — reconcile a ticket with reality after shipping.
- **`lightweight-sql`** — minimize DB load on any SQL/Drizzle diff.

## CLI arsenal (reference, not a skill)

**`ANSH-cli-tools.md`** (sibling of this file) — the debugging/resolution CLI map that
`/ansh-debug` (Phase 1) and `/ansh-resolve` (Phase 1 & 4) pull from: `signoz` (prod traces/logs),
`bk` (Buildkite CI logs + flaky-step retry — `gh` can't read Buildkite), `sentry-cli` (prod
errors), plus `kubectl`/`k9s`/`argocd`/`psql`/`pscale`/`supabase`/`temporal`. Credentials + PATH
live in `~/.config/ansh-cli/env.sh` (git-excluded, chmod 600); source it before use. The rule:
**pull the primary source yourself instead of asking the human to paste a log** — but keep it
read-only, and name any missing token rather than working around it.

**`/ansh-codex`**: the codex CLI skill. `/ansh-plan` calls it in `challenge` mode (Phase 5) and
`/ansh-review` in `review` mode (Phase 2). It owns the binary and auth check, the exact
`codex review` / `codex exec` invocations, the output gate (`CODEX: PASS|FAIL|...`) and the
unavailable fallback. You can also run it directly on any branch. No gstack dependency.

## Relationship to /solve-linear-ticket

`/solve-linear-ticket` is the linear (non-looping) predecessor. Its genuinely useful parts —
fetching ticket context, clarifying scope, the In-Progress transition — now live in `/ansh-plan`,
which works **with or without** a Linear ticket. Reach for `/ansh-small-loop` (single ticket) or
`/ansh-loop` (project) as the canonical end-to-end runners; `/solve-linear-ticket` stays available
but isn't the default.

## How a session typically flows

Small, scoped ticket:
```
/ansh-small-loop "REV-712: availability requests drop the timezone on overnight shifts"
  → effort-dial: Deep (touches shared scheduling + tz)
  → /ansh-plan       → 4 subtasks, T1-T2 Quick, T3-T4 Standard, T3 flagged review-fresh
  → /ansh-task T1    → done; /ansh-review T1 → PASS
  → /ansh-task T3    → done; /ansh-review T3 (review-fresh, tz/shared) → DEBUG (off-by-one at DST)
  → /ansh-debug      → root cause confirmed, writes T5 (fix + regression test), dispatches /ansh-task T5
  → /ansh-review T5  → PASS
  → whole-goal eval (codex, landing gate) → PASS
  → commit + open PR via git/gh (chill-describe format) → PR up
  → /ansh-resolve    → Cursor flagged a nil case; /ansh-task fixes it; checks green; threads closed
```

Project-scale goal:
```
/ansh-plan "REV-1157: payrule threshold rework across the accrual + reporting stack"
  → 4 sections, 11 subtasks, guardrails/acceptance_criteria/exit_criteria written
  → codex challenge pass folds in 2 missed edge cases
/ansh-loop
  → Step -1: project-scale, stays in this loop
  → Step 0: plan.json has all three criteria lists — proceeds
  → Step 1: AskUserQuestion walks guardrails, acceptance_criteria, exit_criteria — confirmed
  → Step 2: Workflow fans out section 1 + section 2 (independent) via pipeline()/parallel();
            section 3 waits on section 1's deps
  → whole-goal eval vs acceptance_criteria → PASS
  → 4 section PRs → integration branch → umbrella PR → main
  → /ansh-resolve per section as each lands
  → DONE
```

## Keeping this list current

When I change how I work, I edit the `/ansh-` skill, then update its row here. This file is the
index; the SKILL.md files are the source of truth. New curated skill → add `/ansh-<name>`, add a
row. Retired → remove both.
