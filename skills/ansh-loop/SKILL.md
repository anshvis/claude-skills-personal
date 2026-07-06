---
name: ansh-loop
description: ORCHESTRATOR / super-command for the Karpathy loop. The one command you run to take a goal (Linear ticket or prose) from understanding through shipping using the /ansh- role skills. Conducts plan → execute → evaluate → revise as a real closed loop with explicit termination (all done-criteria pass, or max iterations), decides when to pull in fresh/cross-model eyes, then ships. Calls /ansh-plan (planner), /ansh-task (specialist), /ansh-review (evaluator), /ansh-debug (bug loop), and after push /ansh-resolve (outer loop), wiring in the glue skills (effort-dial, chill-describe, gold-star, linear-sync, lightweight-sql). Use when the user says "/ansh-loop", "run the loop", or hands over a goal to drive end-to-end.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - Agent
  - Skill
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_comments
  - mcp__linear-server__save_comment
  - mcp__linear-server__save_issue
---

# /ansh-loop — Orchestrator

The conductor. It does not plan, code, or review directly — it sequences the `/ansh-` role
skills into the Karpathy generator→evaluator→revise cycle, holds the loop state, and decides when
the loop terminates. Keep this skill thin: its value is the control flow and the termination
discipline, not re-implementing the roles.

```
right-size → PLAN → ┌─► TASK ─► REVIEW ─┬─ PASS ──► SHIP ─► RESOLVE
                    │   (specialist)     │                    (outer loop:
                    │                    ├─ REVISE ─┐          CI + comments)
                    └────────────────────┘          │
                    ▲   DEBUG (root cause) ◄─ BUG ───┘
                    └── emits new subtasks back into PLAN
```

## Hard rules

- **`/chill-describe` is mandatory** before any `git commit` / `gh pr create` / `gh pr edit
  --body`. No co-author trailer, no emoji, no "Generated with" footer. Applies inside `/ship` too.
- **Use an integration branch; land the work as many SMALL PRs that merge into it, not one big
  PR to `dev`.** For any non-trivial goal, the ticket's branch (e.g. `rev-746-...`) is a long-lived
  **integration branch** that has exactly one PR → `dev` (the umbrella "main" PR for the epic). The
  actual work arrives as a stack of **small section PRs that target the integration branch, not
  `dev`** — each one a tight, independently-reviewable diff (a few files: one layer/subtask, e.g.
  the schema+migration, the concept, the resolver, the projector, the fetch, the cron, the alerts).
  A reviewer approves each small section against the integration branch; the umbrella PR to `dev`
  is then the sum, already reviewed in pieces. **A section PR does NOT need to compile/ship against
  `dev` on its own** — that's the whole point of the integration branch, and it's what lets you cut
  far smaller PRs than "independently mergeable" would allow. Size test: if a section PR touches
  more than ~8–10 files or mixes layers, split it. A 26-file PR to `dev` is a failure of this rule.
  Topology: `integration → dev` (umbrella); `section-1 → integration`, `section-2 → integration`, …
  (small, merged in order). `/ansh-plan` records the integration branch + the ordered section PRs
  (each → integration) in `plan.json.prs`; the orchestrator opens/merges sections small-first, then
  the umbrella.
- **Commit in small, per-change commits — never one dump at the end.** Each commit is one logical
  change (one migration, one concept, one resolver, one projector, its tests) so any single change
  can be reverted in isolation. Commit as each subtask (or coherent sub-step) verifies green, not
  all at once at SHIP. `/chill-describe` governs the message (short imperative subject).
- Never push to `main`/`master`. Work on the branch `/ansh-plan` proposes — which, when a Linear
  ticket exists, follows `<tag-lower>-<slug>` (e.g. `rev-669-availability-request-integration`),
  one branch per PR. Don't invent a generic branch name when a ticket exists.
- **Linear status flows with the work.** The planner moves in-scope tickets to In Progress when
  their work begins; each `/ansh-task` confirms its ticket is In Progress on pickup. Let the GitHub
  integration move `In Review`/`Done` — the loop never sets those by hand. At SHIP, link the
  ticket(s) inline in the PR body (e.g. "Closes REV-554"), per `/chill-describe`.
- **Sub-issues mirror the branch topology — the epic maps to the umbrella PR, each section PR maps
  to its own sub-issue.** The original ticket becomes the **epic**, tracked by the umbrella
  `integration → dev` PR. The planner creates one **sub-issue per section PR** under the epic; each
  section's `plan.json.linear_ticket` points at its sub-issue, and the small section PR (→ the
  integration branch) "Closes" that sub-issue in its body. The umbrella PR references the epic. Never
  dump every section onto the one epic ticket, and never fabricate ticket numbers — create the
  sub-issues via Linear and read the returned ids. (A trivial single-PR goal skips this — the one
  ticket is enough.)
- Honor every STOP point in the sub-skills. Surface their `AskUserQuestion` gates; don't auto-decide.
- **Never commit the `.ansh/` working dir, and never add it to the tracked `.gitignore`.** Keep it
  out of git via the local exclude only:
  `grep -qxF '.ansh/' "$(git rev-parse --git-path info/exclude)" || printf '\n.ansh/\n' >> "$(git rev-parse --git-path info/exclude)"`.
  Same for any agent-local scratch — local exclude, not the committed `.gitignore`.
- The loop must **terminate**. Respect `termination.max_iterations` from the plan. If the bar
  isn't met after max iterations, STOP and report — don't spin.

## Step 0 — Right-size (skip what the goal doesn't need)

Apply `effort-dial` to the whole goal first. The tier sets how much loop you run:

- 🟢 **Quick** (one-line, mechanical, local): skip the full loop. One `/ansh-task` + a light
  `/ansh-review`, then ship. Don't build a 6-skill cathedral for a typo.
- 🟡 **Standard**: the normal loop below.
- 🔴 **Deep** (ambiguous / high blast radius): full loop, and bias `/ansh-review` toward
  fresh/cross-model eyes.

Announce the tier in one line so the user can recalibrate.

## Step 1 — PLAN

Invoke `/ansh-plan` with the goal. It gathers context (Linear or prose), clarifies, and writes
the `.ansh/` directory: `plan.md` (high context), `plan.json` (machine index), and one
self-contained `tasks/<id>.md` packet per subtask. Wait for it. Surface its clarifying questions.
Do not proceed until the packets exist and the user is content with the decomposition — the
packets being self-contained is what lets the specialists run cheap.

**PR decomposition is part of planning, not an afterthought at SHIP.** `plan.json.prs` must group
the subtasks into the *smallest set of independently-mergeable PRs* (see the hard rule). Apply the
seam test to each proposed PR — does it compile + test green alone? If the whole goal collapses to
one PR, justify why the layers can't be cut; usually they can (schema+domain core in one PR, the
external-source/cron/infra layer stacked in another). Confirm the PR split with the user alongside
the subtask decomposition.

## Step 2 — EXECUTE + EVALUATE per subtask (the inner loop)

Walk the subtasks in dependency order. For each:

1. **`/ansh-task <id>`** — the specialist reads its packet, runs its conviction gate, then
   implements + self-verifies. (On Sonnet/low-med per the stamp; Deep-stamped items should not
   exist — if one does, split via `/ansh-plan` first.)
   - If it returns **NEEDS_REPLAN** (low conviction or a discovery written to
     `.ansh/discoveries.md`): the specialist does NOT redirect — that's not its job. Route the
     subtask back to **`/ansh-plan`** to fold the discovery into `.ansh/plan.md`/the packet and
     decide direction (escalating to the human if it's a real judgment call). Then re-dispatch the
     (possibly re-split) subtask. Count it against `max_iterations`.
   - If it returns **BLOCKED** (environment/tooling): surface to the user.
2. **`/ansh-review`** for that subtask — scores against its done-criteria and picks the
   evaluation depth (in-session / `review-fresh` / `codex`) using its fresh-eyes rule.
3. Branch on the verdict:
   - **PASS** → next subtask.
   - **REVISE** → feed the specific blockers back to `/ansh-task` (or to `/ansh-plan` if the
     finding is architectural). Re-run. Count it against `max_iterations`.
   - **DEBUG** → `/ansh-debug`: it root-causes, writes fix-subtasks back into the plan, and
     dispatches them through `/ansh-task`. Those new subtasks rejoin this loop.

Track iterations. If a subtask hits `max_iterations` without passing, STOP and surface it —
the plan was probably wrong; route back to `/ansh-plan`.

## Step 3 — Whole-goal evaluation

When all subtasks PASS, do one evaluation against the plan's overall `definition_of_done` (not
just per-subtask criteria). If the goal touches auth / payments / migrations / destructive
surface, run a fresh-eyes pass here regardless of what the subtasks said — `review-fresh` for
no-history Claude eyes, `codex` for a cross-model check. This is the landing gate.

## Step 4 — SHIP (integration branch + small section PRs)

Ship as an integration branch with small section PRs merging into it — never one big PR to `dev`.
1. **Open the umbrella PR once:** `integration-branch → dev`, titled/linked to the epic ticket.
   Keep it as the running sum; it stays open while sections land.
2. **For each section, small-first, in dependency order:** cut a section branch off the integration
   branch, commit its small per-change commits (already made in Step 2, not batched here), and open
   a PR **targeting the integration branch** (`gh pr create --base <integration-branch>`). Keep each
   diff tight (~8–10 files max, one layer/subtask); `/chill-describe` the message. Merge it into the
   integration branch before opening the next dependent section.
3. Apply `/chill-describe` to every commit + PR body (holistic Problem/Fix/Impact, link the section's
   Linear sub-issue inline, no trailers/emoji). If `/ship` re-injects a template, run `git`/`gh`
   manually with compliant text.
4. Post each section PR URL back (note its base = the integration branch). The umbrella PR to `dev`
   merges last, once all sections are in and green.

## Step 5 — RESOLVE (outer loop)

After the PR is up and CI + reviewers have run, invoke `/ansh-resolve` to comb the checks,
automated/human review comments, and Linear comments; triage; dispatch fixes through `/ansh-task`
and bugs through `/ansh-debug`; re-verify green; close the threads. Repeat the outer loop until
checks are green and review is settled.

## Glue (called by name, never forked)

- `effort-dial` — Step 0 right-sizing.
- `chill-describe` — every commit/PR write.
- `lightweight-sql` — when a subtask's diff includes SQL/Drizzle (the specialist calls it).
- `gold-star` — when the user names a reference implementation to hold the work to; surface
  divergence in `/ansh-review`.
- `linear-sync` — optional wrap-up to reconcile the ticket with reality after shipping.

## Termination & completion

The loop ends when the plan's `definition_of_done` is met and `/ansh-resolve` shows checks green +
review settled, OR when `max_iterations` is exhausted (then STOP and report). End with:
- **DONE** — shipped, checks green, review settled, Linear linked.
- **DONE_WITH_CONCERNS** — shipped but open items remain (list them).
- **BLOCKED** — could not proceed (what was tried).
- **NEEDS_CONTEXT** — missing a user decision (state exactly what).

Close with two sentences max: what shipped (PR URL) and anything left open. Don't re-narrate.
