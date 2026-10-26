# PR comment templates

Post these on Ansh's own PRs only. PR's own voice: no AI attribution, no emoji. Each template has
a marker so the loop edits its own comment instead of posting a new one. Post with
`--body-file` ([GitHub recipes](../../ansh-resolve/references/github.md)).

## Waiting on a dependency

```markdown
<!-- ansh-pr-loop:waiting-on -->
Waiting on #<parent> (<open | parked | awaiting approval>). This PR merges automatically once
#<parent> merges and CI passes on the merged-up head.
```

When the parent merges, edit it to `#<parent> merged. Retargeted to <base>.`

## Parked

```markdown
<!-- ansh-pr-loop:parked -->
**Parked, not merging.** <what merging would do that can't be undone, e.g. the migration drops
`shift_notes.legacy_body` on deploy>.

Verified at `<short sha>`: <evidence comment link>. To land it: <exact command or click>.
```

## Bot review dismissed

```markdown
<!-- ansh-pr-loop:dismissed <bot login> -->
Dismissed <bot>'s review from `<short sha>`. Every finding was addressed in <shas> (replies on each
thread), and the bot hasn't re-reviewed after two iterations. If it re-flags anything on its next
pass, the loop picks it up again.
```

## Awaiting approval

```markdown
<!-- ansh-pr-loop:awaiting-approval -->
Ready to merge at `<short sha>`: CI green, verification passed (<evidence link>), review gate clear.
Branch protection needs an approval from <@codeowner or team>. Requested.
```

For an `/ansh-correct` PR, replace the last line with `Hardening PR: requesting @anshvis's review.
The loop never merges these.`

## Deep lane

```markdown
<!-- ansh-pr-loop:deep-lane -->
**Deep lane** (blast radius high: <why>) at `<short sha>`.
- Fresh-context review: <clean | n findings, fixed in <shas>> (<provider/model>)
- Independent re-verification: <pass, checks AC-1..AC-n> (<evidence link>)
```
