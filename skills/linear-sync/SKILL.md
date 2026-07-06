---
name: linear-sync
description: Reconcile Linear with the real state of the current Claude Code session so the global context stays accurate. Detects the active ticket(s) from the git branch (e.g. `rev-644-...` → REV-644) and its project/parent/siblings, compares Linear's recorded state (status, description, checklist, relations, PR links) against what has actually happened in this chat (branch, commits, PRs, decisions made, scope changes, completed plan items), proposes a sync plan, and — after a confirm gate for any outward-facing edit — applies status transitions, decision comments, description/checklist updates, and PR/relation links. Invoke when the user says "sync linear", "/linear-sync", "update the tickets", "make sure linear is up to date", or after a working session that changed scope, made decisions, or moved work forward.
---

# linear-sync

Keep Linear honest about what this session actually did. The failure mode this prevents: a ticket sitting in `Backlog` with a stale description while the branch already has commits, a PR, and three design decisions that live only in the chat. After this skill runs, someone opening the ticket should see the same reality you see.

This skill **writes to Linear**, which is outward-facing. Comments are append-only and low-risk; **status changes and description edits are confirmed with the user before applying** (see your global feedback on not overwriting outward-facing artifacts without authorization).

## Step 1 — Identify the work in scope

1. Get the current branch: `git branch --show-current`. Extract the ticket id from the prefix (`rev-644-...` → `REV-644`, `roi-1595-...` → `ROI-1595`). If the branch has no ticket prefix, ask the user which ticket(s) to sync.
2. `mcp__claude_ai_Linear__get_issue` for that id with `includeRelations: true`. Note its `parentId` and `projectId`.
3. If it has a parent (epic), fetch the parent too, and `list_issues` filtered to the same `project` to pull sibling subtasks — the session may have touched more than one (e.g. a stacked PR series). Build the **candidate set** of issues to reconcile.
4. Gather session ground truth — do NOT ask the user to retype any of it:
   - Branch + its commits vs. the base branch: `git log --oneline <base>..<branch>` (base is usually `dev` or the parent ticket's branch for a stacked PR).
   - Open PR for the branch and its base: `gh pr view --json number,title,isDraft,baseRefName,url` (note if it stacks onto a parent ticket's PR rather than `dev`).
   - Decisions, scope changes, and resolved open-questions established **in this chat** — the things that exist nowhere but the conversation. These are the highest-value sync targets.
   - Which plan/checklist items in the ticket description are now actually done.

## Step 2 — Compute drift

For each candidate issue, diff Linear's recorded state against session reality and bucket the gaps:

- **Status drift** — work started/PR opened but issue is `Backlog`/`Todo`; or work merged but issue not `Done`. Map to the team's real workflow states (fetch via `get_team` / the issue's `statusType` if unsure of names).
- **Description / scope drift** — a decision in chat contradicts, narrows, or extends the ticket body (e.g. "we chose `gist(badge, timeRange)` over a plain GiST", "deferred profileId to the downstream feature"). Note the exact lines that are now wrong or missing.
- **Checklist drift** — plan checkboxes that are now complete.
- **Link drift** — a PR exists but isn't attached; a `relatedTo`/`blockedBy` relation discovered in chat isn't recorded; a stacked-PR base isn't reflected.
- **Decision log** — material decisions with no home in Linear (these become comments, never silent description rewrites).

If nothing drifted, say so in one line and stop — don't manufacture busywork.

## Step 3 — Propose the sync plan (confirm gate)

Present a compact, per-issue plan grouped by action type. Example shape:

```
REV-644
  status:  Backlog → In Progress        (branch has commits + draft PR #11409)
  comment: + decision log (gist(badge,timeRange) chosen; profileId deferred)
  body:    update "Open (reviewer)" line to record the GiST-scope decision
  links:   attach PR #11412 (base: rev-611, stacked)
```

Then **confirm before any outward-facing write** using `AskUserQuestion`:
- Comments (append-only): safe to apply on confirm.
- **Status transitions and description/body edits: always confirm**, since they overwrite shared state. Show the exact before/after for body edits.
- If the user pre-authorized ("just sync everything"), skip the per-item gate but still echo what you're about to do in one block before doing it.

Respect the user's saved preferences: no emojis, no AI-author trailers, no "as discussed" filler in anything written to Linear. Send real newlines in Linear strings, never literal `\n`.

## Step 4 — Apply

In dependency order (parent before children when statuses cascade):

- Status: `mcp__claude_ai_Linear__save_issue` with the new `stateId`/state.
- Decision comment: `mcp__claude_ai_Linear__save_comment` — a tight bullet list of decisions, each with its *why*, plus a link to the PR/branch. This is the durable record; favor it over rewriting the description.
- Description/checklist edits: `save_issue` with the updated `description` (markdown, real newlines). Edit surgically — preserve the existing structure, flip checkboxes, append a short "Decisions" note rather than rewriting prose, unless the user asked for a fuller rewrite.
- PR attachment / relations: attach the PR and set `relatedTo`/`blockedBy`/parent as discovered.

## Step 5 — Confirm

Print one line per issue touched:
`REV-644 → In Progress · comment added · PR #11412 attached`
End with a single summary line. Nothing more.

## Anti-patterns — don't

- **Don't** silently rewrite a ticket description or move status without the confirm gate — these are shared, outward-facing artifacts.
- **Don't** invent decisions or progress that didn't happen in the session. Sync reality, not aspiration.
- **Don't** dump the chat transcript into a comment — extract decisions and artifacts, not narration.
- **Don't** create new issues here (that's planning) or new documents (that's `/record-in-linear`). This skill reconciles existing issues.
- **Don't** mark something `Done` unless the work is actually merged/verified — "code written" is not "done".
- **Don't** clobber description structure; flip checkboxes and append, prefer comments for decisions.
- **Don't** add emojis or AI-author trailers to anything written to Linear.
