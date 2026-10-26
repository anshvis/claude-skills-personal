---
name: ansh-task
description: "Turn one task packet from .ansh/tasks/ into the smallest diff that makes its red-first verification pass, or kick it back as NEEDS_REPLAN. Use for /ansh-task <id> or an explicit single-task request with criteria."
---

# /ansh-task

**Goal:** one packet -> the smallest diff that makes its red-first verification pass.

**Uses:** [runtime](../_shared/runtime.md), [autonomy](../_shared/autonomy.md),
[verification](../_shared/verification.md), [principles](../_shared/principles.md),
[stacking](../_shared/stacking.md), [worktrees](../_shared/worktrees.md), [tickets](../_shared/tickets.md), [ledger](../_shared/ledger.md) (`../_shared/ansh-log`),
[/ansh-verify](../ansh-verify/SKILL.md), [/lightweight-sql](../lightweight-sql/SKILL.md),
[/chill-describe](../chill-describe/SKILL.md), [/ansh-plan](../ansh-plan/SKILL.md),
[/ansh-ship](../ansh-ship/SKILL.md).

The packet is your whole world. Read `.ansh/tasks/<id>.md` (index `.ansh/plan.json`) and the docs
it cites (`.ansh/plan.md`, `handoffs/*.md`). Don't read the planner's reasoning. Don't survey the
codebase. Model and effort come from the packet stamp, routed per runtime.md.

## Steps

1. **Load the packet.** A task id reads `.ansh/tasks/<id>.md`. An inline task with explicit
   done-criteria also works. Neither: return BLOCKED, "No scoped task. Run `/ansh-plan` first."
2. **Worktree.** Work in the item's worktree per [worktrees](../_shared/worktrees.md).
3. **Ticket to In Progress.** Move the packet's own tickets per [tickets](../_shared/tickets.md).
4. **Base.** Run stacking.md "Before starting work": fetch, take the base from
   `plan.json.prs[].base`, cut from `origin/<base>` or merge it in, confirm the dependency's code is
   present. Merge, never rebase or force-push.
5. **Conviction gate.** Before touching code: are the files named, does the gold-star fit, is every
   criterion testable, is the Verification contract runnable, are there zero open questions? A
   question of fact (does this column exist, what does this call return) gets settled by running
   something. A scope gap kicks back (step 11). Don't start on low conviction.
6. **Red first.** Write each check in the packet's `## Verification` and run it on the base per
   [verification](../_shared/verification.md) (`/ansh-verify run --red-first`). Record the failure:
   command, output, SHA.
   Log `ansh-log ansh-task red-check DONE --task <id> --ids <AC/FM ids>`.
7. **Implement.** Read the named files and gold-star references. Write the smallest diff that turns
   the checks green, mirroring the gold-star. Name the data shape first. No adjacent refactors,
   renames or "while I'm here".
8. **SQL or Drizzle in the diff:** load `/lightweight-sql` and apply it.
9. **Commit, then verify.** Commit the candidate per `/chill-describe` so the SHA is real. Run
   `/ansh-verify run` for the packet at that SHA: every check, regression, perf
   and the surface path in verification.md. Write the evidence pack. Every done-criterion gets
   met or not met with evidence (command + result). Log
   `ansh-log ansh-task done DONE --task <id> --attempt <n> --surface <surface>`.
10. **Stop at the verified commit.** Any change after verification is a new commit and a new
    verify ([worktrees](../_shared/worktrees.md)). Don't push or open a PR: `/ansh-ship` does.
11. **Kick back** when scope is wrong (see Edge cases). Append to `.ansh/discoveries.md`: the task,
    what you found, the specific gap, why it blocks. Describe the problem. Don't propose and apply
    a fix. Set the task's `status` to `needs_replan` in `.ansh/plan.json`. Log
    `ansh-log ansh-task done NEEDS_REPLAN --task <id> --reason <reason>`. Return NEEDS_REPLAN. The
    orchestrator routes it to `/ansh-plan`, which resolves it without me per autonomy.md.

## Edge cases

| case | do |
|---|---|
| Needs files the packet didn't name, or unfinished work | Kick back NEEDS_REPLAN. |
| Done-criterion ambiguous or untestable | Kick back NEEDS_REPLAN. |
| Touches shared, migration or customer-facing surface the packet didn't flag | Kick back NEEDS_REPLAN. |
| Needs higher-level context to resolve correctly | Kick back NEEDS_REPLAN. |
| Unknown fact (schema, return value, timing) | Run something to settle it. Not a kick back. |
| Red check passes on base and can't be made to fail | The behavior exists or the check is wrong. Kick back with the output. |
| Packet has done-criteria but no `## Verification` | Build red-first checks from Done-criteria and Tests to write. Note it in the report. |
| Same approach failed ~3 times | Stop. Kick back with each attempt's evidence. Don't try a new direction yourself. |
| Packet's model looks too weak mid-task | Escalate per runtime.md. Log it to `.ansh/decisions.md`. |
| Dependency code missing, or base not named in the plan | BLOCKED. Don't rebuild the missing piece. |
| Tool or environment failure (not scope) | BLOCKED with what's missing. |
| Verification would need prod writes, deploy or infra apply | Never do it. Verify on local or a branch database. Park per autonomy.md if that's impossible. |

Never change direction. Don't guess a new approach, expand scope to "just handle it", or patch
around an unknown. Direction belongs to `/ansh-plan`.

Out of scope here: planning questions, the independent review (`/ansh-review` reruns your checks),
pushing and PRs (`/ansh-ship`), and any Linear edit beyond In Progress.

## Output

- Per check: id, red result on base, green result on head, evidence path.
- Per done-criterion: met or not met, with evidence.
- Principles that changed a decision, and what they changed (principles.md).
- Files touched, head SHA, attempt number.

End with one status:
- **DONE**: every check green at the head SHA with evidence.
- **NEEDS_REPLAN**: scope was wrong. Point at the `.ansh/discoveries.md` entry.
- **BLOCKED**: tooling, environment or base problem. Say what was tried and what's missing.
