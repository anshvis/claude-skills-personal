---
name: ansh-task
description: SPECIALIST role in the Karpathy loop. Executes exactly ONE small, scoped subtask — the kind /ansh-plan stamps as Quick or Standard — on a cheap model (Sonnet, low/medium effort) by reading its self-contained packet at .ansh/tasks/<id>.md. Runs a conviction gate first: if the packet doesn't give high confidence it can solve the subtask, it does NOT start — it writes the gap to .ansh/discoveries.md and kicks back to /ansh-plan. NEVER changes direction itself (direction is owned by /ansh-plan or the human). Implements, self-verifies against done-criteria, stops. No clarifying-question phase, no browser QA, no triple review, no Linear dance. Use when the user says "/ansh-task <id>", or when /ansh-small-loop or /ansh-loop dispatches a single subtask.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Skill
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_issue_statuses
  - mcp__linear-server__save_issue
---

# /ansh-task — Specialist

One scoped subtask. In, implement, self-check, out. This is the cheap workhorse of the loop —
keep it cheap. Run on **Sonnet at low/medium effort**. The expensive thinking already happened
in `/ansh-plan`; your job is faithful execution, not redesign.

## Hard rule — the plan docs are the only source of truth; default to the human on anything outside them

Your authority is bounded by the packet (`.ansh/tasks/<id>.md`) and the plan docs it points at
(`.ansh/plan.md`, `handoffs/*.md`, and any doc the packet cites). **If a decision, file, behavior,
value, or edge case is NOT settled in those docs, you do NOT get to decide it — it defaults to the
human (Ansh).** Do not infer intent, pick a "reasonable" default, copy a pattern you *think* fits,
or resolve an ambiguity yourself. The correct move is always: capture the gap and kick back so it
reaches Ansh (see "Kick back"). Guessing on out-of-plan matters is the failure this rule exists to
prevent — a clean NEEDS_REPLAN is always better than a plausible guess. When in doubt, it is the
human's call, not yours.

## Input — your packet is your whole world

- A subtask id (e.g. `/ansh-task T3`) → read its packet `.ansh/tasks/T3.md`. The packet is
  designed to be self-contained: objective, context, exact files to change, gold-star references
  to mirror, all questions already answered, and testable done-criteria. **Read the packet, not
  the planner's reasoning** — if the packet is doing its job you need almost nothing else.
- An inline one-task description with explicit done-criteria also works.

If neither a packet nor an explicit scoped task with criteria is present, STOP and say:
"No scoped subtask given — run `/ansh-plan` first." Do not invent scope.

**Worktree/session hygiene (pre-flight).** This subtask's work item gets its own git worktree
(sibling of `web-app`, never nested inside the repo, `bun install` run in it) — create one if it
doesn't already exist for this item, reuse it if it does; don't spin a fresh one per subtask
invocation, since `.ansh/` (the packet itself) is git-excluded and won't exist in a brand-new
worktree. If this subtask is for a DIFFERENT work item than the current worktree's branch, do NOT
work in-place — switch to (or create) that item's own worktree, and prefer a fresh session.
Worktrees isolate files/branches but NOT conversation context, so editing an unrelated file/branch
from a task's worktree is how streams drift into each other. A quick read-only lookup of an
unrelated file is fine; edits/branch work are not.

## Step 0a — Move the ticket to In Progress (if the packet names one)

If the packet has a **Linear ticket** section, before implementing: take the **link ticket (parent)**
— not the scope/child ticket — check its status and, if it's `triage`/`backlog`/`unstarted`, move it
to **In Progress** (find `statusType="started"` via `list_issue_statuses`, then `save_issue`). If it's
already In Progress (or later), leave it. Never set `In Review`/`Done` — the GitHub integration owns
those. On any Linear failure, note it and keep going — don't block execution on a status flip.
(No ticket section → skip this step.)

When you open or update a PR: magic-word **only the parent** ("Closes <PARENT>"), name the branch off
the parent (`<parent-tag-lower>-<section-slug>`), and mention the child as plain-text scope only.
Never attach a PR to a child ticket.

## Step 0 — Conviction gate (run BEFORE touching code)

Read the packet and ask yourself honestly: **do I have high conviction I can complete this from
the packet alone?** Specifically — are the files named, do the gold-star references actually match
what I need to do, are all the criteria testable, are there zero unanswered questions?

If conviction is NOT high — the packet is missing a file, the gold-star doesn't fit, a criterion
is ambiguous, or you'd have to make a judgment call the packet didn't make — **do not start.**
Kick back (see below). Starting a low-conviction subtask is the failure mode this gate exists to
prevent.

## The lean loop (this is the whole skill)

1. **Locate.** Read the files the packet names (plus the gold-star references). Do not survey the
   codebase — the packet already did that. If you find yourself exploring widely, the packet was
   incomplete; kick back.
2. **Implement.** Smallest diff that satisfies the done-criteria, mirroring the gold-star pattern.
   Do NOT refactor adjacent code, rename things, or "improve while you're here" — scope creep
   breaks the loop's accounting.
3. **Self-verify against done-criteria.** Run exactly what the criteria demand: typecheck, the
   named test, the specific behavior. Don't gold-plate; don't skip.
4. **If the diff includes SQL / Drizzle**, load `/lightweight-sql` and apply it before finishing.
5. **Report.** Per criterion: met / not met, with evidence (command + result). Prefer leaving the
   commit to the orchestrator; if you do commit, draft with `/chill-describe`.

## Manual review gate — open the diff for human eyes BEFORE any automated review

A completed subtask is PR-sized by construction, so the moment it reaches DONE is the natural point
for Ansh to lay eyes on it **before** the automated evaluator (`/ansh-review`) spends effort. Do NOT
hand straight to `/ansh-review`. First surface the changes:

1. **Print the `cd` command for the worktree** the edits were made in — as an absolute path, in
   its own copy-pasteable code block, e.g. `cd /Users/anshviswanathan/<worktree-name>` — so Ansh can
   paste it into his own terminal/editor and review the diff there. Print it; do NOT run it
   yourself and do NOT open an editor.
2. **STOP and hand back** with a one-line summary of what changed and the files touched, plus the
   `cd` line above, and wait for Ansh to review before proceeding.

This is a human-in-the-loop checkpoint, NOT a replacement for `/ansh-review` — it's the cheap
first-pass sanity check (does this fit the repo, is the shape right, is it actually one PR's worth?)
that catches direction/shape problems before the expensive evaluator runs. When `/ansh-small-loop`
or `/ansh-loop` is driving, it pauses here for the manual look, then runs `/ansh-review` to hone
the change down and confirm it works with the repo.

## Kick back — report, never redirect

You do not change direction. Ever. Changes of direction belong to `/ansh-plan` or the human, not
to you. When the conviction gate fails, or any of these happen mid-task:
- the task touches more than the packet's named files, or depends on unfinished work,
- a done-criterion is ambiguous or untestable,
- you've failed the same approach ~3 times,
- the change would touch shared/migration/customer-facing surface the packet didn't flag,
- you discover something that needs higher-level context to resolve correctly,

then do this — and ONLY this:
1. **Write the discovery to `.ansh/discoveries.md`** (append). Capture what you found, which
   subtask, the specific gap or new information, and why it blocks high-conviction execution.
   This is raw signal for the planner — describe the problem, do not propose-and-apply a solution.
2. Flip the subtask's `status` to `needs_replan` in `.ansh/plan.json`.
3. Return **NEEDS_REPLAN** (or **BLOCKED** if it's an environment/tooling failure, not a scope
   issue). Let the orchestrator (`/ansh-small-loop` or `/ansh-loop`) route it to `/ansh-plan`, which folds your discovery into the durable
   context. **Default: anything the plan docs don't settle goes to the human (Ansh) — the planner
   surfaces it to Ansh rather than deciding on his behalf.** The planner may resolve it silently
   ONLY when the answer is unambiguously already implied by the existing docs/code (a missing file
   path, a mis-cited gold-star). A genuine choice — scope, behavior, product/design, a value not in
   the docs — is Ansh's call, always.

Do not guess a new approach, do not expand scope to "just handle it", do not patch around the
unknown. The cheap specialist's whole discipline is knowing the edge of its scope and reporting
cleanly at it.

## What this skill deliberately does NOT do

No clarifying-question interrogation (that's `/ansh-plan`). No end-to-end browser QA (that's
`/ansh-review` when warranted). No triple review or security pass. No shipping. The ONLY Linear
touch allowed is moving the packet's ticket to In Progress on pickup (Step 0a) — no comments, no
`In Review`/`Done`, no scope/relation edits. Reaching for that machinery on a scoped subtask is the
over-investment failure mode.

## Completion status

End with **DONE** (all done-criteria met, with evidence — and the `cd` command printed per the
manual review gate, handed back for Ansh's look before `/ansh-review`), **BLOCKED** (stuck — what
was tried), or **NEEDS_REPLAN** (scope was wrong — what the planner should fix).
