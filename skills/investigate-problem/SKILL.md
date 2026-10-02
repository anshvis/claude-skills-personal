---
name: investigate-problem
description: Systematic investigation for a PROBLEM that isn't a code bug — why a ticket stalled, what was actually decided and why, the history behind a constraint, an operational/org question. Pulls from every source that might hold the answer (Obsidian vault recall, Linear, Slack, GitHub PR discussion, the open web) rather than guessing from memory. Use when asked to figure out "why did X happen", "what did we decide about Y and why", or to investigate something that isn't a stack trace. For an actual code bug use investigate-code instead — this one is non-code.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - WebSearch
  - Skill
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_comments
---

# /investigate-problem — Root-cause investigation for non-code problems

## Iron law

**No conclusion without checking every source that could hold the answer first.** A confident
guess presented as fact is worse than "I don't know, here's where I looked" — the latter is
actionable, the former just relocates the confusion.

## Phase 1 — Frame the question

State, in one sentence, exactly what's being asked and what would count as a real answer:
- A **decision question** ("why did we choose X") wants: the decision, who made it, when, and
  the reasoning — not just the outcome.
- A **status question** ("why is this stalled") wants: the current blocker, since when, and who
  owns unblocking it.
- A **history question** ("what's the story behind this constraint") wants: the origin, and
  whether it's still true today or just inherited.

If the question is genuinely ambiguous, ask ONE clarifying question rather than investigating
the wrong thing thoroughly.

## Phase 2 — Gather from every relevant source

Don't stop at the first source that returns something — a decision made in a Slack thread and
never logged in Linear is exactly the kind of thing a single-source search misses. Pull from
whichever of these are actually relevant to the question (skip what clearly doesn't apply):

- **Obsidian vault** (`/obsidian`, recall mode) — the highest-leverage first stop. It already
  aggregates Slack/Linear/Granola meeting notes with topic/people wikilinks; a decision made in
  a meeting is often only findable here, not in Linear or Slack directly.
- **Linear** — the ticket itself, its full comment history, and linked/related issues
  (`mcp__linear-server__get_issue`, `list_comments`, `list_issues` for related tickets). Status
  changes and comment timestamps often show *when* something actually happened, not just that it
  did.
- **Slack** (direct, if the vault's cached copy is stale or the channel isn't tracked there) —
  search for the relevant channel/thread if you have Slack MCP access in this session.
- **GitHub PR discussion** — if the question traces to a code change, `gh pr view --json
  comments,reviews` or `gh api repos/{owner}/{repo}/pulls/<n>/comments` often has the actual
  reasoning a commit message doesn't.
- **The open web** (`WebSearch`) — only for questions with an external dimension (a vendor's
  behavior, a library's known issue, an industry norm). Sanitize anything you search — never
  leak internal names, tickets, or customer data into a public search query.

Treat every source as a *lead*, not ground truth — a Slack message asserting something
confidently is not proof; corroborate across sources when the answer matters.

## Phase 3 — Reconcile conflicts before concluding

If sources disagree (Linear says one thing, a Slack thread says another, the vault has a third
version) — do not silently pick one. Note the conflict, check timestamps (later usually
supersedes earlier, but not always — a reversal should say so explicitly), and if it's still
unresolved, surface the conflict directly rather than resolving it by assumption.

**3-strike rule:** if three searches/angles turn up nothing, STOP. Say plainly that the answer
doesn't appear to exist in any searched source, rather than fabricating a plausible-sounding
answer. Offer to search a source you didn't already check, or ask the human who was likely
involved.

## Phase 4 — Report

```
INVESTIGATION REPORT
════════════════════════════════════════
Question:        [what was actually being asked]
Answer:           [the decision / status / history, stated plainly]
Sources:          [note/ticket/thread/PR — cited, not "the vault said so"]
Confidence:       [high | medium | low, and why]
Conflicts:        [any sources that disagreed, and how you reconciled — or didn't]
Open threads:     [anything still genuinely unresolved]
Status:           DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

## Handoff — this skill investigates, it doesn't execute

If the investigation surfaces that actual code work is needed (a bug to fix, a feature to
build), stop here and hand off rather than drifting into implementation:
- A code bug → `investigate-code`.
- A scoped task or small ticket → `/ansh-task` directly, or `/ansh-loop` for the full cycle.
- A project-scale piece of work → `/ansh-plan` (or talk it through first, per `/ansh-loop`'s
  scope gate) — this skill's job ends at a clear, cited answer.

## Rules

- Never present a guess as a finding. "I couldn't find this" is a valid, useful answer.
- Cite the actual note/ticket/thread for every claim — not just the source category.
- Conflicting sources get surfaced, not silently resolved by picking whichever is more recent.
- Sanitize before any external web search — no internal names, tickets, or customer data.
