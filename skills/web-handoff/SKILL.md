---
name: web-handoff
description: HANDOFF the current terminal session to Claude Code Web (or your phone / another device) via Linear. Snapshots the working context — goal, git branch/commits/PRs/CI, what's done vs open, decisions + their rationale, landmines, and the ordered next steps — into a PERSONAL Linear ticket (assigned to you, labeled `web-handoff`, NOT linked to any epic/project/relation) so a Claude Code Web session pointed at the same GitHub repo can pick it up as context and keep solving. This is the cloud-travelling mirror of /ansh-save — /ansh-save writes to `.ansh/` which is git-excluded and never leaves the laptop; this writes to Linear, which the web sandbox and your phone can all read. Use when the user says "/web-handoff", "hand this off to web", "continue this on web/my phone", or wants to move work off the laptop. Pair with /web-read to pull it back into a terminal.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - mcp__claude_ai_Linear__save_issue
  - mcp__claude_ai_Linear__list_issues
  - mcp__claude_ai_Linear__get_issue
  - mcp__claude_ai_Linear__list_teams
  - mcp__claude_ai_Linear__list_projects
  - mcp__claude_ai_Linear__list_issue_labels
  - mcp__claude_ai_Linear__list_comments
  - mcp__claude_ai_Linear__save_comment
---

# /web-handoff — Terminal → Web handoff via Linear

`/ansh-save` captures a handoff to `.ansh/saves/` — perfect for the *same machine*, useless for the
cloud: `.ansh/` is git-excluded (local `.git/info/exclude`), so it never reaches a Claude Code Web
sandbox (which boots from your GitHub repo) or your phone. This skill puts the same handoff **into
Linear**, the one place the laptop, the web sandbox, and your phone all reach.

The point is the same as `/ansh-save`: capture the **reasoning that lives only in the chat** — why a
decision went the way it did, what was ruled out, the landmine you hit — plus the concrete repo/PR
state, so a fresh session on another device resumes with zero re-derivation.

## Channel constraints — READ FIRST (learned 2026-07-06)

The security / auto-mode classifier **hard-blocks the assistant from uploading private-repo content**
(source code, file paths, architecture, DB schema, business logic) **to external personal cloud
services — Google Drive, Notion, etc. — as data exfiltration. Sanitizing the content does NOT clear
it** (a plan with only file paths + architecture was still denied). Do **not** attempt Drive / Notion /
other external-cloud uploads for a handoff — it will be denied every time.

- The **company Linear workspace is in-boundary** (it already holds repo/PR references) and is the
  intended destination — but a handoff there is only **private** if it lives in a **private team**
  (Step 2). Assignment / label / project do NOT make it private, and **many users cannot create teams**
  (only join them), so a private Linear destination may simply be unavailable.
- **If no private in-boundary destination exists, do NOT push the handoff to any external service.**
  Instead PRODUCE the handoff and let the **user relocate it themselves** — that does not cross the
  tool trust boundary. Preferred fallback: **write the handoff to a local file and surface it with
  `SendUserFile`** for the user to upload into Claude Web; or print the markdown in-chat for the user
  to paste. This is the reliable, privacy-preserving path when private Linear isn't an option.

## Step 1 — Gather the context (don't skip the "why")

Collect, in this order:
- **Goal** — the ticket/prose driving the work, and the definition of done.
- **Repo state** — `git rev-parse --abbrev-ref HEAD` (branch), `git rev-parse HEAD` (sha),
  `git log --oneline -15`, `git status --short`. Note the base branch (usually `dev`).
- **PRs / CI** — `gh pr list --head <branch>` and for each open PR `gh pr view <n> --json
  number,title,url,state,baseRefName,statusCheckRollup` (state + check summary). Capture stacked-PR
  bases if relevant.
- **Linear** — any tickets the branch maps to (`rev-644-...` → REV-644) and their status.
- **What's done vs open** — per work-item, one line each, with evidence (which PR/commit/test).
- **Decisions + rationale** — the judgment calls made in-chat and *why* (this is the load-bearing
  part a fresh session can't reconstruct).
- **Landmines / gotchas** — anything surprising discovered (stale base, flaky infra, a convention).
- **Ordered next steps** — the exact sequence to continue.

If `/ansh-save` already wrote a local save this session, read it and reuse its content — this skill is
that content, relocated to Linear.

## Step 2 — Resolve a PRIVATE destination (once, then reuse)

**Privacy model — read this first, it is the whole point.** Linear has **no** private-by-default
"personal" area. **"My Issues" is only a filter/view — assigning an issue to yourself does NOT make
it private.** Any issue in a **shared team** (Engineering, a Pod, Operations, etc.) is visible to
every member of that team, and a **project or label confers no privacy whatsoever**. The ONLY way to
keep a handoff private is to put it in a **private team** (members-only visibility). A private team
you belong to is still fully readable by your *own* Claude Web / phone Linear auth, so it satisfies
both privacy and the cross-device purpose. A handoff carries internal decisions/rationale — treat a
shared-team placement as a leak unless the user explicitly opts in.

- **Team = the privacy boundary.** The handoff MUST live in a **private team** whose only member is
  the user (e.g. `<Name> Handoffs` / `<Name> Personal`). Resolve it via `list_teams` and prior
  handoffs. **The Linear MCP here cannot create teams** — if no private team exists, **STOP and ask
  the user to create one** in the Linear UI (Settings → Teams → New team → visibility **Private**,
  membership just them), then reuse it every time. **Do NOT fall back to a shared team** without the
  user's explicit, informed consent that their teammates will be able to read the handoff.
- **Assignee** — `me` (organizational convenience only — this is NOT a privacy mechanism; see above).
- **Label** — ensure a `web-handoff` label exists **on that private team** (`list_issue_labels`;
  create if missing). Note: **workspace-wide labels require admin**, so create it as a *team* label
  (pass the private team's `teamId` to `create_issue_label`). This is the discovery key `/web-read` uses.
- **Project** — optional, *inside the private team*, for tidiness only. A project does **not** affect
  visibility, so never rely on it for privacy. Skip unless the user asks.
- **Do NOT** set `parentId`, `relatedTo`, `blockedBy`, or link it to any feature epic. It is a
  free-standing private note.

## Step 3 — Write (or update) the handoff ticket

**Dedupe first:** `list_issues` filtered by `label: web-handoff`, `assignee: me`, ordered by
`updatedAt`; if one already exists **for this repo+branch** (match the title/marker), UPDATE it
rather than creating a duplicate. Otherwise create a new one.

- **Title:** `[web-handoff] <repo>@<branch> — <short goal>` (e.g.
  `[web-handoff] web-app@rev-746-sec-c — UKG skill ingestion stack`).
- **Body:** Markdown, both human- and machine-readable. Start with a fenced context block so
  `/web-read` can parse it deterministically, then the prose handoff:

  ```
  <!-- web-handoff:v1 -->
  repo: vitalizecare/web-app
  branch: <branch>
  head: <sha>
  base: dev
  prs: [#11876, #11877, ...]
  updated: <ISO date — stamp it from `date -u`, do not invent>
  ```

  Then sections: **Goal / DoD**, **Repo & PR state** (branch, PR links + CI status), **Done**,
  **Open / in-flight**, **Decisions & rationale**, **Landmines**, **Next steps (ordered)**, and a
  final **Resume in Claude Web** line:
  > In Claude Code Web on `vitalizecare/web-app`, say: *"read Linear `<ISSUE-ID>` and continue"* — or run `/web-read`.

- Keep secrets/tokens out. Link PRs inline. Convert relative dates to absolute.

**Confirm before writing** (it's outward-facing): show the user the title + a short summary and the
target (team/project), then create/update on approval.

## Step 4 — Return the pointer

Print the **issue URL + identifier** and the exact copy-paste line for the web session. Remind the
user they still need Claude Code Web pointed at the same repo, and (if the web sandbox lacks the
Linear connector) that they can paste the ticket body directly.

## Notes

- **Linear auth:** needs the Linear MCP connected (the claude.ai Linear connector locally). If it
  isn't, tell the user to connect it (`/mcp`) — don't fabricate an issue id.
- **One live handoff per branch:** update-in-place keeps a single source of truth; stale handoffs
  should be closed (see `/web-read`, which offers to mark it done on resume).
- Not a replacement for `/ansh-save` on the same machine, and not durable cross-session *facts*
  (that's memory) — this is a point-in-time, cloud-reachable work handoff.
