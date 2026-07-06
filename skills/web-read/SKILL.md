---
name: web-read
description: RESUME work handed off from another device by reading it back from Linear into the current terminal (or web) session. The read half of /web-handoff — finds the most recent personal `web-handoff` Linear ticket (assigned to you, matched to the current repo/branch when possible), pulls its context, reconciles it against the live git/PR/Linear state, and orients the session to continue the ordered next steps. Use when the user says "/web-read", "pull my web handoff", "resume what I did on web/my phone", or opens a laptop session to continue cloud work. Inverse of /web-handoff.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - mcp__claude_ai_Linear__list_issues
  - mcp__claude_ai_Linear__get_issue
  - mcp__claude_ai_Linear__list_comments
  - mcp__claude_ai_Linear__save_issue
---

# /web-read — Read a Linear handoff back into the session

Pulls the handoff `/web-handoff` parked in Linear and picks the work back up. Works in either
direction — laptop resuming what web did, or web resuming what the laptop did — as long as both point
at the same GitHub repo.

## Step 1 — Identify where you are

- `git rev-parse --show-toplevel` (repo) and `git rev-parse --abbrev-ref HEAD` (branch), `git remote
  get-url origin` (to match `owner/repo`). This is what you'll match the handoff against.

## Step 2 — Find the handoff ticket

`list_issues` filtered by `label: web-handoff`, `assignee: me`, `orderBy: updatedAt`.
- Prefer the ticket whose `<!-- web-handoff:v1 -->` block (or title) matches the **current repo +
  branch**. Read the body with `get_issue` (also `list_comments` in case updates were appended).
- If several match, or none matches the current branch, list the candidates (title + updated date +
  branch) and ask which to resume — don't guess.
- If none exist, say so and stop (nothing to resume).

## Step 3 — Reconcile against reality (don't trust the snapshot blindly)

The handoff is a point-in-time note; the world may have moved. Before acting, verify:
- `git fetch origin`; compare the handoff's `head:` sha and `branch:` to what exists now. If the
  branch advanced, was force-pushed, or is gone, say so.
- Check out the branch (`git checkout <branch>` / create-tracking if needed) — only if the working
  tree is clean; otherwise surface the dirty state first.
- `gh pr view` each listed PR for current state + CI (the handoff's CI status may be stale).
- If Linear tickets are referenced, check their current status too.
- Flag every divergence between the handoff and now — a file/PR/flag it names may have changed. This
  mirrors the rule for recalled context: verify names/state still exist before relying on them.

## Step 4 — Orient and continue

- Summarize for the user: the goal, where things actually stand now (reconciled), the decisions +
  landmines from the handoff, and the **ordered next steps**.
- With confirmation, proceed on the next step (or hand to `/ansh-loop` / the relevant skill if the
  handoff points at one).

## Step 5 — Close the loop on the handoff

Once resumed (or when the work moves on), offer to **update or close** the handoff ticket so it isn't
re-read stale later: mark it Done if the handed-off work is finished, or have `/web-handoff` refresh
it in place if you're about to hand back off. Confirm before any outward-facing Linear write.

## Notes

- Needs the Linear MCP connected. If the web sandbox has no Linear connector, the user can paste the
  ticket body and you parse the same `web-handoff:v1` block from the message instead.
- Read-only by default except the optional Step-5 status update (gated on confirm).
- If the handoff references a local `.ansh/` save that isn't in the repo, note it won't be present on
  a different machine — the Linear body is the source of truth cross-device.
