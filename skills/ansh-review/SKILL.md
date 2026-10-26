---
name: ansh-review
description: "Evaluate a subtask or PR against its done-criteria and its plan (packet, linked Linear ticket and parents, TDD), sort the change into setup, logic or wiring, rate the gap between plan and code and the blast radius, and return PASS, REVISE or DEBUG plus a merge call: auto or manual-review. Plan gap and blast radius run first as a cheap triage; in PR mode a manual-review call stops there. Use after /ansh-task, inside /ansh-pr-loop's review gate, or when the user invokes /ansh-review. Prefer an independent reviewer using an available model; record actual independence and preserve stronger fresh-review gates."
---

# /ansh-review — Evaluator

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

The evaluator closes the loop. It does not edit code. It answers three questions, with evidence:

1. **Does it work?** Done-criteria, edge cases and repo patterns.
2. **Is it what we planned?** The gap between the plan and the code.
3. **What breaks if it's wrong?** The blast radius, which decides whether it can merge unattended.

**Triage first.** Phases 2 and 3 are cheap: they read the diff, the tickets and the TDD, not the
code in depth. Run them before anything else. In **PR mode** (a PR number, as `/ansh-pr-loop`
calls it), a `manual-review` call ends the review there: post the merge-call comment and return,
skipping Phases 1 and 4. A person is going to read the PR anyway, so a deep automated pass would
only spend effort and invite fixes to code whose direction isn't settled. In **subtask mode**
(after `/ansh-task`), run every phase; the merge call only matters later, when the PR opens.

**Effort.** Use GPT-6 Astra at high effort. For auth, payments, migrations or destructive changes,
use xhigh with extended thinking. Never review on a cheap model: a shallow review is worse than
none, because it creates false confidence.

## Phase 0 — Ground yourself

Judge against this repo, not general taste. Read the root `AGENTS.md` and the nearest nested one,
and the sections of `.agents/skills/best-practices/references/` that the diff touches. For Effect,
use `bunx effect-solutions show <topic>` and `submodules/effect`. Prior art beats doctrine: before
calling something the wrong pattern, check how the nearest good sibling slice does it. Matching a
good neighbour is not a finding. Matching a known-bad one still is; cite the reference doc.

## Phase 1 — Does it work? (after triage)

**Done-criteria.** Read them from `.ansh/tasks/<id>.md` (index `.ansh/plan.json`) or from what you
were handed. Give each one a verdict with evidence. A criterion with no evidence is a FAIL.

```
T3 "endpoint returns 422 on missing tenantId"  → PASS (ran curl, got 422 + body {error:...})
T3 "unit test added"                            → FAIL (no test touches this path)
```

**Watch-outs and tests.** Every edge case in the packet's "Watch out for" must be handled, and
every test in "Tests to write" must exist and pass. A missed one is a BLOCKER. Then look for edge
cases the planner missed.

**Layering.** These are BLOCKERS (see `services-and-layers.md` and STYLE.md §13):
- A repo doing more than data access: auth checks, business decisions, tagging rows with domain
  meaning, merging across tables, opening orchestration transactions, calling another repo or a
  facade, publishing events, or returning transport errors.
- Database access outside a repo. Facades, services, projectors and handlers call repos.
- A facade calling another slice's repo instead of that slice's facade.
- An effectful repo or facade method that isn't `Effect.fn("<Tag>.<method>")`, or a service tag
  that doesn't match its class name.

A brand-new slice in `packages/database` instead of `packages/services` is a non-blocking issue.

## Phase 2 — Is it what we planned? (triage)

**Find the plan, from the closest source to the furthest:**
1. The packet and `.ansh/plan.json` (including the PR's entry in `prs[]`).
2. The Linear tickets the PR is linked to. Collect keys (`[A-Z]{2,5}-\d+`) from the PR title,
   body (`Closes` / `Part of`), branch name and commit messages, then fetch each with `get_issue`.
   Note whether the PR **closes** each one or is only **part of** it.
3. Each ticket's parents, up to the top. List each parent's other children, so you know which
   work belongs to a sibling ticket.
4. The TDD. Look for a design-doc link in the PR body, the tickets or the parents. If there isn't
   one, check the documents on the ticket's Linear project.

Missing sources are not a failure. Review against what exists and say what was missing.

**Compare.**
- For a ticket the PR closes, each acceptance criterion is met (cite the line or test), partial,
  or missing. For a "part of" ticket, check only the share this PR claims.
- The change stays inside the parent's scope. It doesn't take a sibling ticket's work or a later
  phase's work.
- The code matches the TDD's names, data model, interfaces, where code lives, and which phase the
  work belongs to. Nothing it lists as out of scope is in the diff.

**Rate the gap:**
- **none** — the code does what the plan says.
- **small** — a naming difference, a missing test or a small missing case, with an obvious fix.
- **large** — a missing core criterion, a contradiction of the TDD (schema, contract, layer or
  approach), extra scope, or a decision the plan never made. The code and the plan disagree about
  what to build, so a person has to choose.

If the code is deliberately different and better than a stale plan, that is still a large gap.
Don't change the code. Say the plan or TDD needs updating, and leave the decision to the user.

## Phase 3 — What breaks if it's wrong? (triage)

**Sort the change into kinds.** Classify each file, then the PR as a whole.

| Kind | What it does | Typical blast radius |
|---|---|---|
| **setup** | Adds a new type, schema, table, config or dependency. Nothing calls it yet. | low |
| **logic** | Implements a behaviour: a function, facade method, model or rule. Tests reach it; it isn't switched on yet. | medium |
| **wiring** | Connects things: registers a layer, route, RPC, cron, flag, UI entry point or caller. This is what makes the code run in production. | high |

The PR's kind is its riskiest part. If setup and logic were done properly, a wiring PR is thin:
imports, registrations and a flag check. Watch for these:
- **Logic hiding in a wiring PR** (new branching, calculations, error handling): a large gap.
  The logic belongs in its own reviewed logic PR.
- **A PR that mixes kinds**: a small gap. Recommend splitting it, unless it's tiny.

**Then adjust the blast radius.** It goes **up to high** whenever the change does any of these:
- Edits something that already exists and has callers: a shared type, contract, schema, RPC or
  public function. That counts even when the PR is setup.
- Changes a migration or production data, deletes anything, or does anything else destructive.
- Touches auth, permissions, payments, payroll or pay rules, or patient data.
- Changes what customers see or what runs on a schedule, with no flag (or with the flag on).
- Changes CI, deploy or infrastructure config.

It goes **down one level** when the new path is unreachable in production: behind a flag that
is off by default, unregistered, or called by nothing.

**Merge call.**
- **manual-review** if any of these is true:
  - the gap is large;
  - the blast radius is high;
  - the reviewers left an unresolved disagreement (only known after Phase 4).
- **auto** otherwise. The PR may merge without a person once it is green.

Dependencies don't change the call; they decide *when*. List each `Depends on #<n>` PR with its
state. An `auto` PR whose dependency is open or in manual review is **waiting**: it can be
reviewed, fixed and driven to green, but it doesn't merge until everything below it has.

**Post the call on the PR** when one exists. If there is no PR yet, the orchestrator posts it
when it opens the PR. Add or edit one comment starting `<!-- ansh-review:merge-call -->`. Write it
in the PR's own voice: no AI attribution, no emoji. Shape:

```markdown
<!-- ansh-review:merge-call -->
**Needs manual review** | **Clear to auto-merge**

Kind: wiring (registers the forecast cron, adds the RPC route)
Plan gap: large. FND-2710 says the job reads the census input interface, but the diff reads `unit_census` directly.
Blast radius: high. The cron runs nightly for every unit, with no flag.
Waiting on: #1234 (open) <omit the line when there are no open dependencies>

What to look at: <the one or two places a reviewer should read first>
```

## Phase 4 — Independent review

Send the diff, the done-criteria, the watch-outs and the plan sources to an independent reviewer,
using the runtime guide's routing. Prefer a different model, then fresh context. Report the
reviewer's actual provider, model and independence; a Codex process launched from Codex is not
automatically a different model. Separately, do your own adversarial pass in this session: races,
missing error paths, leaks and security boundaries.

- **Auth, payments, migrations, destructive changes, or `fresh_eyes: review-fresh`:** add a
  fresh-context review. Use `/review-fresh` only for a clean, committed tree. On a stacked or
  shared branch, never rebase to fit it (see [stacking](../_shared/stacking.md)): give a
  read-only reviewer the diff instead. If fresh context isn't available, return BLOCKED.
- **Large structural diffs or an explicit swarm request:** run the correctness, silent-failure,
  tests, types, comments and simplification lenses, using the `pr-review-*` agent definitions
  where they exist. Verify each finding against the code before keeping it.
- **Reviewers disagree:** re-read the code and settle it with evidence. Keep any disagreement you
  can't settle in the verdict, and never drop an independent finding silently.

If no delegation is available, do the in-session pass and record reduced independence as a
concern. A required fresh-review gate stays BLOCKED.

## Output

Sort findings into:
- **BLOCKER**: a criterion fails, a real bug or security issue, or a layering violation.
- **BUG**: behaviour is wrong and the cause isn't obvious. Send it to `/ansh-debug`, not a blind
  patch.
- **NIT**: style or clarity, or a small plan gap. Note any divergence from a `gold-star` reference.

A large plan gap is not a BLOCKER by itself, because the plan may be the thing that's wrong. It
sets `MERGE: manual-review` and goes in the PR comment for a person to decide. A missing core
criterion still fails Phase 1, and that failure is a BLOCKER.

```
VERDICT: TRIAGED | PASS | REVISE | DEBUG
CRITERIA: <n met> / <n total>
KIND: setup | logic | wiring [mixed: ...]
PLAN_GAP: none | small | large — <one line per gap, with ticket key or TDD section>
PLAN_SOURCES: <packet, FND-1234 (closes), parent FND-1200, TDD link | missing: ...>
BLAST_RADIUS: low | medium | high — <why>
DEPENDS_ON: [#<n> open | merged | manual-review]
MERGE: auto | manual-review — <reasons>
WAITING_ON: [#<n> ...]   # open or manual-review dependencies; merge holds until they merge
MODE: independent [+ in-session] [+ review-fresh] [+ swarm]
REVIEWER: <provider/model or unknown>
INDEPENDENCE: cross-model | fresh-context | in-session
CONCERNS: [unavailable capabilities or reduced independence]
BLOCKERS: [ {subtask, finding, suggested fix} ... ]
BUGS: [ {symptom, why root-cause is non-obvious} ... ]   # → /ansh-debug
NITS: [ ... ]
```

- **TRIAGED** (PR mode, `manual-review`): Phases 1 and 4 were skipped on purpose. The caller
  hands the PR to a person and runs no further automated review or fixes on it.
- **PASS**: the caller may ship. `MERGE` decides whether the merge waits for a person.
- **REVISE**: the caller sends BLOCKERS back to `/ansh-task`, or to `/ansh-plan` when a fix needs
  a decision. Never let the specialist guess its way through a plan gap.
- **DEBUG**: the caller sends BUGS to `/ansh-debug` for a root cause before any fix.

## Completion status

End with **DONE** (verdict emitted) or **BLOCKED** (couldn't evaluate; say what's needed).
