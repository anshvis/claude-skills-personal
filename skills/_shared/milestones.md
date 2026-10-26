# TDD milestones

TDDs use web-app's template (`.agents/commands/spec-doc.md`, written with `author-prd-tdd`). Don't
change that file. `/ansh` adds one collapsed section after `## Nitty gritty details`:
`>>> ## Implementation milestones`, one block per `PR order` step. `PR order` stays the short
index teammates read.

IDs make everything traceable: ACs from the PRD are `AC-n`, failure-mode rows are `FM-n`,
decisions `D-n`, open questions `Q-n`, milestones `M-n` (matching the PR order step number).
Number them if the doc doesn't.

## Block

```
### M2 - <PR order step name>
Covers: AC-3, AC-4 | FM-2, FM-5 | Depends on: M1 | Parallel with: M3
Surface: visible | data-visible | invisible (why)

Changes
- Schema: <slice of Schema changes, or none>
- Service: <RPC/facade/repo changes and the errors callers see>
- Files: <slice of File blast radius, file:line>
- Gold-star: <existing slice to mirror>

Functional verification (red-first)
- AC-3: <check> -> expect <observable>. Fails today because <reason>.
- Could this pass while broken? <why not>

Performance verification
- <metric, baseline method, budget> | n/a: <reason>

Regression
- <suites and callers from blast radius> | FM-2 -> <check>

Rollout and rollback
- Flag: <name> | Rollout step: <n> | Rollback: <this milestone's piece>

Signals after merge
- <log, metric or trace that proves it in prod>

Exit gate
- <one runnable predicate: every check above green on the head SHA>
```

## Who writes what

- **I write:** the ACs and what proves each one (feature success).
- **The agent writes:** everything else in the block. `/ansh-plan` drafts missing blocks from
  `PR order`, `File blast radius`, `Failure modes` and `Rollout`, keeps them in `.ansh/plan.md`,
  and adds them to the Linear doc with a comment noting they were agent-drafted.

## Checks `/ansh-plan` runs on a TDD (Phase 0)

| Check | If it fails |
|---|---|
| Every AC is numbered and binary | Number it. Rewrite a vague one as Given/When/Then, mark `inferred`. |
| Every AC is covered by some milestone | Add it to the milestone that touches its surface. |
| Every FM row is caught by some check | Add a check to the owning milestone. |
| Every milestone has a Surface | Classify from `Surfaces touched` and the file list. |
| "Could pass while broken" has a real answer | Strengthen the check. |
| Open `Q-n` items | Settle by running something, or take an agent default (see [autonomy](autonomy.md)). |
| Irreversible rollout steps | Mark the milestone parked-at-merge. |
| Perf-sensitive milestone without a budget | Use the default budget and note it. |
