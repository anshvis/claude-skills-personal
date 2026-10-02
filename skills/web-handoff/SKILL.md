---
name: web-handoff
description: HANDOFF the current terminal session to another device (Claude Code Web / your phone) by writing a self-contained handoff `.md` into the repo. Snapshots the working context — goal, git branch/commits/PRs/CI, what's done vs open, decisions + their rationale, landmines, and the ordered next steps — into a tracked markdown file so a session pointed at the same GitHub repo can pick it up and keep solving. This is the cross-device mirror of /ansh-save (which writes to git-excluded `.ansh/`). Use when the user says "/web-handoff", "hand this off to web", "continue this on web/my phone", or wants to move work off the laptop. Pair with /web-read to pull it back into a terminal.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# /web-handoff — Terminal → Web handoff via a repo `.md`

`/ansh-save` captures a handoff to `.ansh/saves/` — perfect for the *same machine*, useless for the
cloud: `.ansh/` is git-excluded (local `.git/info/exclude`), so it never reaches a Claude Code Web
sandbox (which boots from your GitHub repo) or your phone. This skill writes the same handoff to a
**tracked `.md` file in the repo**, the one channel the laptop, the web sandbox, and your phone all
reach once it's on GitHub.

The point is the same as `/ansh-save`: capture the **reasoning that lives only in the chat** — why a
decision went the way it did, what was ruled out, the landmine you hit — plus the concrete repo/PR
state, so a fresh session on another device resumes with zero re-derivation.

## Why a repo `.md` (and NOT Linear / external cloud) — READ FIRST

- **No Linear, ever.** This workspace has **no private Linear team and cannot create one**, and a
  handoff carries internal decisions/architecture that must not land in a shared team (that's a leak).
  Do not attempt a Linear ticket for the handoff.
- **No external cloud** (Google Drive, Notion, etc.). The security classifier hard-blocks uploading
  private-repo content there as exfiltration; sanitizing does not clear it. Don't try.
- **The repo itself is the in-boundary channel.** A private GitHub repo is readable by your own Claude
  Code Web / phone session. A tracked `.md` on the branch is the reliable, privacy-preserving way to
  move the handoff across devices.

## What this skill does and does NOT do

- **DOES:** write a self-contained handoff `.md` into the repo working tree.
- **DOES NOT:** commit, and **DOES NOT push**. Leave the file uncommitted. Getting it onto mobile is
  the user's call — they commit + push it themselves when ready (or a later `/ship`/commit sweeps it
  up). Never run `git commit`/`git push` from this skill.

## Step 1 — Gather the context (don't skip the "why")

Collect, in this order:
- **Goal** — the ticket/prose driving the work, and the definition of done.
- **Repo state** — `git rev-parse --abbrev-ref HEAD` (branch), `git rev-parse HEAD` (sha),
  `git log --oneline -15`, `git status --short`. Note the base branch (usually `dev`).
- **PRs / CI** — `gh pr list --head <branch>` and for each open PR `gh pr view <n> --json
  number,title,url,state,baseRefName,statusCheckRollup` (state + check summary). Capture stacked-PR
  bases if relevant.
- **Linear** — any tickets the branch maps to (`rev-644-...` → REV-644) and their status (for
  *reference in the doc* — not as a destination).
- **What's done vs open** — per work-item, one line each, with evidence (which PR/commit/test).
- **Decisions + rationale** — the judgment calls made in-chat and *why* (this is the load-bearing
  part a fresh session can't reconstruct). If an earlier decision was reversed, say so explicitly.
- **Landmines / gotchas** — anything surprising discovered (stale base, flaky infra, a convention).
- **Ordered next steps** — the exact sequence to continue.

If `/ansh-save` already wrote a local save this session, read it and reuse its content — this skill is
that content, placed in a tracked repo file instead of git-excluded `.ansh/`.

## Step 2 — Write the handoff `.md`

- **Path:** `handoffs/<branch>.md` at the repo root (create `handoffs/` if missing). A tracked path so
  the user can push it and have Claude Code Web read it off GitHub. Keep one file per branch — if it
  already exists for this branch, UPDATE it in place (single source of truth) rather than duplicating.
- **Content:** Markdown, both human- and machine-readable. Start with a fenced/comment context block
  so `/web-read` can parse it deterministically, then the prose handoff:

  ```
  <!-- web-handoff:v1 -->
  repo: vitalizecare/web-app
  branch: <branch>
  head: <sha>
  base: dev
  prs: [#11876, #11877, ...]
  updated: <ISO date — stamp it from `date -u`, do not invent>
  ```

  Then sections: a top **Resume** line (how to re-enter on the other device), **Goal / DoD**,
  **Repo & PR state** (branch, PR links + CI status), **Done**, **Open / in-flight**, **Decisions &
  rationale**, **Landmines**, **Next steps (ordered)**, and any **Open questions for the user**.

  The **Resume** line should read:
  > **Resume on mobile / Claude Code Web** (repo `<repo>`, branch `<branch>`): say *"read
  > `handoffs/<branch>.md` and continue"*.

- Keep secrets/tokens out. Link PRs inline. Convert relative dates to absolute.

## Step 3 — Return the pointer

Print the **file path** and remind the user:
- The file is **written but not committed/pushed** — to reach mobile/web they commit + push it (or let
  their normal flow do it), then open Claude Code Web on the same repo/branch.
- The exact re-entry line: *"read `handoffs/<branch>.md` and continue"* — or run `/web-read`.

## Notes

- **No network side effects.** This skill only writes a local file. No Linear, no external upload, no
  git commit/push. If the user wants it committed, they say so (or use a commit skill).
- **One live handoff per branch:** update-in-place at `handoffs/<branch>.md` keeps a single source of
  truth; delete stale ones when the work lands.
- Not a replacement for `/ansh-save` on the same machine, and not durable cross-session *facts* (that's
  memory) — this is a point-in-time, repo-portable work handoff.
