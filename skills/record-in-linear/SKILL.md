---
name: record-in-linear
description: Capture useful findings from the current chat and persist them as a Linear document. ALWAYS prompts the user for the destination project — if they name (or paste a URL/ID for) a Linear project, attach the document there and weave that project's existing context into the note so it stays relevant. Otherwise place it under the user's personal-notes project on Linear (find one named like "Personal Notes" / "<Ansh> Notes", or create one and reuse it next time). Invoke whenever the user says "record this", "save to linear", "/record-in-linear", or asks to document findings from this chat.
---

# record-in-linear

Persists chat findings as a Linear **document** (not an issue). Two rules make these documents useful months later: (1) the destination project is always the user's choice, and (2) when a project is given, the document references that project's stated goals/state so it doesn't read as an orphan note.

## Inputs

You bring the **findings** from chat context — do not ask the user to retype. Extract concrete, reusable artifacts:

- Working SQL/API queries with verified table/column names and parameters.
- Working request shapes (URL, headers, body) and the responses they produced.
- Identifiers learned (IDs, hostnames, badge numbers, table names) — anything you'd have wished you knew at the start of the session.
- Gotchas: wrong-turn paths that wasted time (column names that didn't exist, auth schemes that were wrong, filters that looked right but weren't).
- One-line summary of the original question this chat answered.

If the chat is too sprawling to extract from confidently, ask once: "Which threads should I capture?" Otherwise proceed.

## Step 1 — Ask for the destination project

Use `AskUserQuestion` exactly once. Phrase it as: "Which Linear project should this document attach to? (Or save to your personal notes.)" Offer:

- **A specific project** — user pastes a Linear project URL, ID, or names it (e.g., "UKG integration", "customer onboarding"). You'll resolve via Linear search.
- **Personal notes** — falls back to the user's personal-notes project (resolved or created in Step 2b).
- **Other** — free-text destination the user describes.

If the user already named a project in the chat ("save this under the UKG integration project"), still confirm the resolved project with them once before writing — Linear projects often have similar names.

## Step 2 — Resolve the destination

### 2a. Named project path

1. Call `mcp__claude_ai_Linear__list_projects` (or `search`-style equivalent) with the user's project name/keyword. If they gave a URL or ID, use `mcp__claude_ai_Linear__get_project` directly.
2. If multiple projects match, present the candidates back to the user with `AskUserQuestion` (show name + team + status).
3. Once you have the project, **fetch its details**: name, summary/description, current state, target date, lead, and any open milestones. This is the project context you'll weave into the document.
4. Optionally fetch a few recent `list_issues` results filtered to that project to surface what's actively happening — pick 3–5 most recent, name + status only. Skip if it adds nothing.

### 2b. Personal notes path

1. Identify the current user via `mcp__claude_ai_Linear__get_user` (or `list_users` filtered to "me"/current).
2. Search `list_projects` for an existing project the user uses as a notes bucket. Heuristics:
   - Name matches `personal notes`, `<first-name> notes`, `<first-name>'s notes`, `scratch`, `engineering notes` (case-insensitive).
   - Lead is the current user AND no other members (a private-feel project).
3. If exactly one match, use it. If multiple, ask the user which one. If none, **create one** via `mcp__claude_ai_Linear__save_project`:
   - Name: `<First name>'s Notes` (e.g., `Ansh's Notes`).
   - Description: `Personal scratch space for findings, debug notes, and reusable artifacts captured from coding sessions.`
   - Lead: current user.
   - Team: pick the user's primary team (smallest set of teams they belong to, or ask if ambiguous).
4. Remember the project ID — future invocations should reuse it without re-creating.

## Step 3 — Format the document body

Linear documents are markdown. Send real newlines, not literal `\n`. Use this skeleton:

```markdown
# <Punchy title — what was learned, not "Chat with Claude on X">

**Date:** YYYY-MM-DD  ·  **Captured from:** Claude Code chat
**Project:** <Linear project name>  ·  **Link:** <linear project URL>

## Context
<2–4 sentences describing the project this note attaches to: what it IS, what stage it's in, who owns it. Pulled from the Linear project description/state. For personal-notes destinations, replace with a one-line "Personal note — no parent project context.">

## Question this answered
<one-line problem statement from the chat>

## Findings
- <Concrete fact 1 — specific table.column, endpoint, ID format, etc.>
- <Concrete fact 2>
- ...

## Working artifacts
<Copy the SQL queries, request bodies, response snippets verbatim in code fences. These are the things future-you will copy-paste.>

## Gotchas / wrong turns
- <What looked right but wasn't, and why>

## Related
- <Linear project link — required for project-attached docs>
- <Linked issues if any were referenced in the chat>
```

**Hard formatting rules:**
- No emojis anywhere.
- No mention that an AI wrote the document (no "Generated with…", no "Claude", no co-author trailers).
- Real newlines in Linear strings (per the Linear MCP convention) — never literal `\n`.
- Code fences for queries/payloads. Inline backticks for identifiers (table names, column names, IDs).

## Step 4 — Create the document

Use `mcp__claude_ai_Linear__save_document` with:

- `title`: the document title from Step 3.
- `content`: the full markdown body.
- `projectId`: the resolved project ID from Step 2.

After creation, print a single-line confirmation: `Saved → <document URL>  ·  Project: <project name>`.

## Anti-patterns — don't

- **Don't** create the document as a Linear **issue**. It's a document, not a tracked work item.
- **Don't** skip the destination prompt — the whole point is the user picks where it lands.
- **Don't** invent project IDs. If search returns nothing for a name the user gave, ask before falling back.
- **Don't** dump the full chat transcript. Extract artifacts, not narration.
- **Don't** create a duplicate personal-notes project — always search first and reuse.
- **Don't** include LLM-author trailers, emojis, or "as discussed" pleasantries.
- **Don't** create more than one document per invocation unless the user asks.

## End-of-skill

Single-line confirmation, nothing more.
