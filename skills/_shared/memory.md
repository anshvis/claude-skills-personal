# Project memory

Lessons that should outlive a run go into Beacon's project memory: local to this machine, shared
by Claude and Codex, one memory per repo (every worktree of a repo reads the same one). The
[ledger](ledger.md) counts what happened. Memory says what to do differently next time.

Use `<skills-root>/_shared/ansh-memory` (resolve `<skills-root>` like `ansh-log`). It exits 0 and
skips with a note when Beacon isn't installed, so a missing Beacon never stops a run. `setup.sh`
installs it.

## Read

```bash
"<skills-root>/_shared/ansh-memory" context [--kind K] "<goal, symptom or diff summary>"
```

The MCP tool `get_memory_context` (server `aw-beacon`, `project` = the repo root) returns the same
thing. Memory is a lead, like a PR comment: check it against the current code before acting on it.

| Who | When | With | Then |
|---|---|---|---|
| `/ansh-plan` | step 1 and re-entry | the goal text, then each area it touches | Fold each memory that applies into the packet that owns it (Watch out for, Tests to write), citing its id. Specialists never read memory themselves; the packet carries it. |
| `/ansh-debug` | step 2 | the symptom and error | A matching `debugging_pattern` or `gotcha` is the first hypothesis. It still has to be confirmed. |
| `/ansh-review` | each verdict | the diff summary | A diff that repeats an approved `correction` or breaks a `convention` is REVISE, citing the memory id. |

## Write

```bash
"<skills-root>/_shared/ansh-memory" save --kind <kind> --title "<title>" --body "<lesson>" \
  [--applicability "<when it applies>"] [--approve --reason "<why it's proven>"]
```

| When | Who | Kind | Approve now |
|---|---|---|---|
| Root cause confirmed and the fix's regression check went red then green | `/ansh-debug` step 10 | `debugging_pattern`, or `gotcha` for an environment trap | yes: proven by the check |
| A human reviewer's comment was fixed | `/ansh-resolve` | `correction`, or `convention` for a taste rule | yes: a person said it |
| I corrected an agent default or something verification passed (`human-correction`, `escaped`) | the skill that logs it | `correction` | yes |
| The same REVISE class shows up a second time in one goal | `/ansh-cycle` | `correction` | no: `/ansh-retro` decides |
| A stack, seed, port or secrets-config trap found while verifying | `/ansh-verify`, `/ansh-backend` | `gotcha` | no |
| A pattern across runs in this repo | `/ansh-retro` | `workflow` or `convention` | yes |

A lesson is worth saving only if a future agent in this repo would act differently because of it.

- One lesson per memory. Imperative, at most 5 lines: what to do, when, and the file, command or
  check that shows it.
- `--applicability` names the trigger ("when a migration touches `shift_assignments`"), not "in
  this project".
- Search first (`context`). Same lesson already there: don't save a second copy.
- Never save: secrets or tokens, customer or patient data, people's names or handles, anything
  already enforced by a lint, type or CI check, anything already in `AGENTS.md` or a skill, or
  facts about this one run (those go in `.ansh/` and `/ansh-save`).
- Log it: `ansh-log <skill> memory DONE --class <class> --note "<memory or candidate id>"`.

## Review

`/ansh-retro` owns the queue (`ansh-memory pending`):

- **Approve** a candidate that is specific, still true at `origin/main`, and not covered by a
  check, `AGENTS.md` or a skill. Tighten the body on approval if it's vague.
- **Reject** one that is vague, one-off or already covered, with the reason.
- **Correct** an approved memory the code has moved past: save the fixed lesson, approve it, and
  list the old id as stale in the report.
- A class that `/ansh-correct` turned into a check no longer needs its memory: list it as stale.
