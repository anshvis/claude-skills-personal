---
name: ansh-small-loop
description: ORCHESTRATOR for the Karpathy loop — ONLY for small, scoped tickets. Takes a goal (a Linear ticket or a plain-prose task, not a project) from understanding through shipping using the /ansh- role skills. Conducts plan → execute → evaluate → revise as a real closed loop with explicit termination (all done-criteria pass, or max iterations), decides when to pull in fresh/cross-model eyes, then ships. Calls /ansh-plan (planner), /ansh-task (specialist), /ansh-review (evaluator), /ansh-debug (bug loop), and after push /ansh-resolve (outer loop), wiring in the glue skills (effort-dial, chill-describe, gold-star, linear-sync, lightweight-sql). Runs a scope gate FIRST: a project-scale goal (spans a Linear project/multiple parent tickets, needs product/architecture judgment calls, or the shape of the work genuinely isn't settled) is handed off to /ansh-loop (the project-scale orchestrator, which requires an explicit walk-through of acceptance/exit criteria and runs via dynamic Workflows) instead of run here. Use when the user says "/ansh-small-loop" or hands over a SMALL, SCOPED goal — a single ticket, bugfix, or well-bounded feature — to drive end-to-end. Do NOT use for a project or multi-ticket initiative; that's /ansh-loop.
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
  - mcp__claude_ai_Linear__get_issue
  - mcp__claude_ai_Linear__list_comments
  - mcp__claude_ai_Linear__save_comment
  - mcp__claude_ai_Linear__save_issue
---

# /ansh-small-loop — Orchestrator (small, scoped tickets)

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

- **One worktree per work item, one session per work-stream.** A distinct work item gets its own
  git worktree (sibling of `web-app`, `bun install` in it — never nested inside the repo) — create
  it if none exists for this item, reuse it across that item's subtasks/debug passes/resolve
  passes rather than spinning a fresh one each time. When the goal pivots to a genuinely DIFFERENT
  work-stream (different ticket/epic), prefer a fresh session on that stream's own worktree rather
  than continuing in-place. Worktrees isolate files/branches but NOT conversation context, so
  investigating/editing an unrelated file or branch from the current worktree is how streams drift
  into each other — a quick read-only lookup is fine, edits/branch work are not. (See memory
  `feedback-worktree-and-session-per-task`.)
- **`/chill-describe` is mandatory** before any `git commit` / `gh pr create` / `gh pr edit
  --body`. No co-author trailer, no emoji, no "Generated with" footer.
- **Use an integration branch; land the work as many SMALL PRs that merge into it, not one big
  PR to `main`.** For any non-trivial goal, the ticket's branch (e.g. `rev-746-...`) is a long-lived
  **integration branch** that has exactly one PR → `main` (the umbrella "main" PR for the epic). The
  actual work arrives as a stack of **small section PRs that target the integration branch, not
  `main`** — each one a tight, independently-reviewable diff (a few files: one layer/subtask, e.g.
  the schema+migration, the concept, the resolver, the projector, the fetch, the cron, the alerts).
  A reviewer approves each small section against the integration branch; the umbrella PR to `main`
  is then the sum, already reviewed in pieces. **A section PR does NOT need to compile/ship against
  `main` on its own** — that's the whole point of the integration branch, and it's what lets you cut
  far smaller PRs than "independently mergeable" would allow. Size test: if a section PR touches
  more than ~8–10 files or mixes layers, split it. A 26-file PR to `main` is a failure of this rule.
  Topology: `integration → main` (umbrella); `section-1 → integration`, `section-2 → integration`, …
  (small, merged in order). `/ansh-plan` records the integration branch + the ordered section PRs
  (each → integration) in `plan.json.prs`; the orchestrator opens/merges sections small-first, then
  the umbrella.
- **Commit in small, per-change commits — never one dump at the end.** Each commit is one logical
  change (one migration, one concept, one resolver, one projector, its tests) so any single change
  can be reverted in isolation. Commit as each subtask (or coherent sub-step) verifies green, not
  all at once at SHIP. `/chill-describe` governs the message (short imperative subject).
- **Commit review gate (allow-edits mode) — locally commit, don't push.** When running in
  allow-edits / accept-edits (auto-accept) mode, do NOT push or open a PR without approval. But DO
  commit each section locally as soon as it verifies green — small, per-change commits, same shape
  as the rule above — rather than leaving the diff sitting uncommitted in the working tree. A local
  commit is cheap to amend/revert and costs nothing to make; leaving work uncommitted is what turns
  a routine worktree cleanup into real data loss (this is exactly how the FND-1715 plumbing work
  was lost before this run). Hand back with the branch showing real commits for the user to review
  in their source-control editor; push + PR only after they approve.
- Never push to `main`/`master`. Work on the branch `/ansh-plan` proposes — which, when a Linear
  ticket exists, follows `<tag-lower>-<slug>` derived from the **parent/epic** ticket (e.g.
  `rev-669-availability-request-integration`), one branch per PR. Don't invent a generic branch
  name when a ticket exists, and don't name section branches after child tickets (see the linking
  rule below — branch name is what Linear auto-attaches on).
- **Linear status flows with the work.** The planner moves the parent/epic to In Progress when
  work begins. Let the GitHub integration move `In Review`/`Done` — the loop never sets those by
  hand. At SHIP, link the **parent** ticket inline in the PR body (e.g. "Closes <PARENT>"), per
  `/chill-describe`.
- **ALL PRs link to the PARENT ticket — never to child tickets.** Child/sub-issues exist to scope
  and plan the work, not to collect PR links; attaching a PR to each child crowds the board and
  scatters the lineage. So:
  - Every section PR **and** the umbrella PR attach to the **same parent/epic ticket**, under the
    parent's name. That keeps stacking and lineage clean — one ticket shows the whole PR series in
    order.
  - **Section branches are named off the parent ticket**, `<parent-tag-lower>-<slug>` where `slug`
    describes the *section* (e.g. parent `REV-1157` → `rev-1157-payrule-thresholds`,
    `rev-1157-hours-accumulator`). Linear auto-links on the branch name, so a child-named branch
    silently attaches to the child — this is the rule that actually enforces the convention.
  - Only the **parent** id goes in magic-word position ("Closes REV-1157"). Reference the child in
    the PR body as **plain text for traceability** (e.g. "Scope: REV-1163 (hours calculator)") —
    plain text, never a magic word, so it reads as context without creating an attachment.
  - Never fabricate ticket numbers. Children still get created by the planner for scope/planning;
    they just don't receive PR links.
  - (A trivial single-ticket goal has no children — the one ticket is the parent.)
- Honor every STOP point in the sub-skills. Surface their `AskUserQuestion` gates; don't auto-decide.
- **Never commit the `.ansh/` working dir, and never add it to the tracked `.gitignore`.** Keep it
  out of git via the local exclude only:
  `grep -qxF '.ansh/' "$(git rev-parse --git-path info/exclude)" || printf '\n.ansh/\n' >> "$(git rev-parse --git-path info/exclude)"`.
  Same for any agent-local scratch — local exclude, not the committed `.gitignore`.
- The loop must **terminate**. Respect `termination.max_iterations` from the plan. If the bar
  isn't met after max iterations, STOP and report — don't spin.

## Step -1 — Scope gate (does this even belong in the small loop?)

**`/ansh-small-loop` is for small, scoped tickets — not projects.** Run this check before
anything else, including `effort-dial`. Effort-dial asks "how hard should I think about this
scoped task"; this gate asks a prior question — "is this actually one scoped task, or a project
whose shape is Ansh's call to make?" A goal can be 🔴 Deep on the effort dial and still correctly
stay in this loop (a gnarly bug, a tricky migration) — Deep is about difficulty, not about who
should be deciding the shape of the work.

Any ONE of these is enough to trigger the fallback:
- The goal is a Linear **project**, spans **multiple parent/epic tickets**, or is phrased as an
  initiative/roadmap item rather than one ticket or one clearly-scoped ask.
- Decomposing it requires a **product or architecture judgment call that materially shapes
  downstream work** — a new data model, a new subsystem/service boundary, a cross-team
  dependency, a build-vs-buy or sequencing call with no obviously-correct answer.
- The estimate is genuinely **multi-week**, not "a few PRs."
- Working through Phase 3.5 of `/ansh-plan` (the packet-readiness checklist) would fail for
  **most** subtasks not because they need more research, but because **the shape of the work
  itself isn't settled yet** — there's a design decision upstream of any subtask list.

If none of these hold, this is a scoped ticket — proceed to Step 0 below.

If any hold: **STOP. Do not invoke `/ansh-plan` or run any part of this loop.** This is exactly
the situation where autonomous decomposition would guess at calls that are Ansh's to make, and a
plan built on a guessed shape is expensive to unwind later. Say so plainly, then offer, via
`AskUserQuestion`:

- **A) Hand off to `/ansh-loop`** (recommended for genuine projects) — the project-scale
  orchestrator. It runs `/ansh-plan` for the whole goal, requires Ansh to explicitly walk through
  and sign off on the resulting guardrails/acceptance/exit criteria before anything executes, then
  fans out via dynamic Workflows. This is the default answer for a project-shaped ask.
- **B) Shape it together first** — talk through the architecture/scope/sequencing in
  conversation now, with Ansh driving the direction; once the shape is settled, hand the
  *resulting scoped pieces* to `/ansh-small-loop` one at a time (or the whole thing to
  `/ansh-loop` if it's still project-sized once shaped).
- **C) Run `/ansh-plan` anyway, but as a flagged interactive pass** — it decomposes as usual,
  but stops after Phase 3 (before persisting packets) for Ansh to review and redirect the
  decomposition itself, not just answer clarifying questions. Only pick this if Ansh wants a
  first draft to react to rather than starting from a blank page.
- **D) Split off the first scoped slice now** — carve out one clearly-bounded piece of the
  project that IS ready to decompose, defer the rest, and only run this loop on that piece.

Do not auto-pick an option. This is the one decision in the whole skill that is never the loop's
to make silently.

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
2. **`/ansh-review`** for that subtask — scores against its done-criteria. It runs a **cross-model
   Codex review pass by default on every evaluation** (that's where the real bugs surface), and adds
   `review-fresh` / `swarm` on top when the fresh-eyes stamp or risk calls for it.
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
just per-subtask criteria). This landing-gate evaluation runs the **cross-model Codex pass** like
every other review; if the goal touches auth / payments / migrations / destructive surface, ALSO
run `review-fresh` (no-history Claude eyes) on top for a second independent read. This is the
landing gate.

## Step 4 — SHIP (integration branch + small section PRs)

Ship as an integration branch with small section PRs merging into it — never one big PR to `main`.
1. **Open the umbrella PR once:** `integration-branch → main`, titled/linked to the parent/epic
   ticket. Keep it as the running sum; it stays open while sections land.
2. **For each section, small-first, in dependency order:** cut a section branch off the integration
   branch — named `<parent-tag-lower>-<section-slug>`, never after a child ticket — commit its small
   per-change commits (already made in Step 2, not batched here), and open a PR **targeting the
   integration branch** (`gh pr create --base <integration-branch>`). Keep each diff tight (~8–10
   files max, one layer/subtask); `/chill-describe` the message. Merge it into the integration branch
   before opening the next dependent section.
3. Apply `/chill-describe` to every commit + PR body (holistic Problem/Fix/Impact, no trailers/emoji).
   **Link the PARENT ticket only** in magic-word position ("Closes <PARENT>"); name the section's
   child ticket as plain-text scope context, never as a link/magic word. Every PR in the series —
   sections and umbrella — attaches to that same parent, so the ticket shows the whole stack in
   order. Create/update PRs directly with `git push` + `gh pr create` / `gh pr edit --body` — if
   a PR template gets auto-injected into the body, overwrite it with the chill-describe-compliant
   text before handing the URL back.
4. Post each section PR URL back (note its base = the integration branch). The umbrella PR to `main`
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
