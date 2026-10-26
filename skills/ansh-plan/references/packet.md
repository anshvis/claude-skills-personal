# Task packet template

`.ansh/tasks/<id>.md`. `/ansh-task` reads this and ideally nothing else. Every section stands on
its own: don't assume the reader saw `plan.md`.

```markdown
# T1 - <short imperative title>

## Milestone
M1 - <name>. Covers: AC-1, FM-2. Surface: invisible (no screen reads these rows).

## Linear ticket
- Ticket: REV-73 (parent REV-1157). PR `PR1` on branch `rev-73-<section-slug>`, base `<base>`,
  links `Closes REV-73`.
- Branch, links and status follow [tickets](../../_shared/tickets.md).

## Objective
<one or two sentences: what done looks like for this slice>

## Context
<the background this task needs: what the code does, why it changes, how it connects to its
neighbours>

## Files to change
- `packages/.../foo.ts` - <what changes>
- `packages/.../foo.test.ts` - <the test it adds>

## Gold-star references (mirror these)
- `packages/.../bar.ts:42-70` - <the pattern, and why it's the one to follow>

## Naming and tracing (new repo, facade, service or business-logic fn only)
- Tag `<Tag>`, class `<Class>`, spans `Effect.fn("<Tag>.<method>")` per method. Sibling to match:
  `<file>`.

## Decisions (no open questions)
- Q: missing tenantId is 422 or 400? A: 422, matches the validation layer in bar.ts.
- D-3 (agent default): <call>. You could tell me instead: <alternative>.

## Watch out for
- empty tenantId and missing tenantId both 422; "" must not pass a truthy check
- concurrent requests with one idempotency key must not double-write
- the cutoff compares projector-local time, not UTC

## Guardrails for this slice
- <the subset of plan.json guardrails that apply>

## Tests to write
- [ ] `foo.test.ts > rejects empty-string tenantId`
- [ ] `foo.test.ts > idempotent on duplicate key`

## Verification
Surface: invisible (no screen changes; a projector writes rows)
Covers: AC-1, FM-2
Checks:
- AC-1: `bun test packages/.../foo.test.ts -t "rejects missing tenantId"` -> expect 422 with
  `{error: "..."}`. Fails today because the handler accepts a missing tenantId.
Could this pass while the feature is broken? <why not>
Regression: <suites and callers, from the blast radius and a caller search>
Perf: <metric, baseline method, budget> | n/a: <reason>
Evidence: ~/.agentic-workflow/<repo-slug>/evidence/<branch>/<sha>/

Done when every check above passes at the head SHA, the Tests to write are green, and typecheck
and lint pass for the touched packages.

## Stamp
tier: standard | model: gpt-6.1-sol | effort: high | fresh_eyes: independent | deps: [] |
autonomy: full | parked_at_merge: false
```

The Verification block follows [verification](../../_shared/verification.md). Add a line telling
the specialist to apply `lightweight-sql` when the diff touches SQL or Drizzle.
