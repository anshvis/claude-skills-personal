---
name: obsidian
description: Recall context from Ansh's "second brain" Obsidian vault at ~/vitalize (Slack, Linear, Granola meeting notes, People, Topics, Repo — kept fresh by the separate weekday vitalize-brain-sync scheduled agent). Use when a task would benefit from prior decisions, meeting outcomes, Slack context, or people/topic history that lives in the vault instead of the codebase or Linear alone — most usefully at the START of planning (/ansh-plan Phase 1), but any skill can pull from it. Read-only: this skill queries the vault, it does not write to it (aggregation is the scheduled agent's job).
allowed-tools:
  - Read
  - Grep
  - Glob
---

# /obsidian — Vault recall

The vault at `/Users/anshviswanathan/vitalize` is where Slack, Linear, and Granola meeting
notes accumulate automatically (the `vitalize-brain-sync` weekday scheduled agent). That
aggregation has been running for a while and is genuinely rich — the gap this skill closes is
that nothing was actually **querying** it. This skill is the read side: given a topic, person,
ticket, or repo area, pull the relevant notes and hand back condensed, cited context.

**This skill does not sync or write.** If the vault looks stale (no notes for a topic you know
happened this week), say so and note that the weekday sync will catch it up — don't try to
re-implement the aggregation inline here.

## Vault shape (so you search it correctly)

```
/Users/anshviswanathan/vitalize/
  Granola/   <date> <title>.md      — meeting summaries: decisions, action items, attendees
  Linear/    <IDENTIFIER> <title>.md — ticket snapshots
  Slack/     <channel>.md            — running per-channel notes, dated "### Update" sections
  People/    <name>.md                — stub notes for recurring people
  Topics/    <topic>.md               — topic hub notes
  00-Home.md, Welcome.md
```

Every note has YAML frontmatter: `source` (slack|linear|granola|repo), `type`, `date` (ISO), `tags`,
and `people`/`attendees` where relevant. Bodies use `[[wikilinks]]` for people/topics and `#tags`.

**Canonical topics and people**: the vault's own tag list and people notes. List them first
(`grep -rhoE '#topic/[a-z0-9-]+' <vault> | sort | uniq -c`, and the `People/` folder) and search
those. Don't invent a new topic unless a note clearly needs one.

## How to recall

Given a query (a Linear ticket ID, a topic, a person, a repo/subsystem name, or free text):

1. **Resolve to a canonical topic/person if one clearly applies** (e.g. "availability request
   work" → `[[Availability Requests]]`). If nothing canonical fits, search the raw term anyway —
   don't force a bad match.
2. **Search, cheapest first:**
   - If a Linear ticket ID is known, check `Linear/<IDENTIFIER>*.md` directly.
   - `Grep` for the topic/person wikilink or `#tag` across the vault (`rg -l '\[\[Availability Requests\]\]' /Users/anshviswanathan/vitalize`), then narrow by folder if the hit count is large.
   - For "what happened recently on X", sort matches by the frontmatter `date` and read the
     newest few fully rather than skimming everything.
3. **Read the matched notes** (Read tool) — don't rely on Grep snippets alone for anything you're
   about to fold into a plan; a one-line match can miss the actual decision two paragraphs later.
4. **Synthesize, don't dump.** Return: what was decided (with the note it came from, e.g.
   `Granola/2026-08-14 customer sync.md`), open questions that were left open, and who owns what.
   Cite `file:section` or the note's date, not just "the vault said so" — the calling skill (or
   Ansh) needs to be able to go verify.
5. **If nothing relevant turns up**, say so plainly — an empty result is real information (this
   hasn't been discussed/decided yet), not a failure to search harder.

## Where this plugs into the `/ansh-` arsenal

- **`/ansh-plan` Phase 1 (primary use)** — after pulling the Linear ticket and reading the code,
  recall the vault for the ticket's topic(s)/people before writing `plan.md`. Prior decisions,
  a Slack thread that already ruled out an approach, or a meeting note with the actual reasoning
  behind a constraint are exactly the kind of context that changes a decomposition and is
  otherwise invisible to a fresh planning pass. Best-effort: if the vault is unavailable, note it
  and continue — never block planning on it.
- Any other `/ansh-` skill may pull from it ad hoc (e.g. `/ansh-debug` checking whether a bug was
  already discussed in Slack), but planning is where the leverage is highest — decisions made
  once shouldn't need re-discovering from scratch every time.

## Completion status

**DONE** (returned synthesized, cited context — or a clear "nothing found"), **BLOCKED** (vault
path inaccessible — say so, don't guess from memory).
