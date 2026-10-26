# Tickets and branches

How branches are named, how PRs link tickets, and who moves a Linear ticket. `/ansh-plan` writes
these into `plan.json`; `/ansh-task` and `/ansh-ship` act on them.

## Branch names

- Name a branch off its PR's primary ticket: its `Closes` ticket, else its main `Part of`.
- Shape: `<tag-lower>-<slug>`. The ticket tag lowercased, plus 3-6 specific kebab-case words from
  the title. Strip filler ("fix", "the", "issue with"). Lowercase ASCII and hyphens only.
  Examples: `rev-669-availability-request-integration`, `rev-75-add-tag-to-edit-shift-sidebar`.
- Use the parent's tag only for the parent's own work (its integration branch, or a parent with no
  children). A parent-named section branch stacks every section onto the parent in Linear.
- Never invent a non-ticket name when a ticket exists. A ticketless prose goal uses `ansh-<slug>`.
- Never push to `main` or `master`. Work only on the branches the plan names.

## PR link words

Each PR links every ticket its own diff advances, one line each:

- `Closes <ID>` for a ticket this PR finishes (its last or only PR).
- `Part of <ID>` for a ticket it advances.
- `Depends on #<n>` for each PR it stacks on. Never link the tickets of dependency branches merged
  under it.
- The parent is plain text on section PRs ("parent REV-1157"). Link it only on its own work: a
  ticket with no children, or the umbrella PR (`Closes <PARENT>`).
- Every child ticket appears in at least one PR's links and in exactly one `Closes`.
- Never invent ticket numbers. A ticketless goal has no link lines.

## Linear status

- `/ansh-plan` and `/ansh-task` move a ticket they own (never the parent) from triage, backlog or
  unstarted to In Progress: find `statusType="started"` with `list_issue_statuses`, then
  `save_issue`. A ticket already started or later stays as it is.
- The GitHub integration owns In Review and Done. Never set those by hand.
- A Linear failure is a note, not a stop.
