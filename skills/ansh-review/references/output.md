# /ansh-review output

## Verdict block

```
VERDICT: PASS | REVISE | DEBUG
SHA: <head sha reviewed>
CRITERIA: <n met> / <n total>
VERIFICATION: rerun <pass | fail> at <sha> | strength: <ok | weak: why it could pass while broken>
SURFACE: declared <class> | diff <class> | <match | mismatch: files>
KIND: setup | logic | wiring [mixed: ...]
PLAN_GAP: none | small | large - <one line per gap, with ticket key or TDD section>
PLAN_SOURCES: <packet, FND-1234 (closes), parent FND-1200, TDD link | missing: ...>
BLAST_RADIUS: low | medium | high - <why>
MERGE_LANE: standard | deep - <reasons>
DEEP_LANE: fresh-context review <done | n/a> | independent re-verify <pass | fail | n/a>
PARKED: no | yes - <never-do item, exact command or click Ansh would need>
DEPENDS_ON: [#<n> open | merged | parked]
WAITING_ON: [#<n> ...]   # open or parked dependencies; merge holds until they merge
REVIEWERS: [<provider/model>, independence: cross-model | fresh-context | in-session] ...
CONCERNS: [unavailable capabilities or reduced independence]
ACT_ON: [ {task, finding, raised_by, route: ansh-task | ansh-plan, suggested fix} ... ]
CONSIDER: [ {finding, raised_by, tradeoff} ... ]
NOTED: [ ... ]
DISMISSED: [ {finding, raised_by, why} ... ]
AGREEMENT: <where reviewers agreed and diverged, and what that says>
BUGS: [ {symptom, why root cause is non-obvious} ... ]   # -> /ansh-debug
REPEAT_CLASSES: [ {class, reason, seen: n, events} ... ]   # -> /ansh-correct
```

- **PASS**: no Act on items, verification rerun passed at the head SHA, plan gap none or small
  with its fix noted. The merge rule in autonomy.md decides the rest.
- **REVISE**: Act on items go back to `/ansh-task`, or to `/ansh-plan` when the fix needs a
  decision or the plan gap is large. Never let the specialist guess through a plan gap.
- **DEBUG**: BUGS go to `/ansh-debug` for a root cause before any fix.

## PR comment

Add or edit one comment starting `<!-- ansh-review:merge-call -->`. Write it in the PR's voice:
no AI attribution, no emoji.

```markdown
<!-- ansh-review:merge-call -->
**Review: PASS | REVISE | DEBUG** at `<short sha>` | Lane: standard | deep | Parked: no | yes

Kind: wiring (registers the forecast cron, adds the RPC route)
Verification: rerun green at `<short sha>` (evidence: <path or link>)
Plan gap: small. FND-2710 names the input `censusInput`; the diff calls it `census`.
Blast radius: high. The cron runs nightly for every unit, behind `forecast-v2` (off).
Parked: <why, and the exact step Ansh would take> <omit when not parked>
Waiting on: #1234 (open) <omit when there are no open dependencies>

What to look at: <the one or two places a reader should read first>
```
