---
name: ansh-save
description: HANDOFF / context-freeze in the Karpathy loop. Captures everything that would be lost if this chat ended — the goal, what's done vs not, the repo state (branch/commits/PRs/CI), the decisions made AND their rationale, open questions, landmines discovered, and the ordered next steps — into one durable, resumable .md under .ansh/saves/. The point is the REASONING that lives only in the chat: why a decision went the way it did, what was ruled out and why, the gotcha you hit at 2am. A fresh session reads the save file and picks up where you left off without re-deriving anything. Use when the user says "/ansh-save", "save context", "save this for later", "I'm stopping, snapshot this", or before stepping away from in-progress work. NOT for durable cross-session facts (that's memory) and NOT a plan (that's /ansh-plan's .ansh/plan.md) — this is a point-in-time work handoff.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Skill
---

# /ansh-save — Context freeze / handoff

Stopping mid-stream. The expensive thing in this chat isn't the code — that's on disk and in
git. It's the **context that exists only in the conversation**: why this approach won over the
one I ruled out, the landmine I already stepped on so the next session doesn't, the half-formed
next step, the thread I'm waiting on. Lose that and the resume costs an hour of re-derivation.

This skill freezes that into one `.md` a future me (or a fresh agent) reads cold and continues.

**Effort: cheap.** This is synthesis of what already happened, not new thinking. Sonnet-tier.
Be thorough on *capture*, not clever.

## Where it writes

```
.ansh/saves/<YYYY-MM-DD>-<short-slug>.md   # one handoff, timestamped + named
.ansh/saves/LATEST.md                       # symlink-or-copy pointer to the newest save
```

- `.ansh/` is the loop's gitignored working dir (same home as `plan.md`, `tasks/`,
  `discoveries.md`). Create `.ansh/saves/` if absent.
- Slug from the active ticket/branch (e.g. `rev-612-realtime-sync` → `rev-612-merge-cron`).
- Get the date from `date +%F` — never guess it.
- Multiple saves accumulate; newest wins. Don't overwrite an old one — append a new file so the
  trail of where-I-was-when survives.

## Process

1. **Gather the machine-knowable state first** (don't make the human tell you what git knows):
   ```bash
   git rev-parse --abbrev-ref HEAD
   git log --oneline -15
   git status --short
   git log --oneline origin/main..HEAD          # what's on this branch vs base
   gh pr view --json number,title,url,state,statusCheckRollup 2>/dev/null
   gh pr checks 2>/dev/null
   ```
   Also note the active Linear ticket (from the branch prefix) and read `.ansh/plan.md` /
   `.ansh/discoveries.md` if they exist — fold their live state in, don't duplicate them.
2. **Synthesize the conversation** into the template below. The bar: a competent stranger with
   repo access reads only this file and resumes correctly. Capture the *why*, not just the *what*
   — every non-obvious decision gets its rationale and what was rejected.
3. **Write** the file, update `LATEST.md`, and confirm the path back to the user.
4. If anything in the save is actually a durable cross-session fact (a preference, a recurring
   gotcha, a project constraint), also offer to persist it to memory — the save file is
   point-in-time and will go stale; memory is forever.

## The template

```markdown
# Save: <title> — <YYYY-MM-DD>

**Branch:** <branch>  ·  **Ticket(s):** <REV-xxx + links>  ·  **PR:** <#/url/state>

## Goal
<What we're actually trying to achieve, in 2-3 lines. The why, not just the task.>

## Status
- ✅ Done (with evidence): <commit shas / PRs / verified checks>
- 🔄 In progress: <what's half-built, where exactly it stands>
- ⬜ Not started: <remaining work>

## Repo state
- Last commits: <oneline list of the branch's commits vs base>
- Working tree: <clean | the dirty files and what they are>
- CI / checks: <passing | what's failing and the error>

## Decisions made (and why)
<The reasoning that lives only in the chat. For each: the call, the rationale, and what was
ruled out. e.g. "Kept the mock UKG factory over dev's inline mocks — factory is the single
type-break point; dropping it reintroduces the per-package fragility it was built to kill.">

## Open questions / waiting on
<Pending user decisions, unanswered questions, external things in flight (a review, a deploy).>

## Landmines / gotchas
<Things that already bit us or will bite the next session. e.g. "drizzle-kit generate surfaces
unrelated audit.record_version casing drift — do NOT regenerate; hand-edit the snapshot.">

## Next steps (ordered, actionable)
1. <concrete first move on resume>
2. ...

## Pointers
- Key files: <path:line — what's there>
- Related: <plan.md sections, other tickets, skills to invoke on resume>

## How to resume
<One line: "Read this, then run X / continue at step N.">
```

## Resume (the other half)

To pick back up: read `.ansh/saves/LATEST.md` (or the named save), reconstruct state from its
Repo-state + Decisions sections, and start at its first Next step. If the branch moved since the
save, trust git over the file and reconcile. A save older than the current HEAD is a starting
point, not gospel — verify file/line pointers still resolve before acting on them (same caveat as
recalled memories).

## Boundaries

- **Not memory.** Memory (`~/.claude/.../memory/`) is durable, cross-session, deduplicated facts.
  A save is a disposable point-in-time snapshot of one work session. If a fact deserves to outlive
  this work, route it to memory instead — don't let saves become a second, staler memory store.
- **Not a plan.** `/ansh-plan` owns `.ansh/plan.md` (the durable understanding + subtask packets).
  A save references the plan's live state; it doesn't replace or re-decompose it.
- **Don't dump the transcript.** Synthesize. A 4000-word wall of chat is as useless on resume as
  no notes — distill to decisions, state, and next moves.
