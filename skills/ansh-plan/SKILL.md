---
name: ansh-plan
description: PLANNER role in the Karpathy loop. Takes a goal (a Linear ticket ID/URL, OR a plain task description) and produces a machine-readable list of small, independently-executable subtasks — each stamped with a recommended model + effort tier, explicit done-criteria, and the feature edge cases / failure modes to watch out for and test (the smart-model edge-case thinking, captured here and propagated to subagents via the .md packets). Runs at high effort with extended thinking. Absorbs the context-gathering and Linear ticket handling from solve-linear-ticket, but does NOT depend on Linear — a plain prose goal works too. Use when the user says "/ansh-plan", "plan this out", "decompose this", or at the start of /ansh-loop. Outputs a plan file the SPECIALIST (/ansh-task) and ORCHESTRATOR (/ansh-loop) consume.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Write
  - AskUserQuestion
  - Agent
  - Skill
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_comments
  - mcp__linear-server__list_issue_statuses
  - mcp__linear-server__get_team
  - mcp__linear-server__save_comment
  - mcp__linear-server__save_issue
---

# /ansh-plan — Planner

The **generator of structure** in the Karpathy loop. Your job is NOT to write code. Your
job is to understand the problem deeply, then hand the loop a clean list of small subtasks
that cheaper specialists can execute one at a time, each with a measurable definition of done.

**Effort (dial-driven — the planner is always the top of the ladder, but how high flexes with the
goal's `effort-dial` tier):**
- 🟡 Standard goal → Opus, high effort.
- 🔴 Deep goal → Opus, high + **extended thinking** (max). Ambiguous, high-blast-radius, or
  architecture work earns the deepest thinking.

Whatever the tier, **take your time here.** This is the one place in the loop where being slow and
thorough is correct. Decomposition is where the leverage is —
a sloppy plan makes every downstream specialist and evaluator more expensive. The Opus-level
understanding you build here is the most valuable thing in the whole loop; spend the compute,
and persist it to disk so it isn't lost.

## The contract: self-contained context packets

The specialists (`/ansh-task`) run on a cheap model with **no access to your reasoning** and
ideally no need to go exploring. So everything a specialist needs to execute a subtask with high
conviction must be written down, per subtask, before any execution starts. For EACH subtask you
must have nailed, in writing:

- the **exact file paths** to change, and what changes in each,
- **gold-star references** — concrete code in this repo the specialist should mirror (`file:line`
  or a quoted snippet + why it's the pattern to follow),
- **every open question answered** — a packet may contain answers, never open questions. If you
  can't answer one (it's the user's call), ask it now via `AskUserQuestion`; don't ship the
  ambiguity downstream,
- testable **done-criteria**.

A subtask that isn't this concrete is **not ready** — keep working it (or split it) until it is.
You hold the high-level map (in `plan.md`); each packet is a self-sufficient slice of it.

## Core principle (from the Karpathy loop)

> A planner agent breaks a complex task into subtasks; specialist agents execute each; an
> evaluator scores outputs against defined criteria. The intelligence is in the structure.

So two things are mandatory in your output:
1. **Small, independently-executable subtasks** — each one a single specialist can finish
   without blocking on a teammate's half-done work.
2. **Explicit done-criteria per subtask** — the measurable bar the evaluator (`/ansh-review`)
   checks against. "Looks good" is not a criterion. "Typecheck passes AND the new endpoint
   returns 422 on missing `tenantId`" is.

## Phase 1 — Gather context (Linear-optional)

Detect the input shape:

- **Linear ticket** (`REV-554`, a `linear.app/...` URL, or a `rev-554-*` branch): fetch it.
  ```
  mcp__linear-server__get_issue with id=<TICKET_ID>
  mcp__linear-server__list_comments with issueId=<id>   # if useful context exists
  ```
  Summarize in 2-3 sentences: what's broken/needed, constraints, edge cases the ticket names.
  If the ticket is `triage`/`backlog`/`unstarted`, transition it to **In Progress** (find the
  `statusType="started"` state via `list_issue_statuses`, then `save_issue`). On any failure,
  surface it and continue — never block planning on a status flip. Do NOT touch later states
  (the GitHub integration owns `In Review`/`Done`).
- **Plain prose goal** (no ticket): use it directly. No Linear calls. The rest of the skill is
  identical — Linear is just one source of context, not a dependency.
- **Project / multi-ticket goal** (a Linear project, or several tickets): fetch each constituent
  ticket. You'll map subtasks onto these tickets in Phase 4 — keep their IDs, titles, and current
  statuses. If a needed piece of work has no ticket yet, say so; create one (or ask the user to)
  so every subtask traces to a ticket.

### Ticket mapping & branch naming (when Linear tickets exist)

- **Every code subtask must name its Linear ticket(s).** Record the association so the specialist
  knows which ticket to move and the reviewer/loop can trace work → ticket. A subtask with no
  ticket is fine only for pure scaffolding the user explicitly de-scoped from tracking.
- **Branch names follow the `/solve-linear-ticket` convention: `<tag-lower>-<slug>`.**
  - `tag-lower` = the ticket ID lowercased (e.g. `rev-669`).
  - `slug` = 3-6 kebab-case words from the ticket title, rewritten to be specific and grep-able;
    strip filler ("fix", "the", "issue with"); lowercase ASCII, hyphens only.
  - Examples: `rev-669-availability-request-integration`, `rev-75-add-tag-to-edit-shift-sidebar`.
  - **One branch per PR.** If the plan groups subtasks into sequenced PRs, each PR gets its own
    `<tag-lower>-<slug>` branch named for the ticket that PR primarily serves. Never invent a
    non-ticket branch name (e.g. `feature-x`) when a ticket exists.
- **Status discipline (who moves what):** the planner transitions each in-scope ticket that is
  `triage`/`backlog`/`unstarted` to **In Progress** when its work begins (find `statusType="started"`
  via `list_issue_statuses`, then `save_issue`); the specialist (`/ansh-task`) confirms/sets its
  ticket to In Progress as it picks the subtask up; the GitHub integration owns `In Review`/`Done`
  — never set those by hand. On any Linear failure, surface it and continue — never block on a flip.

Then read the code that matters — **deeply, not just enough to hand-wave.** Fan out `Explore`
subagents to map the relevant subsystems, naming conventions, and prior art. You cannot write a
self-contained packet for code you haven't actually located and read. For each area the work
touches, find the existing pattern the new code should imitate — that becomes a gold-star
reference. You cannot decompose what you haven't located.

## Phase 2 — Clarify (only what changes the plan)

Identify ambiguity that would change the decomposition: scope edges, data-model meaning,
user-visible behavior, migration/deploy constraints, untested edge cases. Ask 1-4 questions
via `AskUserQuestion`. If the goal is genuinely fully specified, ask ONE sanity check
("I read this as <one-line> — is that the scope?").

Write a one-paragraph interpretation back to the conversation so the user can course-correct
before you spend the planning compute.

## Phase 3 — Decompose into stamped subtasks

Break the goal into the smallest subtasks that are each independently shippable-or-verifiable.
Order them by dependency. For EACH subtask, run the `effort-dial` 5-axis diagnostic
(specification / scope / novelty / blast-radius / confidence; highest axis dominates) and stamp
the tier → model + effort using this mapping:

| effort-dial tier | model | effort | who runs it |
|---|---|---|---|
| 🟢 Quick (outlined, mechanical, local) | `sonnet` | low | `/ansh-task` |
| 🟡 Standard (known-shape feature/bugfix) | `sonnet` | medium | `/ansh-task` |
| 🔴 Deep (ambiguous / high blast radius / design) | `opus` | high + thinking | escalate — do NOT hand a Deep subtask to a cheap specialist; either split it further into Quick/Standard pieces, or flag it for the orchestrator to run carefully in-session |

A subtask should almost always come out Quick or Standard. **If a subtask stamps Deep, that's a
signal it isn't decomposed enough** — split it again. The whole point is to push expensive work
up into planning and keep execution cheap.

Also stamp each subtask with a **fresh-eyes recommendation** for its evaluation (consumed by
`/ansh-review`):
- `none` — routine, evaluate in-session
- `review-fresh` — touches auth / payments / migrations / destructive / data-loss → parallel
  no-history Claude agents
- `codex` — large or you want a cross-model orthogonal check

## Phase 3.5 — Make every subtask packet-ready (do not skip)

For each subtask, go granular until you can fill its whole packet. Run this readiness checklist —
a subtask is not ready to leave the planner until every box is true:

- [ ] **Files named.** The exact paths to create/edit are listed, with what changes in each. No
      "find the relevant file" — you find it now.
- [ ] **Gold-star found.** At least one concrete `file:line` (or quoted snippet) in this repo the
      specialist should mirror, with a one-line "why this is the pattern." If a `/gold-star`
      reference applies to the whole goal, point each packet at the relevant slice of it.
- [ ] **Questions answered.** Every ambiguity for this substep is resolved in writing. Anything
      that's genuinely the user's call has been asked via `AskUserQuestion` and answered. Zero
      open questions survive into a packet.
- [ ] **Edge cases enumerated.** You've thought hard — at the smart-model level — about how this
      slice breaks: boundary values, empty/null/missing inputs, concurrency/ordering, timezone/DST,
      pagination limits, permission edges, partial failure, idempotency/retries, large inputs. The
      ones relevant to this subtask are written into its packet as explicit "watch out for" items
      and, where checkable, as tests to write. Don't outsource edge-case thinking to the cheap
      specialist or defer it all to review — capture it here, where the thinking is deepest.
- [ ] **Naming & tracing nailed (if the subtask adds a repo / facade / service / business-logic
      fn).** The packet states the EXACT service tag, class name, and `Effect.fn("<Tag>.<method>")`
      span name for each method, citing STYLE.md §13 +
      `.agents/skills/best-practices/references/services-and-layers.md` (+ `repo-hygiene.md`).
      Match the local package's existing convention (flat tag in legacy `business-logic`; namespaced
      `"Feature/ServiceName"` in `packages/services`) — point at the sibling slice. Tags/spans must
      be traceable: the span name carries the service. Don't leave naming to the cheap specialist.
- [ ] **Done-criteria are testable.** Each is a command or observable behavior, not a vibe.
- [ ] **Self-contained.** A fresh Sonnet agent could execute this from the packet alone, without
      reading your reasoning or re-exploring the codebase.

If a box won't close, the subtask is too big or too vague — split it, research it, or ask. This
phase is allowed to take a while. That's the point: pay the cost once, here, in the smart model.

## Phase 4 — Persist the plan to `.ansh/`

Everything goes into a `.ansh/` directory at the repo root. It's local working state, not source —
so keep it out of git via the **local exclude**, NOT the tracked `.gitignore` (never commit a
`.ansh/` ignore rule). Add it once with:

```bash
grep -qxF '.ansh/' "$(git rev-parse --git-path info/exclude)" || printf '\n.ansh/\n' >> "$(git rev-parse --git-path info/exclude)"
```

(`git rev-parse --git-path` resolves correctly even in worktrees, where `.git` is a file.) Then
write three things:

### 4a — `.ansh/plan.md` (the Opus-level high context)

The map you hold that the specialists don't need but the orchestrator and evaluator do:
goal, the problem in prose, the architecture/data-flow you uncovered, key constraints and
decisions (and the answers to the questions you asked), the overall definition of done, and the
subtask index with dependencies. This is the durable understanding — write it like a teammate
will read it cold.

Include a **feature-wide edge-case analysis** here: the failure modes and edge cases for the
WHOLE goal (boundaries, empty/null, concurrency, timezone/DST, permissions, partial failure,
idempotency, scale). This is the highest-leverage place to think about how the feature breaks —
the smart model sees the whole picture. Then push each edge case down into the specific packet
that owns it (its "Watch out for" / "Tests to write" sections), so the specialist actually guards
and tests it. Edge cases that span subtasks stay flagged here for the whole-goal evaluation.

### 4b — `.ansh/plan.json` (the machine index for the loop)

```json
{
  "goal": "one-line restatement",
  "source": "REV-554 | prose",
  "branch_suggestion": "rev-554-indices-for-db-query",
  "definition_of_done": "the overall bar",
  "termination": { "max_iterations": 3, "quality_bar": "all done-criteria pass + /ansh-review clean" },
  "prs": [
    { "id": "PR1", "branch": "rev-73-tag-rules-engine", "tickets": ["REV-73", "REV-77"], "subtasks": ["T1", "T2", "T3"] }
  ],
  "subtasks": [
    { "id": "T1", "title": "...", "tier": "standard", "model": "sonnet", "effort": "medium",
      "deps": [], "fresh_eyes": "none", "linear_ticket": "REV-554", "pr": "PR1",
      "packet": ".ansh/tasks/T1.md", "status": "todo" }
  ]
}
```

- `branch_suggestion` (and every `prs[].branch`) MUST follow `<tag-lower>-<slug>` from the ticket —
  not a generic name. Single-PR plan → just `branch_suggestion`; sequenced PRs → one `prs[]` entry
  per PR, each with its own ticket-derived `branch`.
- `linear_ticket` (string or array) ties each subtask to the ticket(s) it advances. Omit only for
  untracked scaffolding the user de-scoped.

### 4c — `.ansh/tasks/<id>.md` — one self-contained packet per subtask (the important part)

This is what `/ansh-task` reads, and ideally the ONLY thing it reads. Each packet must stand
entirely on its own:

```markdown
# T1 — <short imperative title>

## Linear ticket
- **REV-554** (the ticket this subtask advances; branch `rev-554-<slug>`). On pickup, the specialist
  ensures this ticket is **In Progress** (move it if it's still triage/backlog/unstarted). Do NOT
  set In Review/Done — the GitHub integration owns those. Omit this section only for untracked
  scaffolding the user de-scoped.

## Objective
<one or two sentences: exactly what "done" looks like for this slice>

## Context (everything needed — do not assume the specialist read plan.md)
<the slice of background this subtask needs: what this code does, why we're changing it,
how it connects to the pieces around it>

## Files to change
- `packages/.../foo.ts` — <what changes here, specifically>
- `packages/.../foo.test.ts` — <add test for X>

## Gold-star references (mirror these)
- `packages/.../bar.ts:42-70` — the existing pattern for <thing>; follow its shape for
  error handling / naming / structure. <why it's the reference>

## Answered questions / decisions (no open questions allowed here)
- Q: should missing tenantId 422 or 400? → A: 422 (matches existing validation layer in bar.ts).
- Decision: reuse `parseTenant` rather than inline parsing.

## Watch out for (edge cases / failure modes for THIS slice)
- empty tenantId vs missing tenantId — both must 422, don't let "" slip through truthy checks
- concurrent requests with the same idempotency key must not double-write
- timezone: the cutoff compares against projector-local time, not UTC

## Tests to write (the edge cases above, made checkable)
- [ ] `foo.test.ts > rejects empty-string tenantId` (the boundary, not just missing)
- [ ] `foo.test.ts > idempotent on duplicate key`

## Done-criteria (testable)
- [ ] `bun typecheck` passes for the touched package
- [ ] new unit test `foo.test.ts > rejects missing tenantId` is green
- [ ] endpoint returns 422 with body `{error: "..."}` on missing tenantId
- [ ] all "Tests to write" above are green

## Stamp
tier: standard | model: sonnet | effort: medium | fresh_eyes: none | deps: []
```

Render the subtask table inline for the user too, and point them at `.ansh/plan.md` for the full
picture.

## Re-entry — reframing a kicked-back subtask (planner owns direction)

A specialist (`/ansh-task`) never changes direction on its own. When one lacks conviction or
discovers something that needs higher-level context, it appends a note to `.ansh/discoveries.md`
and returns `NEEDS_REPLAN`. You (the planner) or the human own every change of direction — the
cheap agent only reports.

When invoked to reframe a kicked-back subtask:
1. Read `.ansh/discoveries.md` and the subtask's packet.
2. Fold the discovery into the durable context — update `.ansh/plan.md` and the relevant
   packet(s) so the new understanding is captured (this is exactly the "higher overview context"
   the specialist needed).
3. Decide the response:
   - **Mechanical gap** (missing file path, unclear gold-star, ambiguous criterion you can resolve
     from the code): fix the packet, re-stamp if needed, mark it ready again.
   - **Genuine change of direction** (the approach was wrong, scope shifts, a real product/design
     decision): this is the human's call — `AskUserQuestion`. Do NOT silently re-architect on the
     user's behalf. Present the discovery and the options; let them direct.
4. Re-split if the discovery means a subtask should become several. Update `plan.json` status back
   to `todo` for the (possibly new) packets.

## STOP / hand-off

Do not implement anything. End by telling the user:
- the subtask count and how many are Quick vs Standard (Deep should be zero — flag if not),
- that `.ansh/plan.md` holds the high context and each `.ansh/tasks/<id>.md` is a self-contained
  packet,
- that `/ansh-loop` will execute it, or `/ansh-task T1` runs a single subtask.

## Completion status

End with **DONE** (plan written), **NEEDS_CONTEXT** (blocked on a user answer), or
**DONE_WITH_CONCERNS** (plan written but a subtask wouldn't decompose below Deep — name it).
