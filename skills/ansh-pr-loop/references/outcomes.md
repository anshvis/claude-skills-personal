# Outcome ledger

Counts how many PRs the loop actually merges. Separate from the iteration ledger
([ledger](../../_shared/ledger.md)), which logs phases.

Append one JSON line to `~/.agentic-workflow/ansh-pr-loop/outcomes.jsonl` (create the directory if
needed) each time the loop merges a PR or ends a run:

```json
{"ts":"<ISO time>","repo":"<owner/repo>","pr":<n>,"head":"<sha>","via":"<ansh-loop | ansh-small-loop | direct>","merge_call":"<standard | deep | not-own>","outcome":"<outcome>","waiting_on":[<n>],"reason":"<one line>"}
```

| Field | Meaning |
|---|---|
| `via` | The conductor `/ansh-ship` passed as `via=<name>` (`ansh-loop` or `ansh-small-loop`), else `direct`. |
| `merge_call` | `/ansh-review`'s `MERGE_LANE` (`standard` or `deep`), or `not-own` for someone else's PR. Stats count any other value in older lines as `standard`. |
| `outcome` | One of the values below. |
| `waiting_on` | `/ansh-review`'s `WAITING_ON` at the end of the run, else `[]`. |

| Outcome | Written when |
|---|---|
| `auto_merged` | The loop ran `gh pr merge`, or armed `--auto` and saw it merge. |
| `user_asked_merge` | Ansh told the loop to merge in his own message. |
| `waiting_on_parent` | Converged, but a dependency is still open when the run ends. |
| `parked` | `/ansh-review` said `PARKED: yes`: merging would be irreversible ([autonomy](../../_shared/autonomy.md)). Verified and left unmerged. |
| `awaiting_approval` | Branch protection needs a non-author approval, a human change request awaits re-review. Review requested. |
| `needs_review` | Someone else's PR. The loop reported findings and stopped. |
| `safety_cap` | The iteration cap hit with work left. |
| `stopped_by_user` | Ansh cancelled the run. |
| `needs_decision` | Not written by new runs. Kept so older lines still parse. |

Write a new line when a waiting, parked or awaiting PR later merges. Never rewrite old lines, so
the file stays a history.

## `/ansh-pr-loop stats`

Read the ledger and report, for a date range (default: the last 7 days):
- PRs by latest outcome.
- The auto-merge rate overall and for `via=ansh-loop`.
- Every PR whose latest outcome is `waiting_on_parent`, `parked` or `awaiting_approval`, with how
  long it has waited.
