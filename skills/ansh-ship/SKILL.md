---
name: ansh-ship
description: "Push the plan's PR branches per stacking, open or update each PR with the right base, body and ticket links, then start /ansh-pr-loop on it. Use for /ansh-ship, or when a loop has PR sections whose tasks all passed review."
---

# /ansh-ship

**Goal:** every ready `prs[]` entry in `.ansh/plan.json` is pushed, open on the right base with the
right links, and handed to `/ansh-pr-loop`.

**Uses:** [`/ansh-pr-loop`](../ansh-pr-loop/SKILL.md), [`/ansh-verify`](../ansh-verify/SKILL.md),
[`/chill-describe`](../chill-describe/SKILL.md), [stacking](../_shared/stacking.md),
[tickets](../_shared/tickets.md), [worktrees](../_shared/worktrees.md),
[autonomy](../_shared/autonomy.md), [ledger](../_shared/ledger.md) (`../_shared/ansh-log`),
[runtime](../_shared/runtime.md), [plan.json](../ansh-plan/references/plan-json.md).

Arguments: `/ansh-ship [<PR id> ...] [push-only] via=<ansh-loop | ansh-small-loop | direct>`.
With no ids, take every `prs[]` entry whose subtasks are all `done` and whose `merge_state` is
`todo` or `open`. `push-only` stops after step 3, for a dependent that must be cut from it.

## Steps

1. **Order the work.** Sort the chosen PRs small-first in dependency order per the topology in
   [stacking](../_shared/stacking.md). Work in each item's worktree
   ([worktrees](../_shared/worktrees.md)).
2. **Current and clean.** Run stacking's "Before pushing or opening a PR" on the branch: fetch,
   merge `origin/<base>`, and check that `git log` and the diff stat hold only this section's
   work. If the merge brought anything in, run `/ansh-verify run` for the PR's packets at the new
   head before going on.
3. **Push.** `git push origin <branch>`. Never force, never to `main` or `master`
   ([tickets](../_shared/tickets.md)). Stop here on `push-only`.
4. **Write the body.** Run `/chill-describe` for the PR body. Add the link lines from
   `prs[].links`, one `Depends on #<n>` per unmerged `depends_on` PR, and the parent in plain text,
   all per [tickets](../_shared/tickets.md).
5. **Open or update.** Look for an open PR on the branch (`gh pr list --head <branch>`).
   - None: `gh pr create --base <base> --title <title> --body-file <file>`.
   - One exists: `gh pr edit <n> --base <base> --body-file <file>`.
   - A PR template got injected: overwrite it with the chill-describe body.
6. **Umbrella.** In the integration topology, open the umbrella PR to `main` once, titled after the
   parent, `Closes <PARENT>`, the same way.
7. **Check the tickets.** Each linked ticket shows the PR. The parent shows no section PRs unless
   tickets says to link it there. Fix a gap with a Linear link (`save_issue`) and say so.
8. **Record.** Set `prs[].number` and `merge_state: open` in `plan.json`. Log
   `ansh-log ansh-ship pr-opened DONE --pr <n> --milestone <M-n> --surface <s>`.
9. **Hand off.** Right after each PR opens, start `/ansh-pr-loop <n> via=<via>`. Don't wait for
   the other PRs.

## Edge cases

| case | do |
|---|---|
| Log or diff stat shows another section's work | Wrong base. Fix it per stacking before opening. Never open a PR that carries someone else's diff. |
| Merge from `origin/<base>` landed after verification | Re-run `/ansh-verify run` before pushing. |
| Integration branch has no commits ahead of `main` yet | Open the umbrella once the first section merges into it. |
| A PR already exists for the branch | Update it. Never open a second one. |
| The existing PR isn't ours | Don't push, edit or comment. Report it. |
| A dependency PR is open or parked | Open this one stacked on it with `Depends on #<n>`. `/ansh-pr-loop` holds the merge. |
| PR or milestone is `parked_at_merge` | Open and ship it anyway. `/ansh-pr-loop` parks it per autonomy. |
| Push rejected as non-fast-forward | Fetch, merge, re-verify, push again. Never force. |
| Linear unavailable | Skip the ticket check with a note ([tickets](../_shared/tickets.md)). |
| Ticketless goal | No link lines. Branch is `ansh-<slug>`. |
| A subtask of the PR isn't `done` | Skip that PR. Report it as not ready. |

## Output

```
SHIP: DONE | PARTIAL | BLOCKED
PRS: <PR id> #<n> <url> base=<base> links=<words and tickets> loop=started | skipped (why)
TICKETS: <gaps fixed or none>
```

- **DONE**: every chosen PR is open and its loop started.
- **PARTIAL**: some were skipped, each with why.
- **BLOCKED**: nothing could ship. Name the missing piece.
