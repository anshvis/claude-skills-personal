---
name: ansh-loop
description: "Orchestrate project-scale work from an approved ANSH plan using available delegation or serial execution. Require human sign-off on guardrails, acceptance and exit criteria; preserve specialist, review, debug and resolve gates. Use /ansh-loop for projects or multiple parent tickets; use /ansh-small-loop for one scoped ticket."
---

# /ansh-loop — Orchestrator (project scale)

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

The conductor for work too big to hand a single specialist chain: a project, an initiative, or a
goal spanning multiple parent/epic tickets. It does not plan, code, or review directly — it reads
an already-approved plan, gets an explicit human sign-off on that plan's guardrails and
acceptance/exit criteria, then drives execution through the **available orchestration backend**, preserving dependencies and human checkpoints. Keep this skill thin on role logic (that still lives
in `/ansh-plan`, `/ansh-task`, `/ansh-review`, `/ansh-debug`, `/ansh-resolve`) — its own value is
the criteria gate and dependency-aware execution.

```
inverse gate → REQUIRE plan.json → CRITERIA STOP (human) → WORKFLOW FAN-OUT ─┬─ PASS ──► SHIP ─► PR-LOOP
                                                          per section:       │
                                                          TASK ─► REVIEW ────┼─ REVISE ─┐
                                                                             │          │
                                                             DEBUG ◄─ BUG ───┴──────────┘
                                                             └── emits new subtasks back into PLAN
```

## Hard rules

Everything `/ansh-small-loop` enforces still applies here — worktree/session discipline,
`/chill-describe`, the integration-branch + small-section-PR topology, the per-subtask small-commit
discipline, the commit review gate in allow-edits mode, never pushing to `main`/`master`, per-ticket
PR linking (each PR links every ticket its own diff advances), `.ansh/` local-exclude hygiene, and loop termination. Read `/ansh-small-loop`'s
"Hard rules" section — it is not repeated verbatim here to avoid drift between two copies; treat it
as inherited. Two rules are **specific to this loop**:

- **No execution without the criteria STOP.** Step 1 below is a hard gate — a project this size
  does not get to "just start." Skipping it (because the plan looks obviously fine, because time
  pressure) defeats the entire reason this loop exists as a separate skill from
  `/ansh-small-loop`.
- **Workflow fan-out has a cap.** This session's workflow-size guideline is medium (under ~15
  agents per workflow). A project with more sections than that runs multiple sequential Workflow
  calls (one per wave, or one per PR group) rather than one giant fan-out, and `log()`s anything
  intentionally deferred to a later wave — never silently truncate.

## Step -1 — Inverse scope gate (does this actually belong in the BIG loop?)

`/ansh-loop` is for project-scale work. If the goal is actually one scoped ticket or one clearly
bounded ask — no Linear project, no multiple parent tickets, no architecture call left open —
say so and hand off to **`/ansh-small-loop`** instead of running the machinery below on it. Use
`/ansh-small-loop`'s Step -1 checklist as the test, inverted: if NONE of its trigger conditions
hold, this loop is the wrong tool.

## Step 0 — Require an approved plan (do not invoke `/ansh-plan` from here)

This loop does **not** run the planner itself — planning a project is Ansh's-judgment-in-the-loop
work that happens via `/ansh-plan` (or the human-led shaping in `/ansh-small-loop`'s Step -1
option B) *before* `/ansh-loop` is ever invoked.

Read `.ansh/plan.json` and `.ansh/plan.md`. Refuse and stop if any of these are true:
- `.ansh/plan.json` doesn't exist — tell the user to run `/ansh-plan` first.
- The plan is missing any of `guardrails`, `acceptance_criteria`, or `exit_criteria` (an older
  plan predating this contract) — kick back to `/ansh-plan` to backfill them; do not improvise
  these yourself, they are the planner's call to make with full context.
- The plan's own shape still reads as unsettled (Phase 3.5 readiness boxes unchecked for most
  subtasks) — that's `/ansh-plan` or human-shaping work, not this loop's.

If the plan is present and complete, proceed to Step 1.

## Step 1 — Criteria STOP (hard human gate, before anything executes)

This is the one non-negotiable gate in this skill. Present, via `AskUserQuestion`, item by item —
not as a wall of text to rubber-stamp:

1. **`guardrails[]`** — the boundaries this run will not cross (out-of-scope areas, "no schema
   change without a migration review," "no prod writes," etc.). Confirm each is still correct and
   ask if anything new should be added given how the plan turned out.
2. **`acceptance_criteria[]`** — the goal-level, product/user-facing bar. Confirm these are what
   "done" actually means to the person who asked for this, not just what's testable.
3. **`exit_criteria[]`** — the conditions that stop this loop regardless of whether acceptance
   criteria are met (max iterations exhausted, a guardrail tripped, blocked on a human decision,
   a section's whole-goal evaluation fails twice). Confirm the loop should actually stop on each
   of these, and confirm there isn't a missing one.

Do not auto-pick or auto-confirm on the user's behalf, and do not proceed past this step on a
"looks fine, continuing" assumption — wait for the explicit answer. If the user wants changes to
any of the three lists, that's a plan edit: either patch `.ansh/plan.json`/`plan.md` directly for
a trivial wording fix, or route back to `/ansh-plan` if it changes decomposition. Only once all
three are explicitly confirmed does execution begin.

## Step 2 — Execute through the available orchestration backend

Use the runtime guide's orchestration mapping. When Workflow is absent, dispatch ready
packets with host-native delegation; when delegation is absent, run roles serially. Report
that fallback and preserve every gate, dependency and exit condition. The details below
apply only to the Workflow backend; do not call nonexistent APIs. Pause after each specialist
for its manual human diff review before scheduling automated evaluation.

- **Enumerate first, in plain tool calls — not inside the script.** Workflow scripts have no
  filesystem access. Before calling `Workflow`, read `.ansh/plan.json` and list `.ansh/tasks/*.md`
  yourself (Bash/Read), then pass the subtask/PR list in through `args` (as real JSON, never a
  stringified blob).
- **Shape: pipeline per PR/section, not one flat fan-out.** Each `plan.json.prs[]` entry is a
  section; within a section, subtasks with dependencies still respect `deps` (encode as sequential
  stages in `pipeline()`; independent subtasks within a stage run via `parallel()`). Across
  sections, independent sections can pipeline concurrently — a later section's subtasks shouldn't
  block on an earlier section's *review*, only on its actual `deps`.
- **`isolation: 'worktree'` is a concurrency property, not a file-sensitivity property — never
  isolate a node that has an in-run dependent.** `isolation: "worktree"` gives an `agent()` call a
  fresh checkout branched off the base commit, with ZERO visibility into any other agent's
  (including an already-finished one's) uncommitted worktree changes — scripts have no filesystem
  access to bridge worktrees between stages, so a dependent stage isolated this way will always find
  its dependency's code missing and correctly refuse to proceed (`NEEDS_REPLAN`), even though the
  upstream agent genuinely finished. The rule: isolate a subtask ONLY if it runs inside the same
  `parallel()` call as another subtask touching overlapping files — that is, only leaves of the
  dependency graph with no in-run consumer. Any subtask with a `deps` edge pointing at it from
  within this same Workflow run must execute unisolated, in the shared invoking directory,
  sequentially with its dependency (the ordinary `await agent()`/`pipeline()` sequencing already
  guarantees single-writer-at-a-time, so no isolation is needed for conflict-safety there either).
  If a wave boundary forces a dependency across two separate `Workflow` calls, the orchestrator
  (this conversation, not the script) must reconcile state between them, since the script itself
  cannot. Do it through git, not by copying files: commit and push the upstream section's branch,
  then have the dependent section start from it per [stacking](../_shared/stacking.md) (fetch, cut
  from `origin/<dependency-branch>`, confirm the dependency's code is present).
- **Each subtask's execution + evaluation is one pipeline, not a barrier.** Model per subtask as:
  `agent()` running `/ansh-task <id>` → `agent()` running `/ansh-review` for that subtask → branch
  on verdict. Use `pipeline()` across subtasks in a section so review of subtask N overlaps
  execution of subtask N+1 where deps allow.
- **NEEDS_REPLAN / BLOCKED / DEBUG still escalate exactly as in `/ansh-small-loop`** — a subtask
  returning `NEEDS_REPLAN` routes back to `/ansh-plan` (outside the Workflow, in this
  conversation — don't try to have the Workflow itself call the planner mid-fan-out), `BLOCKED`
  surfaces to the user, and a `DEBUG` verdict hands to `/ansh-debug`, whose new fix-subtasks
  rejoin the plan and get picked up in the next wave.
- **Respect the fan-out cap.** If the section/subtask count exceeds the session's workflow-size
  guideline, split into multiple `Workflow` calls (one wave at a time, in dependency order) rather
  than one oversized script, and `log()` what's queued for the next wave.
- **Every `exit_criteria[]` condition is checked between waves.** If one trips (a guardrail
  violation surfaces, max iterations for a subtask is exhausted, a whole section fails twice),
  STOP the loop and surface it — do not let the Workflow silently keep going into the next wave.

## Step 3 — Whole-goal evaluation against acceptance criteria

Once every section's subtasks PASS, run one evaluation against `acceptance_criteria[]` (not just
per-subtask done-criteria) — this is the landing gate, and it checks the criteria confirmed in
Step 1, not a paraphrase of them. Run it as `/ansh-review` with the cross-model independent pass; if the
goal touches auth/payments/migrations/destructive surface, add `review-fresh` on top.

## Step 4 — SHIP (integration branch + small section PRs)

Every branch and PR follows [stacking](../_shared/stacking.md):
- Base each one on the dependency's branch while that PR is open, otherwise on the integration
  branch.
- Fetch before cutting, and merge the base in before every push.
- Never rebase or force-push.

Same topology as `/ansh-small-loop`'s Step 4 — integration branch, small section PRs merging into
it in dependency order, umbrella PR to `main` last, `/chill-describe` on every commit/PR. Each section PR
links its own tickets (`Closes` / `Part of` per `plan.json.prs[].links`), and only the umbrella links the
parent. After each Workflow wave, the orchestrator checks that every linked ticket shows its PR, and that
the parent didn't pick up section PRs. At project scale, sections map 1:1 to `plan.json.prs[]`
entries and there will typically be more of them; open/merge them small-first exactly as before.

## Step 5 — Drive each PR to merge with `/ansh-pr-loop`

Right after each section PR opens, run `/ansh-pr-loop <n> via=ansh-loop` on it (the `via` tag
feeds its outcome ledger). Don't wait for the rest of the
wave. Its review gate starts with `/ansh-review`'s triage, which sorts the PR into setup, logic or
wiring, rates the plan gap and the blast radius, and makes the merge call before any other review
runs:
- **`auto`, and every dependency merged** → `/ansh-pr-loop` drives the PR to green and
  squash-merges it into the integration branch. Then retarget and merge up the PRs stacked on it
  (stacking, "When a dependency merges"), and their loops carry on.
- **`manual-review`** (a large plan gap or a high blast radius) → `/ansh-pr-loop` posts the
  merge-call comment saying it needs manual review and stops at once: no further reviews, fixes or
  CI babysitting on that PR. Record it in `.ansh/plan.json` (`prs[].merge_call`). Re-run
  `/ansh-pr-loop <n>` once the user has looked (or said go ahead). Review comments the user left
  on the PR count as that look. From then on the agent owns the rest: it answers every comment,
  makes the changes (deciding direction questions itself and explaining the call on the PR), and
  merges when green, without asking again.
- **A dependency is still open or waiting for manual review** → don't merge, even when the call is
  `auto`. Keep building and reviewing the dependent sections on top (stacked), drive them to
  green, and post the `waiting-on` comment on each. They merge automatically, with no review
  request of their own, once the PR below them merges.

**The umbrella PR to `main`** runs `/ansh-pr-loop <n> merge=ask`. It is the whole project landing on
`main`, so a person always says yes to it.

**Between waves, report the merge state.** List each PR as merged, waiting on #<n>, or needs
manual review, with the reason. A PR left for manual review isn't an exit criterion by itself.
Keep working on everything that doesn't depend on it. Stop and report only when nothing else can
move without the user.

## Glue (called by name, never forked)

- `chill-describe` — every commit/PR write.
- `lightweight-sql` — when a subtask's diff includes SQL/Drizzle (the specialist calls it).
- `gold-star` — when the user names a reference implementation to hold the work to; surface
  divergence in `/ansh-review`.
- `linear-sync` — optional wrap-up to reconcile tickets with reality after shipping.

Note: this loop does not call `effort-dial` on the whole goal the way `/ansh-small-loop` does —
`/ansh-plan` already ran it per subtask before this loop was ever invoked (Step 0 refuses to run
without that). `effort-dial` still applies inside each `agent()` call implicitly via the subtask's
stamp.

## Termination & completion

The loop ends when `acceptance_criteria[]` is met and each PR's `/ansh-pr-loop` shows checks green + review
settled, OR when any `exit_criteria[]` condition trips (then STOP and report — don't spin). End
with:
- **DONE** — shipped, acceptance criteria met, checks green, review settled, Linear linked.
- **DONE_WITH_CONCERNS** — shipped but open items remain (list them against acceptance criteria).
- **AWAITING_REVIEW** — everything that could merge has merged. The rest is waiting on manual
  review: list each PR, its kind, why it was called, and what depends on it.
- **BLOCKED** — could not proceed (what was tried, which guardrail or exit criterion stopped it).
- **NEEDS_CONTEXT** — missing a user decision (state exactly what).

Close with a short summary: what shipped (PR URLs), what is waiting for manual review and why, which exit criterion ended the loop if it
wasn't full completion, and anything left open. Don't re-narrate the whole run.
