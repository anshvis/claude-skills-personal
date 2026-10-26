# Feature map template

One file per user-facing feature at `~/.agentic-workflow/<repo-slug>/feature-map/<feature>.md`.
Write it from the user's point of view. Discover internals at run time instead of freezing them here.

## README.md (index)

```markdown
# Feature map: <repo-slug>
Stack recipes: [_stack.md](_stack.md)

| Feature | File | Surface | Last verified |
|---|---|---|---|
| <name> | [<feature>.md](<feature>.md) | ui / data-visible / full-stack | <sha> |
```

## _stack.md

```markdown
# Local stack

## Launch
<commands from an empty data dir to a usable app: deps, DB, migrations, seed, dev server>
Ready when: <a page or log line that means usable, not just a port answering>

## Doctor (read-only)
- `bash ~/agentic-workflow/skills/ui-evidence/scripts/doctor.sh`
- <app title, DB ready, seed marker row, running build SHA, API port>

## Cleanup
- Stop by PID: <how PIDs are recorded at launch>
- Scratch state to remove: <dirs, branch DBs>
- Evidence stays at `~/.agentic-workflow/<repo-slug>/evidence/`.
```

## <feature>.md

```markdown
# <Feature name>

<one line: what the user gets from it>
Surface: ui | backend | data-visible | full-stack (see verification.md#surface)
Last verified: <sha> (<date>)

## User path
- Click path: <screen> -> <tab or panel> -> <control>
- Route: </path>
- Shortcut: <key or none>

## How to drive it
- Harness: ui-evidence | verify-web | verify-ios | CLI | curl
- <step> should <visible result>
- Reset: <how to get back to a known state>

## Stable selectors
- `role:<role>|<accessible name>`
- `<data-testid>`
- ARIA: <relationship, e.g. dialog labelled by heading>
Never generated classes, hashes, child indexes or DOM position.

## States
- Default, loading, empty, error
- Open, selected, disabled
- <feature-specific variants>
Mark the ones that don't apply.

## Preconditions
- Auth: <role and account>
- Fixtures: <seed rows the journey needs>
- Flags: <flag and value, or none>
- Services: <API, worker, queue that must be up>

## Evidence and cross-check
- Screenshot: <state that proves it>
- Cross-check (read-only): <SQL, API call or log line that confirms what the screen shows>

## Gotchas
- <dead ends, wrong look-alike surfaces, timing, seed gaps>
```
