# Worktrees

Every `/ansh` skill that edits code or moves a branch works under these rules.

## One worktree per work item

- A work item is a ticket, a project's integration branch, or one PR. It gets exactly one worktree.
- Put it beside `web-app` as a sibling, never nested inside a repo. Run `bun install` in it.
- Create it if none exists. Reuse it for every plan, task, debug, resolve and PR-loop pass of that
  item. Don't cut a new one per invocation: `.ansh/` is git-excluded and won't be in a fresh one.
- Work on a PR in the worktree that tracks its branch. Never fix or resolve a PR from another
  branch's worktree.
- A different ticket or project gets its own worktree, and a fresh session when you can.
- A read-only lookup in another checkout is fine. Edits and branch work there are not.
- Short-lived read-only checkouts are fine and get removed after: a detached review worktree at a
  head SHA ([stacking](stacking.md)), or the base worktree for a red-first run.

## Never leave verified work uncommitted

Commit a candidate before you verify it, so the SHA you verify is real. Any change after that is a
new commit and a new verification. Commits follow `chill-describe`: one logical change each (a
migration, a concept, a resolver, its tests) so any one can be reverted. Verified work that sits
uncommitted turns a worktree cleanup into data loss.
