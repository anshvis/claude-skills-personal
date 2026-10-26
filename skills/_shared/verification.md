# Verification

A task is done when its verification contract passes on the real app, not when the code compiles
or the agent says so. The contract is written before the code and must fail before the change.

## The contract (in every task packet)

```
## Verification
Surface: ui | backend | data-visible | full-stack  (derived per Surface below; why, one line)
Covers: AC-n, FM-n
Checks:
- AC-3: <exact command, test or journey> -> expect <observable result>. Fails today because <reason>.
Could this pass while the feature is broken? <why not>
Regression: <suites and callers, from the blast radius>
Perf: <metric, baseline method, budget> | n/a: <reason>
Evidence: <where the pack goes>
```

Rules:
- **Red first.** Run each check on the base before changing code. A check that already passes
  proves nothing: rewrite it.
- **Real path.** Drive what a user or caller drives. No internal setters, test-only endpoints, or
  mocks except where a production boundary already isolates the system.
- **Observable result.** Assert the end state and its side effects (rows, files, events), not
  that a function was called.
- **Rerunnable.** Every check is a command another agent can run at a given SHA. Keep the script.

## Closing the loop

Auto-merge requires evidence at the head SHA that covers every acceptance criterion, the actual
changed user or caller path, its side effects, relevant failure modes and affected existing
callers. Use the surface, regression and performance rules below to derive the checks. The
reviewer reruns them and explains why they would detect the intended behavior being wrong.

For a cornerstone or foundational PR whose consumers arrive later, validate its own contract
through realistic callers and integration checks. State exactly what that proves; later PRs own
their end-to-end feature checks. If this PR's promised result depends on an untested consumer,
its loop is still open. Architectural importance alone does not require a human checkpoint.

For `/ansh-correct`, replay the historical mistake to prove it is rejected, prove the corrected
case passes, and exercise valid affected callers so the new guard does not just reject everything.

Record `LOOP_CLOSURE: closed` with criterion-to-evidence links, or `open` with each missing proof
and the next check to add. An open loop is REVISE: strengthen verification and rerun it. If the
needed environment or reviewer is unavailable, report BLOCKED with the missing capability. A
skipped or inconclusive required check cannot close the loop, even when its reason is recorded.

Behavioral evidence and code quality are separate merge gates. The PR gate must also apply
`/thermo-nuclear-code-quality-review` and meet its approval bar. Working behavior does not waive
structural findings; a missing review is not a pass.

## Surface

The surface is the set of halves a change touches. It is derived from the change, never picked by
hand, and it decides who verifies.

- `ui` half: routes, pages, components, `.tsx`, styles, copy, client state, iOS views.
- `backend` half: services, facades, repos, RPC handlers, DB schema and migrations, jobs, crons,
  projections, queues, integrations, CLIs and HTTP APIs.
- Path rules in web-app: `apps/*/src` UI code and `*.tsx` are `ui`; `packages/services`,
  `packages/database`, RPC, jobs and migrations are `backend`. A shared contract or schema the UI
  renders counts as both.
- `/ansh-plan` derives it per milestone and packet from Changes and File blast radius.
  `/ansh-review` re-derives it from the diff. A half the packet didn't declare is Act on
  (`wrong-surface`), and the check set widens before any PASS.

| Surface | Halves | Verified by |
|---|---|---|
| `ui` | ui only: copy or layout, no data change | `/ansh-control` |
| `backend` | backend only, e.g. scheduled hours or a cron | `/ansh-backend` |
| `data-visible` | backend, and an existing screen shows the result | `/ansh-backend`, then one read-only `/ansh-control` look |
| `full-stack` | both, e.g. a rule engine with new UI, API and storage | end to end, below |

The packet's `Surface:` line, `plan.json` `surface`, the ledger's `--surface` and `/ansh-retro`'s
escape-rate split use these four values. `visible` and `invisible` are aliases for `ui` and
`backend`, so older packets and ledger lines still read.

**full-stack, end to end.** `/ansh-control` performs the user action in the UI. `/ansh-backend`
asserts that same action's side effects: the API call it made (status and body), the DB rows
before and after, and the job or event it triggered. Both run at the same SHA, in one session,
against one local stack. The check passes only if the UI end state and the backend end state both
match. Each half also keeps its own checks: backend contract checks without the UI, and the UI's
error, empty and loading states.

**ui half checks**
1. The feature's entry in the local feature map exists or gets written.
2. A red-first journey: at least 3 interactions, an assertion after every state change.
3. Lenses: functional and error-state always. Accessibility for new controls, responsive for
   layout changes, Figma parity when there's a design.
4. Cross-check the data behind the screen read-only. The screen alone isn't proof.
5. Visual verdict must be `unchanged` or `looks-right`. `off`, `sloppy` or `unchecked` is REVISE.

**backend half checks**
1. Red-first tests at the service boundary (integration and DB tests). Jobs also get retry and
   idempotency tests.
2. Migrations: dry run plus backfill check on a branch database.
3. Perf is required: rows read, duration, and the limiter.
4. The milestone's production signal (log, metric, trace) fires locally.
5. A backend-only change records `journey: n/a (backend)`. That's a classification, not a waiver.

## Regression (agent-derived)

Derive it from the TDD's `File blast radius` and `Surfaces touched`, plus a search for every caller
of what changed. "Run the suites near the diff" isn't enough: the miss is always the other place
the change shows up. Prove the one fact that makes it safe by running something.

## Performance (agent-derived)

Default budget: no worse than base beyond noise. Measure base and head the same way, at least 3
runs each, and name what limits the number before trusting it. A milestone with an explicit
budget in the TDD uses that instead. Write `n/a: <reason>` only when nothing on a hot path, a
query, or a job changes.

## Evidence pack

Write to `~/.agentic-workflow/<repo-slug>/evidence/<branch>/<sha>/<task-id>/`: the command or
journey, its output, screenshots, and a `verdict.json` (`{sha, task, checks:[{id, status, evidence}],
surface}`). `<sha>/manifest.json` lists every check expected from every packet the PR covers, with
its status. The merge gate reads the manifest: a missing check is a fail.
Tools that write their own pack (`verify-web`'s `pack.json`, `ui-evidence`'s `summary.json`) are
copied into the same directory and referenced from `verdict.json`. Evidence survives cleanup.
On my own PRs, post a short evidence comment (checks, verdicts, SHA) without asking. Don't upload
to Linear.

## Not a pass

- "Inconclusive", the wrong surface, or a check run at a different SHA.
- A skipped check without a written reason.
- A self-report from the agent that wrote the code. `/ansh-review` reruns the checks itself.
