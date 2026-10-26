# Verification

A task is done when its verification contract passes on the real app, not when the code compiles
or the agent says so. The contract is written before the code and must fail before the change.

## The contract (in every task packet)

```
## Verification
Surface: visible | data-visible | invisible  (why, one line)
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

## By surface

Pick from the milestone's `Surface`. `/ansh-review` checks the diff against it: a diff that
touches routes, `.tsx`, copy, styles or iOS views is at least `visible`, whatever was declared.

**visible** (what a user sees or does changes, e.g. rule engine)
1. Read or create the feature's entry in the local feature map (`/ansh-verify`).
2. A red-first journey: at least 3 interactions, an assertion after every state change.
3. Run it with `ui-evidence` on the local stack, tied to the head SHA.
4. Lenses: functional and error-state always. Accessibility for new controls, responsive for
   layout changes, Figma parity when there's a design.
5. Cross-check the data behind the screen read-only. The screen alone isn't proof.
6. Visual verdict must be `unchanged` or `looks-right`. `off`, `sloppy` or `unchecked` is REVISE.

**invisible** (no screen changes, e.g. scheduled hours, crons, projections, entities)
1. Red-first tests at the service boundary (integration and DB tests). Jobs also get retry and
   idempotency tests.
2. Migrations: dry run plus backfill check on a branch database.
3. Perf is required: rows read (`/lightweight-sql`), duration, and the limiter.
4. The milestone's production signal (log, metric, trace) fires locally.
5. Record `journey: n/a (invisible)`. That's a classification, not a waiver.

**data-visible**: everything under invisible, plus one read-only `ui-evidence` check that the
screen shows the new value. No write steps.

**CLI or API surface**: same as visible, driven with the CLI or `curl` instead of a browser.
Capture the command, exit code and output.

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

Write to `~/.agentic-workflow/<repo-slug>/evidence/<branch>/<sha>/`: the command or journey, its
output, screenshots, and a `verdict.json` (`{sha, checks:[{id, status, evidence}], surface}`).
Tools that write their own pack (`verify-web`'s `pack.json`, `ui-evidence`'s `summary.json`) are
copied into the same directory and referenced from `verdict.json`. Evidence survives cleanup.
On my own PRs, post a short evidence comment (checks, verdicts, SHA) without asking. Don't upload
to Linear.

## Not a pass

- "Inconclusive", the wrong surface, or a check run at a different SHA.
- A skipped check without a written reason.
- A self-report from the agent that wrote the code. `/ansh-review` reruns the checks itself.
