---
name: ansh-plan
description: "Plan a goal or Linear ticket into small, self-contained task packets with capability profiles, effort, dependencies, done-criteria and edge cases. Write guardrails, acceptance and exit criteria, then challenge the plan before handoff. Use for /ansh-plan, planning or decomposition; do not execute without the workflow's authorization gates."
---

# /ansh-plan — Planner

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

The **generator of structure** in the Karpathy loop. Your job is NOT to write code. Your
job is to understand the problem deeply, then hand the loop a clean list of small subtasks
that scoped specialists can execute one at a time, each with a measurable definition of done.

**Effort (dial-driven — the planner is always the top of the ladder, but how high flexes with the
goal's `effort-dial` tier):**
- 🟡 Standard goal → GPT-6 Astra, high effort.
- 🔴 Deep goal → GPT-6 Astra, high + **extended thinking** (max). Ambiguous, high-blast-radius, or
  architecture work earns the deepest thinking.

Whatever the tier, **take your time here.** This is the one place in the loop where being slow and
thorough is correct. Decomposition is where the leverage is —
a sloppy plan makes every downstream specialist and evaluator more expensive. The reasoning-tier
understanding you build here is the most valuable thing in the whole loop; spend the compute,
and persist it to disk so it isn't lost.

## The contract: self-contained context packets

The specialists (`/ansh-task`) use the runtime-selected model with **no access to your reasoning** and
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
  Linear capability `get_issue` with id=<TICKET_ID>
  Linear capability `list_comments` with issueId=<id>   # if useful context exists
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
  - **One branch per PR, named off that PR's primary ticket**: the child it closes, or the one it
    mostly advances (`<primary-tag-lower>-<section-slug>`). Linear auto-attaches on branch name, so a
    parent-named section branch stacks every PR onto the parent. Use the parent's tag only for the
    parent's own work (a goal with no children, or the umbrella PR). Never invent a non-ticket branch
    name (e.g. `feature-x`) when a ticket exists.
- **Each PR links to every ticket its own diff advances.** Write `Closes <ID>` for a ticket the PR
  finishes, and `Part of <ID>` for one it advances. A chain PR links only its own tickets, never the
  ones its dependency branches carry, and names those PRs as `Depends on #<n>`. The parent is plain
  text on section PRs. It shows the work through its sub-issues. Full rule: `/ansh-small-loop`
  Hard rules. Record the links per PR in `prs[].links` so the loop never infers them.
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

## Phase 2.5 — Guardrails + acceptance/exit criteria (goal-level, do not skip)

Before decomposing, write down the three lists that let a project-scale run be handed to
`/ansh-loop` and signed off on without you in the room. These are goal-level (once per plan), not
per-subtask — a subtask's existing testable done-criteria already are its acceptance bar; don't
duplicate a parallel list there. Keep the three genuinely distinct:

- **`guardrails`** — boundaries this work must never cross, independent of whether it's "done."
  Out-of-scope areas explicitly ruled out, "no schema change without a migration review," "no
  writes to prod outside the standard pipeline," compliance/security lines, things the user said
  not to touch. If nothing unusual applies, still write the baseline ones (never push to
  `main`/`master`, never touch `.ansh/` into tracked git, etc. — inherited from the loop's hard
  rules, but restate anything goal-specific).
- **`acceptance_criteria`** — the goal-level, product/user-facing bar: what makes this genuinely
  done from the requester's perspective, not just what's mechanically testable. Write these as
  the answer to "how would a human verify this shipped correctly," pulling from the ticket/prose
  goal and anything surfaced in Phase 2 clarification. Distinct from `definition_of_done` (which
  stays as the one-line prose summary) — this is the itemized, presentable list a human confirms
  before execution.
- **`exit_criteria`** — the conditions that stop the loop regardless of whether acceptance
  criteria are met: max iterations exhausted, a guardrail tripped, blocked on a human decision,
  a whole-goal evaluation failing twice. These are what `termination.max_iterations` becomes when
  written out as human-legible stop conditions, plus anything else specific to this goal's risk
  profile (e.g. "stop if the migration touches a table with no rollback path").

These three lists are read verbatim by `/ansh-loop`'s Step 1 human sign-off gate for
project-scale goals — write them so they can be presented item by item, not as prose paragraphs.
`/ansh-small-loop` doesn't gate on them the same way, but still benefits from having them written
down; never skip this phase because the goal looks small — let the Step -1 scope gate in the
orchestrator, not this phase, decide which loop runs.

## Phase 3 — Decompose into stamped subtasks

Break the goal into the smallest subtasks that are each independently shippable-or-verifiable.
Order them by dependency. For EACH subtask, run the `effort-dial` 5-axis diagnostic
(specification / scope / novelty / blast-radius / confidence; highest axis dominates) and stamp
the tier → model + effort using this mapping:

| effort-dial tier | model | effort | who runs it |
|---|---|---|---|
| 🟢 Quick (outlined, mechanical, local) | `gpt-6.1-sol` | high | `/ansh-task` |
| 🟡 Standard (known-shape feature/bugfix) | `gpt-6.1-sol` | high | `/ansh-task` |
| 🔴 Deep (ambiguous / high blast radius / design) | `gpt-6-astra` | high / xhigh | escalate — do NOT hand a Deep subtask to a cheap specialist; either split it further into Quick/Standard pieces, or flag it for the orchestrator to run carefully in-session |

A subtask should almost always come out Quick or Standard. **If a subtask stamps Deep, that's a
signal it isn't decomposed enough** — split it again. The whole point is to push expensive work
up into planning and keep execution focused without sacrificing model quality.

Also stamp each subtask with a **fresh-eyes recommendation** for its evaluation (consumed by
`/ansh-review`). Note: `/ansh-review` now runs a **independent review on every evaluation** by
default, so this stamp only signals when to add a HEAVIER mode on top of that baseline:
- `independent` — the default. Route through the runtime guide; record actual independence.
- `review-fresh` — touches auth / payments / migrations / destructive / data-loss → ALSO run
  parallel no-history reviewer agents on top of the independent pass.
- `swarm` — large structural change (new slice, consolidation merge, refactor >~10 files)
  → ALSO run the pr-review-* swarm on top of the independent pass.

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
- [ ] **Self-contained.** A fresh economy model agent could execute this from the packet alone, without
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

### 4a — `.ansh/plan.md` (the reasoning-tier high context)

The map you hold that the specialists don't need but the orchestrator and evaluator do:
goal, the problem in prose, the architecture/data-flow you uncovered, key constraints and
decisions (and the answers to the questions you asked), the overall definition of done, and the
subtask index with dependencies. This is the durable understanding — write it like a teammate
will read it cold.

Include the **guardrails / acceptance_criteria / exit_criteria** written in Phase 2.5, presented
as three itemized lists (not folded into prose) so `/ansh-loop`'s Step 1 sign-off gate can quote
them directly.

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
  "parent_ticket": "REV-1157",
  "branch_suggestion": "rev-1157-indices-for-db-query",
  "definition_of_done": "the overall bar",
  "guardrails": [
    "no schema change to `shift` without a migration review",
    "no writes to prod outside the standard ingestion pipeline"
  ],
  "acceptance_criteria": [
    "a manager can see the +4/+8 override applied after PTO without a page reload",
    "the change is visible to QA on UAT before it ships to prod"
  ],
  "exit_criteria": [
    "max_iterations exhausted on any subtask",
    "a guardrail above is tripped",
    "whole-goal evaluation (Step 3) fails twice"
  ],
  "termination": { "max_iterations": 3, "quality_bar": "all done-criteria pass + /ansh-review clean" },
  "prs": [
    { "id": "PR1", "branch": "rev-73-tag-rules-engine",
      "links": [{ "ticket": "REV-73", "word": "Closes" }, { "ticket": "REV-77", "word": "Part of" }],
      "depends_on": [], "subtasks": ["T1", "T2", "T3"] }
  ],
  "subtasks": [
    { "id": "T1", "title": "...", "tier": "standard", "model": "gpt-6.1-sol", "effort": "high",
      "deps": [], "fresh_eyes": "independent", "linear_ticket": "REV-73", "pr": "PR1",
      "packet": ".ansh/tasks/T1.md", "status": "todo" }
  ]
}
```

- `parent_ticket` is the parent/epic. Record it for context, status and the umbrella PR. Section PRs
  mention it in plain text and do **not** magic-word link it.
- `prs[].links` lists every ticket that PR's own diff advances, each with its magic word: `Closes`
  when this is the ticket's last PR, `Part of` otherwise. Every child ticket must appear in at least
  one PR's links, and in exactly one `Closes`. Don't list tickets that only arrive through a
  dependency branch.
- `prs[].depends_on` lists the PR ids whose branches this one merges or stacks on. They render as
  `Depends on #<n>`.
- `branch_suggestion` and every `prs[].branch` MUST follow `<tag-lower>-<slug>`, using the tag of the
  PR's **primary ticket** (its `Closes` ticket, else its main `Part of`), not a generic name.
  Single-PR plan → just `branch_suggestion`. Sequenced PRs → one `prs[]` entry per PR.
- `linear_ticket` (string or array) ties each subtask to the ticket(s) it advances. A PR's `links`
  must cover the `linear_ticket`s of its subtasks. Omit only for untracked scaffolding the user
  de-scoped.
- `guardrails`, `acceptance_criteria`, and `exit_criteria` are **goal-level, required whenever this
  plan may be handed to `/ansh-loop`** (i.e. any project-scale goal) — that orchestrator refuses to
  execute without all three. Write them even for a plan headed to `/ansh-small-loop`; they cost
  little here and save a re-derivation if the goal turns out bigger than expected. Don't duplicate
  `acceptance_criteria` per subtask — each subtask's own `Done-criteria` in its packet already
  serves that role at the subtask level.

### 4c — `.ansh/tasks/<id>.md` — one self-contained packet per subtask (the important part)

This is what `/ansh-task` reads, and ideally the ONLY thing it reads. Each packet must stand
entirely on its own:

```markdown
# T1 — <short imperative title>

## Linear ticket
- **Ticket: REV-73**. This subtask advances it. Its PR (`PR1`, branch `rev-73-<section-slug>`)
  carries `Closes REV-73` if it's the ticket's last PR, else `Part of REV-73`. List any other ticket
  the PR advances on its own line too. Mention the parent (REV-1157) in plain text only. Name any
  dependency PR as `Depends on #<n>`, and don't link its tickets.
- On pickup, the specialist moves **this ticket** to **In Progress** if it's still
  triage/backlog/unstarted. Do NOT set In Review/Done; the GitHub integration owns those. Omit
  this section only for untracked scaffolding the user de-scoped.

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

## Guardrails that apply to this slice (subset of the goal-level list)
- no schema change to `shift` without a migration review

## Tests to write (the edge cases above, made checkable)
- [ ] `foo.test.ts > rejects empty-string tenantId` (the boundary, not just missing)
- [ ] `foo.test.ts > idempotent on duplicate key`

## Done-criteria (testable)
- [ ] `bun typecheck` passes for the touched package
- [ ] new unit test `foo.test.ts > rejects missing tenantId` is green
- [ ] endpoint returns 422 with body `{error: "..."}` on missing tenantId
- [ ] all "Tests to write" above are green

## Stamp
tier: standard | model: gpt-6.1-sol | effort: high | fresh_eyes: independent | deps: []
```

Render the subtask table inline for the user too, and point them at `.ansh/plan.md` for the full
picture.

## Phase 5 — Independent challenge of the plan (bulletproof gate, do not skip)

Before you hand the plan to the loop, get an **adversarial read of the plan itself**, preferably independent.
The author wrote this decomposition with one perspective. An independent reviewer provides another
mind that tries to break it.

Use the runtime guide's **independent-review routing** in challenge mode. Pass the plan, packets and criteria; request a read-only adversarial review. Record reviewer identity and independence in `plan.md`. It reads the plan you just wrote (`.ansh/plan.md` + `.ansh/plan.json` + the
`.ansh/tasks/*.md` packets). Frame the challenge explicitly around the decomposition, not the code
(there's no code yet):

- **Missing subtasks** — work the goal needs that no packet covers (migrations, backfill, feature
  flags, rollout/rollback, telemetry, tests, docs).
- **Wrong ordering / hidden dependencies** — a subtask that can't actually start until another
  finishes, but isn't marked as a dep.
- **Unhandled edge cases** — failure modes the feature-wide edge-case analysis missed. This is the
  highest-value attack: a cross-model mind catches boundary/concurrency/permission cases the author
  glossed.
- **Weak done-criteria** — criteria that are vibes, not testable; criteria that would pass while
  the feature is still broken.
- **Under-decomposed subtasks** — anything that's secretly Deep hiding as Standard, or too big for a
  cheap specialist to execute from the packet alone.
- **Wrong layering / pattern** — a packet that would push business logic into a repo, run raw SQL
  outside a repo, or invent a pattern the codebase hasn't blessed.

Then **fold the findings back in** before handing off:
- Real gaps → add/split subtasks, fix ordering/deps, tighten done-criteria, enumerate the missed
  edge cases into the owning packet's "Watch out for" / "Tests to write". Re-run the Phase 3.5
  readiness checklist on anything you touched.
- Rejected findings → note in `.ansh/plan.md` why (so the loop and a future you don't re-litigate).
- If the independent reviewer surfaces a genuine product/scope/direction question you can't resolve from the code, it's
  the user's call — `AskUserQuestion`, don't silently re-architect.

If no independent reviewer is available, perform a rigorous in-session adversarial
challenge and record `independence: in-session` and the unavailable capability in `plan.md`.
Do not claim the pass was cross-model or independent.

A plan that hasn't survived an adversarial challenge is not ready to hand off.

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

By default, do not implement anything. End by telling the user:
- the subtask count and how many are Quick vs Standard (Deep should be zero — flag if not),
- **the independent challenge outcome** — what it found and how you folded it in (or that it was skipped
  because independent review was unavailable),
- the **guardrails / acceptance_criteria / exit_criteria** lists, rendered inline — these are what
  a human confirms next, whichever loop runs them,
- that `.ansh/plan.md` holds the high context and each `.ansh/tasks/<id>.md` is a self-contained
  packet,
- which orchestrator should run it: **`/ansh-small-loop`** for one scoped ticket, or **`/ansh-loop`**
  for project-scale work (which will re-present guardrails/acceptance/exit criteria for sign-off
  before executing) — or `/ansh-task T1` to run a single subtask directly — **or, if the user
  explicitly authorizes immediate execution, go straight to Phase 6 below instead of stopping here.**

## Phase 6 — Direct orchestration (only when explicitly authorized)

Planning and execution are separate roles in the Karpathy loop, and `/ansh-loop`'s
guardrail/acceptance/exit-criteria sign-off gate exists precisely so project-scale execution never
starts without a human confirming it first. **Never skip that gate on your own initiative** — the
default is still the STOP above.

But when the user's request — in the same turn that triggered this planning pass, or an immediately
following message — explicitly directs you to run the fleet now ("run it", "fleet these", "yes,
execute this via a workflow," "kick off the agents"), treat that as the sign-off for the subtasks
covered by this plan and dispatch directly, without a second confirmation round-trip:

- Use the runtime guide's available orchestration backend. With delegation, turn each ready
  packet into a child task; without delegation, execute ready packets serially. The `agent()` /
  `pipeline()` / `parallel()` mechanics below are examples only for an exposed Workflow API.
  Prompt each agent to read its `.ansh/tasks/<id>.md` packet in full and execute it exactly — Files
  to change, Answered questions, Guardrails, self-verify against Done-criteria before finishing.
  If an agent's isolation (e.g. a fresh worktree) won't reliably have `.ansh/` on disk, inline the
  packet's content directly into the prompt rather than just pointing at a path.
- Respect `plan.json`'s `deps` edges: independent subtasks fan out via `parallel()`/`pipeline()`;
  a dependency chain becomes sequential stages. Don't flatten a real dependency into parallel just
  because the Workflow tool makes parallel easy.
- **`isolation: "worktree"` is a concurrency property, not a file-sensitivity property — this is
  the mistake to avoid.** Isolation gives an `agent()` call a FRESH checkout branched off the base
  commit, with zero visibility into any other agent's (even an already-finished one's) uncommitted
  worktree changes — a Workflow script has no filesystem access to bridge state between worktrees.
  Isolate a subtask ONLY when it runs inside the same `parallel()` call as another subtask touching
  overlapping files (per the file-collision map from Phase 3/3.5) — i.e. only leaves of the
  dependency graph with no in-run consumer. **Never isolate a subtask that has an in-run dependent**
  (anything another subtask's `deps` points at): run that whole connected chain unisolated, in the
  shared invoking directory, sequential `await agent()` calls — sequencing alone already guarantees
  single-writer-at-a-time, so isolation buys nothing there and actively breaks the dependent stage's
  ability to see the code it needs. If a wave boundary forces the dependency across two separate
  `Workflow` calls, reconcile manually (Bash, outside the script) by copying the upstream stage's
  actual changed files into the shared directory before the next call — the script cannot do this
  itself.
- **Hold back any subtask whose packet names an unlanded prerequisite** (a blocking ticket, PR, or
  shared piece of infra — e.g. a feature flag another packet depends on) — dispatch only what's
  actually unblocked, and say explicitly, in the same message, what you held back and why. Do not
  silently drop a held-back subtask from the report.
- A Workflow run finishing is not the finish line. After it completes, the result routes through the
  normal loop exactly as if `/ansh-loop`/`/ansh-small-loop` had dispatched it: `/ansh-review` per
  subtask (or a batched pass), then `/ansh-resolve` once PRs are up. Don't report a subtask as
  "done" on the strength of the agent's own return value alone.

This does not lower the bar for genuinely project-scale, high-guardrail work — that class of goal
still routes to `/ansh-loop` for its sign-off gate even if the user says "run it," because the sign-off
IS the guardrail walkthrough, not a rubber stamp `/ansh-plan` can substitute for on a plan it just
wrote itself. Phase 6 is for the case where the user has already said "go" on a batch of
independently-scoped, non-project-scale subtasks in this same planning pass.

## Completion status

End with **DONE** (plan written), **DONE — DISPATCHED** (plan written and Phase 6 execution was
started; name what ran and what was held back), **NEEDS_CONTEXT** (blocked on a user answer), or
**DONE_WITH_CONCERNS** (plan written but a subtask wouldn't decompose below Deep — name it).
