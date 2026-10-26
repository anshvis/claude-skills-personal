---
name: ansh-review
description: "Give an independent PASS, REVISE or DEBUG verdict on a task or PR by rerunning its verification at the head SHA, checking it against the plan, rating blast radius and picking a merge lane. Use after /ansh-task, inside /ansh-pr-loop, or for /ansh-review <task id | PR>."
---

# /ansh-review

**Goal:** an independent verdict on a task or PR, with evidence. Never edit code.

**Uses:** [runtime](../_shared/runtime.md), [autonomy](../_shared/autonomy.md),
[verification](../_shared/verification.md), [principles](../_shared/principles.md),
[stacking](../_shared/stacking.md), [ledger](../_shared/ledger.md) (`../_shared/ansh-log`),
[/ansh-verify](../ansh-verify/SKILL.md), [/codex](../codex/SKILL.md),
[/review-fresh](../review-fresh/SKILL.md), [/ansh-debug](../ansh-debug/SKILL.md),
[/ansh-plan](../ansh-plan/SKILL.md), [/ansh-correct](../ansh-correct/SKILL.md),
[output format](references/output.md).

Review on Astra per runtime.md, xhigh on the deep lane. Never on a cheap model: a shallow review
gives false confidence. Input is a task id (subtask mode) or a PR number and SHA (PR mode). Every
phase runs in both modes.

## Steps

1. **Triage (cheap).** Read the diff, tickets and TDD, not the code in depth. Run Plan gap (step 5)
   and Blast radius (step 6) first. They pick the lane, and the lane picks how deep the rest goes.
2. **Ground in the repo.** Read the root `AGENTS.md`, the nearest nested one, and the sections of
   `.agents/skills/best-practices/references/` the diff touches. For Effect, use
   `bunx effect-solutions show <topic>` and `submodules/effect`. Before calling a pattern wrong,
   check the nearest good sibling slice. Matching a good neighbor isn't a finding. Matching a
   known-bad one still is: cite the reference doc.
3. **Rerun verification.** Don't trust the task's evidence. Run `/ansh-verify run` with the
   packet's contract at the head SHA. Then judge it:
   - **Strength.** Could it pass while the feature is broken? If yes, it's Act on
     (`weak-verification`). Rerun a check on the base when red-first evidence is missing or doubtful.
   - **Surface.** Compare the declared Surface with the diff per verification.md. A diff touching
     routes, `.tsx`, copy, styles or iOS views is at least `visible`. A mismatch is Act on
     (`wrong-surface`).
   - **Not a pass:** inconclusive, a different SHA, a skipped check with no written reason.
4. **Does it work?** Read done-criteria from `.ansh/tasks/<id>.md` (index `.ansh/plan.json`) or what
   you were handed. Each gets a verdict with evidence. No evidence is a fail. Every "Watch out for"
   item must be handled and every "Tests to write" test must exist and pass: a miss is Act on. Then
   look for edge cases the planner missed. These layering problems are Act on (see
   `services-and-layers.md` and STYLE.md §13):
   - A repo doing more than data access: auth checks, business decisions, tagging rows with domain
     meaning, merging across tables, opening orchestration transactions, calling another repo or a
     facade, publishing events, or returning transport errors.
   - Database access outside a repo. Facades, services, projectors and handlers call repos.
   - A facade calling another slice's repo instead of that slice's facade.
   - An effectful repo or facade method that isn't `Effect.fn("<Tag>.<method>")`, or a service tag
     that doesn't match its class name.

   A brand-new slice in `packages/database` instead of `packages/services` is Consider.
5. **Is it what we planned?** Find the plan, closest source first:
   1. The packet and `.ansh/plan.json`, including the PR's `prs[]` entry.
   2. Linear tickets the PR links. Collect keys (`[A-Z]{2,5}-\d+`) from the PR title, body
      (`Closes` / `Part of`), branch and commits. Fetch each. Note closes vs part of.
   3. Each ticket's parents up to the top, and each parent's other children (sibling work).
   4. The TDD: a design-doc link in the PR, tickets or parents, else the Linear project's documents.

   For a closed ticket, each AC is met (cite line or test), partial or missing. For a "part of"
   ticket, check only this PR's share. The change stays inside the parent's scope, takes no sibling
   or later-phase work, and matches the TDD's names, data model, interfaces, code location and
   phase. Nothing the TDD lists as out of scope is in the diff. Rate the gap:
   - **none**: the code does what the plan says.
   - **small**: a naming difference, a missing test or a small missing case, with an obvious fix.
   - **large**: a missing core criterion, a contradiction of the TDD (schema, contract, layer or
     approach), extra scope, or a decision the plan never made.
6. **What breaks if it's wrong?** Classify each file, then the PR, by its riskiest part:

   | Kind | What it does | Base blast radius |
   |---|---|---|
   | setup | New type, schema, table, config or dependency. Nothing calls it yet. | low |
   | logic | A behavior: function, facade method, model or rule. Tests reach it. Not switched on. | medium |
   | wiring | Registers a layer, route, RPC, cron, flag, UI entry or caller. Makes it run in prod. | high |

   Logic hiding in a wiring PR (new branching, calculations, error handling) is a large gap. Mixed
   kinds is a small gap: recommend a split unless tiny. Raise to **high** when the change edits
   something existing with callers (shared type, contract, schema, RPC, public function, even in
   setup), touches a migration or prod data or deletes anything, touches auth, permissions,
   payments, payroll, pay rules or patient data, changes what customers see or what runs on a
   schedule without a flag (or flag on), or changes CI, deploy or infra config. Lower one level when
   the new path is unreachable in prod: flag off by default, unregistered or uncalled.
7. **Merge lane and park.**
   - `merge_lane: deep` when blast radius is high (auth, payments, migrations, destructive, shared
     contracts and the rest above). Deep needs a fresh-context review plus an independent re-run of
     the verification, both at the head SHA. No fresh context available: BLOCKED.
   - `merge_lane: standard` otherwise.
   - `parked: yes` when the task, milestone or PR has `parked_at_merge: true` in `plan.json`, or
     when merging would do something on autonomy.md's never-do list (a destructive
     migration or backfill on deploy, applying infra or deploying on merge, someone else's PR).
   - List each `Depends on #<n>` with its state. Open or parked dependencies go in `WAITING_ON`.
     They change when it merges, not the verdict.
8. **Independent review.** Skip the outside reviewer when called with `gate` from `/ansh-pr-loop`:
   the gate's Independent lens supplies it. Otherwise send intent, criteria, watch-outs, plan sources and the diff (not the
   author's reasoning) to an independent reviewer per runtime.md. Record provider, model and
   independence. Also do your own adversarial pass: races, missing error paths, leaks, security
   boundaries. Add a fresh-context review on the deep lane or when the packet says
   `fresh_eyes: review-fresh`. Use `/review-fresh` only on a clean committed tree; on a stacked or
   shared branch, give a read-only reviewer `git diff origin/<base>...HEAD` instead (stacking.md).
   Large structural diffs or a swarm request add the correctness, silent-failure, tests, types,
   comments and simplification lenses (`pr-review-*` agents). Verify each finding against the code.
9. **Synthesize.** Merge findings that describe the same issue and note who raised each. Findings
   raised independently by two reviewers weigh most. Bucket every finding:
   - **Act on**: a failing criterion or check, a real bug or security issue, a layering violation,
     a missed watch-out. Blocks the PR.
   - **Consider**: legitimate, unsure it's worth it now. Gold-star divergence goes here or Noted.
   - **Noted**: valid, not actionable now.
   - **Dismissed**: wrong or missing context, with a one-line reason.

   Write the agreement note. Settle a reviewer disagreement by running something. Never drop an
   independent finding silently.
10. **Verdict and log.** Emit the block and PR comment in [output](references/output.md). Post or
    edit the comment when a PR exists. Log
    `ansh-log ansh-review verdict <PASS|REVISE|DEBUG> --task <id> --pr <n> --reason <reason> --surface <s>`.
11. **Repeat mistakes.** Log each Act on item with a ledger `reason` and a `--class` name, reusing
    an existing class from `events.jsonl` when it's the same mistake (ledger.md). A class seen twice
    or more goes in `REPEAT_CLASSES` for `/ansh-correct`.

## Edge cases

| case | do |
|---|---|
| A plan source is missing | Review against what exists. Name what was missing in `PLAN_SOURCES`. |
| No linked ticket or TDD | Say so. Review against the packet alone. |
| Large plan gap | REVISE routed to `/ansh-plan`. Not an Act on by itself: the plan may be what's wrong. A missing core criterion still fails step 4. |
| Code deliberately differs and beats a stale plan | Still a large gap. Don't touch code. Route to `/ansh-plan` to update the plan. |
| Packet has no `## Verification` | Rerun the done-criteria. Flag `weak-verification` as Act on. |
| Task evidence at a different SHA | Ignore it. Your rerun at the head SHA is the evidence. |
| Behavior wrong, cause not obvious | DEBUG. List it in BUGS for `/ansh-debug`, no blind patch. |
| Reviewers still disagree after running something | Keep both sides in Consider. Set the lane to deep. |
| No delegation available | In-session pass, `independence: in-session`, reduced independence in CONCERNS. |
| Deep lane or `review-fresh` needed, no fresh context | BLOCKED. |
| Stacked or shared branch and a tool wants to rebase | Review from a detached worktree at the head. Never rebase or force-push. |
| Dependency PR open or parked | `WAITING_ON`. Review and drive to green anyway. |
| Verification needs prod writes or a deploy | Don't. Mark the check skipped with the reason and set `parked: yes`. |

## Output

The block in [output](references/output.md), plus the principles that changed a call. End with
**DONE** (verdict emitted) or **BLOCKED** (couldn't evaluate; say what's needed).
