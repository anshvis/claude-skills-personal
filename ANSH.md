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
| [verification](skills/_shared/verification.md) | The verification contract, the derived surface and who verifies each half, regression, perf, evidence packs |
| [milestones](skills/_shared/milestones.md) | The `Implementation milestones` section added to web-app's spec-doc TDDs |
| [principles](skills/_shared/principles.md) | The engineering bar (from pstack) |
| [ledger](skills/_shared/ledger.md) | Iteration events via `ansh-log` |
| [memory](skills/_shared/memory.md) | Project memory in Beacon via `ansh-memory`: who reads it, who saves what, what gets approved |
| [stacking](skills/_shared/stacking.md) | PR topology, branch bases, merge order, never rewriting shared branches |
| [worktrees](skills/_shared/worktrees.md) | One worktree per work item, never leaving verified work uncommitted |
| [tickets](skills/_shared/tickets.md) | Branch names, PR link words, Linear status ownership |
| [runtime](skills/_shared/runtime.md) | Host mapping, model routing, independent review |

## Skills

| Skill | Goal |
|---|---|
| [`/ansh-small-loop`](skills/ansh-small-loop/SKILL.md) | Conduct one scoped ticket to a merged, verified PR. |
| [`/ansh-loop`](skills/ansh-loop/SKILL.md) | Conduct a project to merged, verified PRs, in dependency-ordered waves. |
| [`/ansh-plan`](skills/ansh-plan/SKILL.md) | TDD or ticket to milestones and self-contained task packets with verification contracts. |
| [`/ansh-cycle`](skills/ansh-cycle/SKILL.md) | Drive one task to a review PASS: task, review, route the verdict, within the round budget. |
| [`/ansh-task`](skills/ansh-task/SKILL.md) | One packet to the smallest diff that makes its red-first check pass, committed. |
| [`/ansh-verify`](skills/ansh-verify/SKILL.md) | Own the harness: feature map (local), run contracts by surface, write evidence. |
| [`/ansh-control`](skills/ansh-control/SKILL.md) | Drive the app's UI through Playwright or CDP and capture proof. |
| [`/ansh-backend`](skills/ansh-backend/SKILL.md) | Verify the backend directly: API, DB, jobs, signals and CI, under the right secrets config. |
| [`/ansh-review`](skills/ansh-review/SKILL.md) | Independent verdict in three modes: `task <id>`, `pr <n>` (the PR gate), `goal` (every AC). |
| [`/ansh-debug`](skills/ansh-debug/SKILL.md) | Bug to confirmed root cause, fix packets and a regression check that keeps running. |
| [`/ansh-ship`](skills/ansh-ship/SKILL.md) | Push the plan's PRs per stacking, open or update them with ticket links, start their PR loops. |
| [`/ansh-resolve`](skills/ansh-resolve/SKILL.md) | One pass over a PR's CI failures, comments and gate findings. The only skill that fixes PR findings. |
| [`/ansh-pr-loop`](skills/ansh-pr-loop/SKILL.md) | Babysit one PR: gate, resolve until mergeable, prove the head, merge under the merge rule. |
| [`/ansh-correct`](skills/ansh-correct/SKILL.md) | Turn a repeated mistake into a lint, type or CI check. PRs wait for my review. |
| [`/ansh-retro`](skills/ansh-retro/SKILL.md) | Read the ledger, propose cuts to these skills with the numbers, and work the memory queue. |
| [`/ansh-think`](skills/ansh-think/SKILL.md) | Options and tradeoffs to a recommendation. No code. |
| [`/ansh-save`](skills/ansh-save/SKILL.md) | Freeze in-flight state so another session can resume it. |

Glue they call by name: `effort-dial` (size the work), `chill-describe` (every commit and PR),
`gold-star` (hold work to a reference), `lightweight-sql` (any SQL or Drizzle diff), `linear-sync`
(reconcile tickets), `review-fresh` and `codex` (independent review), `claude-fix-prompt` (make a
shallow ask deeper before planning). From agentic-workflow: `ui-evidence`, `verify-web`,
`verify-ios`. CLI map for debugging and CI: [cli-tools](skills/_shared/cli-tools.md).

## How a run goes

```
/ansh-small-loop or /ansh-loop
  -> /ansh-plan
  -> per task: /ansh-cycle <id>
       -> /ansh-task <id> -> /ansh-verify run -> /ansh-control | /ansh-backend
       -> /ansh-review task <id>
            PASS | REVISE -> /ansh-task or /ansh-plan | DEBUG -> /ansh-debug -> /ansh-cycle <fix>
  -> /ansh-review goal          (failures -> /ansh-plan -> /ansh-cycle)
  -> /ansh-ship
       -> per PR: /ansh-pr-loop <n>
            -> /ansh-review pr <n> -> /ansh-resolve <n> -> /ansh-verify run -> merge | park
memory: plan, debug and review read it; debug, resolve, cycle, verify and backend save to it
weekly: /ansh-retro (skills, memory queue) and /ansh-correct (repo checks)
```

## State

- `.ansh/` in the repo (git-excluded): `plan.md`, `plan.json`, `tasks/<id>.md`, `discoveries.md`,
  `decisions.md`.
- `~/.agentic-workflow/ansh/events.jsonl`: the iteration ledger.
- Beacon project memory (`~/.beacon/endpoint/memory.db`), one per repo: lessons that outlive a run.
  Installed by `setup.sh`, local only.
- `~/.agentic-workflow/<repo-slug>/feature-map/` and `evidence/`: local, not committed.
- `~/.agentic-workflow/ansh-pr-loop/outcomes.jsonl`: merge outcomes.

## Keeping this current

Change a skill, then its row here. New skill: add `/ansh-<name>` and a row. Retired: remove both.
