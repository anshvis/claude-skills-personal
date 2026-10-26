---
name: ansh-control
description: "Drive the real app the way a user does: a browser or Electron UI through Playwright or CDP, or a CLI or API through tmux, a PTY or curl, capturing before and after evidence. Use to reproduce a bug, explore a screen, or run one step of a verification check."
---

# /ansh-control

**Goal:** put the agent's hands on the running app and bring back proof of what happened.

**Uses:** [verification](../_shared/verification.md), [autonomy](../_shared/autonomy.md),
[principles](../_shared/principles.md), [ledger](../_shared/ledger.md),
[harness recipes](references/harness.md), the local feature map and `_stack.md` from
[/ansh-verify](../ansh-verify/SKILL.md), and `ui-evidence` for scripted, SHA-pinned runs.

This is the driving layer. `/ansh-verify` owns contracts and evidence packs, `/ansh-debug` uses this
to reproduce, `/ansh-review` uses it to rerun a visible check. For a repeatable journey tied to a
commit, write a `ui-evidence` script instead.

Modes: `ui` (web, IDE, Electron) and `cli` (CLI, TUI, HTTP API). Pick from the surface.

## Steps

1. **Find the target.** Read the feature's map file and `_stack.md`. No map yet: read the repo's
   routes, scripts and existing Playwright or e2e specs. Reuse the repo's own harness first.
2. **Doctor.** Run the `_stack.md` doctor. Launch only if it fails and the stack is yours to start,
   then doctor again. Record the running build's SHA.
3. **Open a session.**
   - `ui`: Playwright against the local URL, or `connectOverCDP` for Electron or a Chromium debug
     port. Pick the page by a stable app marker, never by tab order.
   - `cli`: a tmux session or a PTY probe with deterministic env vars. HTTP: `curl` with the auth the
     map names.
   Recipes in [harness](references/harness.md).
4. **Drive one action at a time.**
   1. Capture state first: accessibility snapshot or screenshot (`ui`), screen capture (`cli`).
   2. Pick the target from that fresh capture. Roles, labels, test ids and prompt strings only.
   3. Do exactly one action: click, type, key, scroll, resize, navigate, or one command.
   4. Wait for a concrete signal (an element, text, URL, prompt), not a sleep.
   5. Capture again and check the expected change happened.
5. **Cross-check the data.** Read the value behind the screen read-only (DB row, API response,
   file) so the proof isn't only pixels.
6. **Capture extras when asked or when debugging:** console and network logs, failed requests,
   CPU profile or trace, heap snapshots, terminal transcript, exit codes.
7. **Save evidence** under `~/.agentic-workflow/<repo-slug>/evidence/<branch>/<sha>/control/`
   with a short `steps.md`: each action, the signal waited for, the result.
8. **Clean up what you started.** Close the browser, kill the tmux session or PTY, stop servers you
   launched. Evidence stays.
9. **Teach the map.** A selector, precondition or gotcha you learned goes into the feature's map
   file. Log `ansh-log ansh-control drive <PASS|FAIL|BLOCKED> --surface <s> --note "<feature>"`.

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
| App hangs or the CLI stops responding | Capture the screen, logs and a stack or CPU sample before interrupting. |
| Playwright isn't in the repo | Use the host's browser tools or `ui-evidence`. Don't add a dependency just for a probe. |
| Screen shows private customer data | Capture only what the check needs. Never post it outside the evidence dir. |
| Behavior is wrong | Report it with the before and after captures. Don't change code here. |

## Output

`PASS` (the expected change happened, with captures), `FAIL` (it didn't, with captures and the
first wrong state), or `BLOCKED` (couldn't drive: name the missing piece). Include the SHA driven,
each action with its result, and the evidence path.
