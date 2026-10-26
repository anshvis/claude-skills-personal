# Review gate

The one-time review gate of `/ansh-pr-loop`. It runs once per state of the PR's own code, and a
comment on the PR records it so later runs can reuse it.

## Reuse a recorded gate (own PRs only)

Find the newest top-level comment whose body starts with
`<!-- ansh-pr-loop:review-gate head=<sha> -->`. List the PR's own commits since then:

```bash
git log --no-merges --format=%H <sha>..origin/<head-branch> --not origin/<base-branch> origin/main
```

The `--not` part drops commits that came in by merging `main` or the base.

| Finding | Do |
|---|---|
| Empty list | The PR's code is unchanged. Reuse the gate: read its rows back and go to the fix step. Say "reusing review gate from `<sha>`". |
| Header lacks a lens (`ansh-review`, `review-fresh`, `independent`, `thermo-nuclear`) | Run only that lens, merge its rows in, and edit the comment. |
| Header says `ansh-review (triage)` only | Run the full gate and replace the comment. |
| Ticket, a parent ticket or the TDD has `updatedAt` after the gate's date | Re-run only `/ansh-review`. The target moved even if the code didn't. |
| Any commit listed | Run the full gate again and edit the comment. |
| `<sha>` isn't in the branch history | Treat as changed. Run the full gate. |

## Running the lenses

Pin one head SHA and give it to every lens. Each lens runs in its own fresh subagent
([runtime](../../_shared/runtime.md)). Brief each with: the pinned SHA, a read-only checkout or
`git diff origin/<base>...<sha>`, which skill file to read and apply, the output format below, and
that it must not edit, commit, push, post or delegate further (except `/review-fresh`'s own lens
subagents). The loop agent never reviews the code itself. It briefs, reads reports, merges them,
and posts.

| Lens | How |
|---|---|
| `/ansh-review` | PR mode with the PR number, SHA and `gate` flag: the gate's Independent lens is its independent pass, so it runs only its own adversarial pass. Return its verdict block ([output](../../ansh-review/references/output.md)); the loop agent posts its `<!-- ansh-review:merge-call -->` comment. Read `VERDICT`, `MERGE_LANE`, `PARKED` and `WAITING_ON` from it. |
| `/review-fresh` | Its capture rebases, so run it in a detached temporary worktree at the SHA, diffing against `origin/<base>`. Argument: the PR title as intent. |
| Independent | Per runtime's independent review, with the PR intent and riskiest areas as watch-outs. Record provider, model and independence. Label findings `independent`. |
| `/thermo-nuclear-code-quality-review` | It sets `disable-model-invocation`, so the Skill tool can't load it. Brief a background subagent to read `../thermo-nuclear-code-quality-review/SKILL.md` and apply it to the diff. Return findings as presumptive-blocker, major or minor with `path:line`. |

A lens the host can't run is marked `unavailable` in the header, never run in the loop agent.

## One severity scale

Collapse duplicates. Keep the strictest severity and both sources.

| Severity | From |
|---|---|
| blocker | `/ansh-review` `ACT_ON` items and `BUGS` (route `/ansh-debug`); review-fresh `blocker`; an independent critical finding; a thermo-nuclear presumptive blocker (a visible code-judo move left on the table, a file pushed past 1k lines, ad-hoc branching tangling a shared flow, scattered feature checks, an unneeded wrapper or cast contract, a duplicated helper or wrong layer) |
| major | review-fresh `major`; another structural thermo-nuclear finding; an `/ansh-review` `PLAN_GAP: large` |
| minor | review-fresh `minor`; an independent advisory finding; a thermo-nuclear legibility note; an `/ansh-review` `CONSIDER` item, `PLAN_GAP: small` or mixed kind |

`/ansh-review` `NOTED` and `DISMISSED` items don't become rows.

## The gate comment

One top-level comment per PR. Edit the existing one instead of adding another. PR's own voice: no
AI attribution, no emoji, one plain line per finding, no raw reviewer output.

```markdown
<!-- ansh-pr-loop:review-gate head=<full head sha> -->
**Review gate** for `<short sha>` (ansh-review + review-fresh + independent + thermo-nuclear, <YYYY-MM-DD>)

Checked against: <FND-1234 (closes), parent FND-1200, TDD: <title + link> | no linked ticket>
Verdict: <PASS | REVISE | DEBUG>. Kind: <setup | logic | wiring>. Blast radius: <low | medium | high>. Lane: <MERGE_LANE>. Parked: <no | yes>

Worst severity: <blocker | major | minor | none>

| Severity | Source | Finding | Where |
|---|---|---|---|
| major | review-fresh | <what is wrong and the failure it causes> | `path:line` |
| major | ansh-review | <criterion or TDD section, and how the diff misses it> | `path:line` or ticket key |
| minor | independent | ... | ... |

<"Clean: no findings." when the list is empty>
```

After the gate's fixes are pushed, mark each fixed row `fixed in <sha>`, mark each agent default
`agent default: <choice>`, and move `head=` to the pushed fix commit. Those fixes were verified
against the gate's findings, so they don't trigger a full re-review on the next run. Any later
non-merge commit does.
