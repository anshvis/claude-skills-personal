---
name: investigate-code
description: Systematic root-cause debugging for CODE problems — errors, stack traces, wrong behavior, "it was working yesterday." Iron law: no fix without a confirmed root cause. Use when asked to debug, fix a bug, or figure out why code is broken. For a non-code problem (why a ticket stalled, what a decision actually was, an operational/org question) use investigate-problem instead — this one is code-only.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - WebSearch
---

# /investigate-code — Root-cause debugging

## Iron law

**No fix without root cause investigation first.** A patch that makes the symptom disappear
without explaining *why* it occurred is how the same bug comes back wearing a different hat.

## Phase 1 — Root cause investigation

1. **Collect symptoms.** Read the error message, stack trace, and reproduction steps. If the
   user hasn't given enough, ask one question at a time.
2. **Read the code.** Trace the path from symptom back to potential causes — Grep for all
   references, Read to understand the actual logic, don't assume from the name of a function.
3. **Check recent changes:**
   ```bash
   git log --oneline -20 -- <affected-files>
   ```
   Was this working before? What changed? A regression means the root cause is in the diff.
4. **Reproduce it.** Deterministic reproduction beats guessing. If you can't reproduce it,
   gather more evidence before forming a hypothesis — don't skip to Phase 3.
5. **Check for recurrence.** `git log` for prior fixes in this same area. Recurring bugs in the
   same files are an architectural smell, not a coincidence — worth naming even if out of scope
   for this fix.

Output: **"Root cause hypothesis: X happens because Y."** — a specific, testable claim.

## Phase 2 — Pattern check

| Pattern | Signature | Where to look |
|---|---|---|
| Race condition | Intermittent, timing-dependent | Concurrent access to shared state |
| Nil/null propagation | TypeError, undefined access | Missing guards on optional values |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks, hooks |
| Integration failure | Timeout, unexpected response | External API calls, service boundaries |
| Configuration drift | Works locally, fails in staging/prod | Env vars, feature flags, DB state |
| Stale cache | Old data, fixes on cache clear | Redis, CDN, browser cache |

If nothing matches, WebSearch the sanitized error type + framework (strip hostnames, IPs, file
paths, SQL, customer data first — search the error *category*, never the raw message). If
WebSearch is unavailable, skip and continue.

## Phase 3 — Hypothesis testing (verify before touching a fix)

1. Add a temporary log/assertion at the suspected cause. Run the reproduction. Does the evidence
   match?
2. If wrong: before the next hypothesis, consider one more sanitized search. Then return to
   Phase 1 — gather more evidence, don't guess again blind.
3. **3-strike rule:** if 3 hypotheses fail, STOP. Ask: continue with a new hypothesis, escalate
   for a fresh pair of eyes, or add logging and wait to catch it live.

Red flags to slow down on: "quick fix for now" (there is no for-now — fix it right or escalate);
proposing a fix before tracing data flow (you're guessing); each fix reveals a new problem
elsewhere (wrong layer, not wrong code).

## Phase 4 — Implementation

1. Fix the root cause, not the symptom — smallest change that eliminates the actual problem.
2. Minimal diff. Resist refactoring adjacent code while you're in there.
3. Write a regression test that **fails without the fix and passes with it.**
4. Run the full test suite. Paste the output. No regressions.
5. If the fix touches more than ~5 files, flag the blast radius before proceeding — that's a
   large footprint for a bug fix; confirm scope rather than assuming it's fine.

## Phase 5 — Verification & report

Reproduce the original scenario fresh and confirm it's actually fixed — not optional. Run the
test suite, paste output.

```
DEBUG REPORT
════════════════════════════════════════
Symptom:         [what was observed]
Root cause:      [what was actually wrong]
Fix:             [what changed, file:line]
Evidence:        [test output / reproduction proving the fix works]
Regression test: [file:line of the new test]
Related:         [prior bugs in same area, architectural notes]
Status:          DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

## Rules

- 3+ failed fix attempts → stop and question the architecture, not the hypothesis.
- Never say "this should fix it" — verify and prove it.
- Never apply a fix you can't reproduce and confirm.
- Fix touching >5 files → confirm scope before proceeding.
