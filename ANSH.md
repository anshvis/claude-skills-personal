# /ansh

My skill set for taking a ticket or TDD to a merged, verified PR without me in the loop. I write
feature success (the numbered ACs). The skills do the rest and prove it with CLI or web evidence.
Everything under `/ansh-` is mine and current. The `SKILL.md` files are the source of truth; this
file is the index.

Runs on Claude Code (`/ansh-plan`) and Codex (`$ansh-plan`). See [runtime](skills/_shared/runtime.md).

## Shared rules

| Doc | Owns |
|---|---|
| [autonomy](skills/_shared/autonomy.md) | No human in the loop, agent defaults, never-do list and parking, merge rule, stop conditions, subagents |
| [verification](skills/_shared/verification.md) | The verification contract, surface classes, regression, perf, evidence packs |
| [milestones](skills/_shared/milestones.md) | The `Implementation milestones` section added to web-app's spec-doc TDDs |
| [principles](skills/_shared/principles.md) | The engineering bar (from pstack) |
| [ledger](skills/_shared/ledger.md) | Iteration events via `ansh-log` |
| [stacking](skills/_shared/stacking.md) | Branch bases, merge order, never rewriting shared branches |
| [runtime](skills/_shared/runtime.md) | Host mapping, model routing, independent review |

## Skills

| Skill | Goal |
|---|---|
| [`/ansh-small-loop`](skills/ansh-small-loop/SKILL.md) | One scoped ticket to a merged, verified PR. |
| [`/ansh-loop`](skills/ansh-loop/SKILL.md) | A project to merged, verified PRs, in dependency-ordered waves. |
| [`/ansh-plan`](skills/ansh-plan/SKILL.md) | TDD or ticket to milestones and self-contained task packets with verification contracts. |
| [`/ansh-task`](skills/ansh-task/SKILL.md) | One packet to the smallest diff that makes its red-first check pass. |
| [`/ansh-verify`](skills/ansh-verify/SKILL.md) | Own the harness: feature map (local), run contracts, write evidence. |
| [`/ansh-control`](skills/ansh-control/SKILL.md) | Drive the real app (Playwright/CDP for UI, tmux/PTY/curl for CLI and API) and capture proof. |
| [`/ansh-review`](skills/ansh-review/SKILL.md) | Independent verdict: rerun verification, plan gap, blast radius, merge lane. |
| [`/ansh-debug`](skills/ansh-debug/SKILL.md) | Bug to confirmed root cause, fix and a regression check that keeps running. |
| [`/ansh-resolve`](skills/ansh-resolve/SKILL.md) | One pass over a PR's CI failures and review comments. |
| [`/ansh-pr-loop`](skills/ansh-pr-loop/SKILL.md) | Resolve until mergeable, then merge under the merge rule. |
| [`/ansh-correct`](skills/ansh-correct/SKILL.md) | Turn a repeated mistake into a lint, type or CI check. PRs wait for my review. |
| [`/ansh-retro`](skills/ansh-retro/SKILL.md) | Read the ledger and propose cuts to these skills, with the numbers. |
| [`/ansh-think`](skills/ansh-think/SKILL.md) | Options and tradeoffs to a recommendation. No code. |
| [`/ansh-save`](skills/ansh-save/SKILL.md) | Freeze in-flight state so another session can resume it. |

Glue they call by name: `effort-dial` (size the work), `chill-describe` (every commit and PR),
`gold-star` (hold work to a reference), `lightweight-sql` (any SQL or Drizzle diff), `linear-sync`
(reconcile tickets), `review-fresh` and `codex` (independent review), `claude-fix-prompt` (make a
shallow ask deeper before planning). From agentic-workflow: `ui-evidence`, `verify-web`,
`verify-ios`. CLI map for debugging and CI: [cli-tools](skills/_shared/cli-tools.md).

## How a run goes

```
TDD (spec-doc + milestones, ACs written by me)
  -> /ansh-plan     Phase 0 checks the TDD, packets with red-first checks, plan challenge
  -> per task:  /ansh-task -> /ansh-verify run -> /ansh-review
                  PASS -> next | REVISE -> /ansh-task | DEBUG -> /ansh-debug -> new packets
  -> whole-goal review against the ACs
  -> PRs via stacking + chill-describe -> /ansh-pr-loop -> merged (or parked, with the reason)
  -> report: shipped, parked, agent defaults, inferred ACs, .ansh/decisions.md
weekly: /ansh-retro (skills) and /ansh-correct (repo checks)
```

## State

- `.ansh/` in the repo (git-excluded): `plan.md`, `plan.json`, `tasks/<id>.md`, `discoveries.md`,
  `decisions.md`.
- `~/.agentic-workflow/ansh/events.jsonl`: the iteration ledger.
- `~/.agentic-workflow/<repo-slug>/feature-map/` and `evidence/`: local, not committed.
- `~/.agentic-workflow/ansh-pr-loop/outcomes.jsonl`: merge outcomes.

## Keeping this current

Change a skill, then its row here. New skill: add `/ansh-<name>` and a row. Retired: remove both.
