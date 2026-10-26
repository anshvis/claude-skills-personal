---
name: ansh-control
description: "Drive the app's UI the way a user does, a web app, IDE or Electron app through Playwright or a Chromium debug port (CDP), capturing before and after evidence. Use to reproduce a UI bug, explore a screen, or run the ui half of a verification check."
---

# /ansh-control

**Goal:** drive the app's UI and bring back proof of what happened.

**Uses:** [verification](../_shared/verification.md), [autonomy](../_shared/autonomy.md), [memory](../_shared/memory.md),
[principles](../_shared/principles.md), [ledger](../_shared/ledger.md),
[harness recipes](references/harness.md), the local feature map and `_stack.md` from
[/ansh-verify](../ansh-verify/SKILL.md), [/ansh-backend](../ansh-backend/SKILL.md), and
`ui-evidence` for scripted, SHA-pinned runs.

This is the UI driving layer. `/ansh-verify` calls it for the `ui` half of a check
([surface](../_shared/verification.md#surface)): alone for `ui`, as one read-only look after
`/ansh-backend` for `data-visible`, and together with `/ansh-backend` for `full-stack`, where this
skill performs the action and `/ansh-backend` asserts its side effects at the same SHA.
`/ansh-debug` uses it to reproduce a UI bug, `/ansh-review` to drive a changed screen once. For a
repeatable journey tied to a commit, write a `ui-evidence` script instead.

## Steps

1. **Find the target.** Read the feature's map file and `_stack.md`. No map yet: read the repo's
   routes and existing Playwright or e2e specs. Reuse the repo's own harness first.
2. **Doctor.** Run the `_stack.md` doctor. Launch only if it fails and the stack is yours to start,
   then doctor again. Record the running build's SHA.
3. **Open a session.** Playwright against the local URL, or `connectOverCDP` for Electron or a
   Chromium debug port. Pick the page by a stable app marker, never by tab order. Recipes in
   [harness](references/harness.md).
4. **Drive one action at a time.**
   1. Capture state first: accessibility snapshot or screenshot.
   2. Pick the target from that fresh capture. Roles, labels and test ids only.
   3. Do exactly one action: click, type, key, scroll, resize or navigate.
   4. Wait for a concrete signal (an element, text, URL), not a sleep.
   5. Capture again and check the expected change happened.
5. **Cross-check the data.** Read the value behind the screen read-only through `/ansh-backend`
   (DB row or API response) so the proof isn't only pixels. In `full-stack` runs, hand it the
   action's time window so it asserts the same action's side effects.
6. **Capture extras when asked or when debugging:** console and network logs, failed requests,
   CPU profile or trace, heap snapshots.
7. **Save evidence** under `~/.agentic-workflow/<repo-slug>/evidence/<branch>/<sha>/control/`
   with a short `steps.md`: each action, the signal waited for, the result.
8. **Clean up what you started.** Close the browser and stop servers you launched. Evidence stays.
9. **Teach the map.** A selector, precondition or gotcha you learned goes into the feature's map
   file. A way to drive the app that works beyond this feature (login, seeding, a navigation
   trick) goes to project memory as an approved `workflow` per [memory](../_shared/memory.md). Log `ansh-log ansh-control drive <PASS|FAIL|BLOCKED> --surface <s> --note "<feature>"`.

## Edge cases

| case | do |
|---|---|
| Doctor fails on an instance you didn't start | Don't drive it, don't kill it. Launch on a free port, else BLOCKED. |
| Target is dev, staging or prod | Refuse. Local stack only. A PR preview only read-only through the `ui-evidence` host guard. |
| Several pages on one debug port | Select by a positive app marker. None match: list titles and URLs, don't guess. |
| Element missing or ambiguous | Fresh snapshot, then a role, label or test id. Never a generated class, DOM position or coordinate without a fresh screenshot. |
| Stale element after navigation | Re-query from a new snapshot. Never reuse old references. |
| Action needs real credentials or a destructive command | Don't send it. Use seeded local accounts. Park it per autonomy if nothing else works. |
| A step needs a write to shared or prod data | Park it per autonomy. |
| App hangs | Capture the screen, console and a CPU sample before interrupting. |
| Playwright isn't in the repo | Use the host's browser tools or `ui-evidence`. Don't add a dependency just for a probe. |
| Screen shows private customer data | Capture only what the check needs. Never post it outside the evidence dir. |
| The check is a CLI, API, job or DB state with no screen | Not this skill. Use `/ansh-backend`. |
| Behavior is wrong | Report it with the before and after captures. Don't change code here. |

## Output

`PASS` (the expected change happened, with captures), `FAIL` (it didn't, with captures and the
first wrong state), or `BLOCKED` (couldn't drive: name the missing piece). Include the SHA driven,
each action with its result, and the evidence path.
