# Stacking and staying current

Shared by `/ansh-task`, `/ansh-small-loop`, `/ansh-loop` and `/ansh-pr-loop`. One copy, so the
rules don't drift between skills.

Most broken stacks come from three mistakes: a branch cut from a stale local ref, a PR whose base
is not the branch it was built on, and a rebase or force-push under a PR that others build on.

## The base of a branch

Every section branch has exactly one base, recorded in `plan.json.prs[].base`:

- **Its dependency's branch**, while that dependency PR is still open. The PR targets that branch
  and says `Depends on #<n>`.
- **The integration branch**, once every dependency has merged into it (or when there is none).
- **`main`**, only for the umbrella PR or a single-PR goal.

Never build on a branch that the plan does not name as the base, and never build on `main` when
the plan says the work is stacked.

## Before starting work (in `/ansh-task`, every time)

1. `git fetch origin`.
2. Work out the base from the rule above. Check whether each dependency PR has merged:
   `gh pr view <n> --json state,mergedAt,baseRefName`.
3. New branch: cut it from the remote tip, `git switch -c <branch> origin/<base>`. Never from a
   local branch that may be behind.
4. Existing branch: if `origin/<base>` has commits the branch lacks
   (`git rev-list --count HEAD..origin/<base>` > 0), merge them in with
   `git merge origin/<base>` before you edit anything.
5. Check that the dependency's code is actually present (the files or symbols the packet relies
   on). If it isn't, the base is wrong: stop and report `BLOCKED`, don't recreate it.

## Before pushing or opening a PR

1. `git fetch origin` and merge `origin/<base>` in again. Resolve conflicts, then re-run the
   packet's verification. A merge that went in after verification means verification has to run
   again.
2. Check the PR holds only its own work:
   - `git log --oneline origin/<base>..HEAD` lists only this section's commits (plus merges).
   - `git diff --stat origin/<base>...HEAD` touches only this section's files.

   Anything else means the branch was cut from the wrong place. Fix the base before opening the PR.
3. Open the PR against that same base: `gh pr create --base <base>`. Add `Depends on #<n>` for each
   unmerged dependency.

## When a dependency merges

1. Retarget each PR stacked on it to the dependency's own base (usually the integration branch):
   `gh pr edit <n> --base <new-base>`. GitHub does this itself only when the merged branch is
   deleted.
2. Merge the new base into the stacked branch (`git merge origin/<new-base>`), re-run verification
   and push. If the dependency was squash-merged, this merge is what makes the PR's diff clean
   again.
3. Repeat up the stack, one level at a time, lowest first.

## Never rewrite a shared branch

Keep stacked, integration and already-pushed branches current by **merging**, never by rebasing,
squashing or force-pushing. Other sessions and the PRs above build on them. If a tool wants to
rebase (for example `/review-fresh`'s capture), review from a detached temporary worktree at the
branch head instead (`git diff origin/<base>...HEAD`). Never force-push a shared branch. It's on the
never-do list in [autonomy](autonomy.md).

## Merge order

A PR merges only after every PR it depends on has merged, and only when its base is current.
`/ansh-pr-loop` checks both before merging, and holds the PR (it does not merge it) while a
dependency is still open or parked.
