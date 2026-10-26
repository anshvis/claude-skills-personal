---
name: ansh-save
description: Freeze in-flight work (goal, progress, repo state, decisions and why, open questions, landmines, ledger position, next steps) into .ansh/saves/ so another session or provider can resume it; use /ansh-save or when asked to save context or hand work off.
---

# /ansh-save

**Goal:** one file a fresh agent reads cold and resumes correctly from.

**Uses:** [ledger](../_shared/ledger.md), [autonomy](../_shared/autonomy.md) (decision trail),
[runtime](../_shared/runtime.md), `.ansh/plan.md`, `.ansh/decisions.md`.

Code is on disk and in git. What's lost on a restart is the context that lives only in the
conversation: why one approach beat another, the landmine already stepped on, the half-formed
next step, the thing in flight. Capture that. This is synthesis, not new thinking: be thorough on
capture, not clever.

## Steps

1. **Gather machine state first.** Don't reconstruct from memory what git knows:
   ```bash
   date +%F
   git rev-parse --abbrev-ref HEAD; git rev-parse HEAD
   git log --oneline -15; git status --short
   git log --oneline origin/main..HEAD
   gh pr view --json number,title,url,state,statusCheckRollup 2>/dev/null; gh pr checks 2>/dev/null
   ```
   Note the ticket from the branch prefix. Read `.ansh/plan.md`, `.ansh/decisions.md` and
   `.ansh/discoveries.md` if present. Link them, don't copy them.
2. **Find the ledger position.** Read the last events for this goal or branch from
   `~/.agentic-workflow/ansh/events.jsonl` (or `ANSH_LEDGER`): the last skill, phase, verdict,
   task, attempt and SHA. That's where the loop stands.
3. **Synthesize** the conversation into the template. Every non-obvious decision gets its reason
   and what was ruled out.
4. **Write** `.ansh/saves/<date>-<slug>.md` and copy it to `.ansh/saves/LATEST.md`. Slug from the
   ticket or branch. Never overwrite an earlier save: the trail matters.
5. **Route durable facts.** A preference, recurring gotcha or project constraint that outlives
   this work goes to project memory per [memory](../_shared/memory.md). A recurring code mistake
   goes to `/ansh-correct`.
6. Log `ansh-log ansh-save saved DONE --note "<save path>"`.

## Template

```markdown
# Save: <title> (<date>)

Branch: <branch> | SHA: <sha> | Ticket: <id + link> | PR: <#, url, state>

## Goal
<2-3 lines. The why, not just the task.>

## Status
- Done (with evidence): <commits, PRs, verified checks, evidence dirs>
- In progress: <what's half-built and exactly where it stands>
- Not started: <remaining work>

## Ledger position
<last event: skill, phase, verdict, task, attempt, sha. Open REVISE or DEBUG and its reason.>

## Repo state
- Branch commits vs base: <oneline list>
- Working tree: <clean | dirty files and what they are>
- CI: <green | what's failing and the error>

## Decisions (and why)
<Each call, its reason, what was ruled out. Agent defaults and parks: see
[.ansh/decisions.md](../decisions.md).>

## Open questions and things in flight
<Unsettled facts and how to settle them, parked items, reviews or CI runs in flight.>

## Landmines
<What already bit us or will bite the next session.>

## Next steps
1. <concrete first move on resume>

## Pointers
- Files: <path:line, what's there>
- Related: <plan sections, tickets, evidence dirs, skills to run on resume>

## How to resume
<One line: read this, then run X or continue at step N.>
```

## Resume

Read `.ansh/saves/LATEST.md` (or the named save). Rebuild state from Repo state, Ledger position
and Decisions. Start at the first next step. If the branch moved since the save, trust git and
the ledger over the file. Check that `path:line` pointers still resolve before acting on them.

## Edge cases

| case | do |
|---|---|
| No `.ansh/` dir | Create `.ansh/saves/`. `.ansh/` is the loop's gitignored working dir. |
| No `.ansh/decisions.md` | Write `Decisions` inline and say there's no trail file. |
| Ledger missing or no events for this goal | Write `Ledger position: none` and the reason. |
| Not a git repo, or no PR | Skip those lines with a note. Don't invent them. |
| Save older than HEAD on resume | Treat it as a starting point. Reconcile with git first. |
| Tempted to paste the transcript | Don't. Distill to decisions, state and next moves. |

Boundaries: a save isn't memory (durable cross-session facts) and isn't a plan (`/ansh-plan` owns
`.ansh/plan.md`). It points at both and replaces neither.

## Output

`DONE` with the save path and the first next step.
