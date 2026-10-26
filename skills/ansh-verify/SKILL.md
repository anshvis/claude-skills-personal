---
name: ansh-verify
description: Own the verification harness (feature map, local stack recipes, evidence packs) and run a task's verification contract on the real app; use /ansh-verify setup for a new repo, run for a packet or check file, maintain when the map may have drifted.
---

# /ansh-verify

**Goal:** prove a change works on the real app at a given SHA, with evidence another agent can rerun.

**Uses:** [verification](../_shared/verification.md), [autonomy](../_shared/autonomy.md),
[principles](../_shared/principles.md), [ledger](../_shared/ledger.md), [runtime](../_shared/runtime.md),
[feature map template](references/feature-map-template.md), [/ansh-control](../ansh-control/SKILL.md) (driving), `ui-evidence`, `verify-web`, `verify-ios`,
`/lightweight-sql`, and the toolkit's `verification-lenses.md` and `evidence-pack.md`
(`~/.agentic-workflow/toolkit/skills/_shared/`).

The contract shape, surface rules, evidence pack layout and what is not a pass live in
[verification](../_shared/verification.md). This skill executes them.

## Paths

- Repo slug: `owner-repo` from `origin`, the same way the toolkit's `repo-slug.sh` derives it.
- Feature map: `~/.agentic-workflow/<repo-slug>/feature-map/`. `README.md` is the index. One file per feature.
- Stack recipes: `feature-map/_stack.md` (launch, doctor, cleanup).
- Evidence: `~/.agentic-workflow/<repo-slug>/evidence/<branch>/<sha>/<task-id>/`, plus `<sha>/manifest.json`.

The map stays local. Never commit it to the product repo. Propose committing it (as a PR, Ansh as
reviewer) only when the ledger shows visible-class `escaped` events per merged visible milestone
dropping across two retros since the map was set up. `/ansh-retro` reports that number.

## Steps

### setup

1. Read the repo, not a person: routes, nav, commands, README quickstart, existing Playwright or
   XCUITest specs, `AGENTS.md`, `ui-evidence` `deployment.md` if present.
2. Write `_stack.md`:
   - **Launch:** exact commands from an empty data dir to a usable app (migrations, seed, auth). Ready means a real page loads, not that a port answers.
   - **Doctor:** read-only checks: process up, port owned by the process you started, app title matches (`UI_EVIDENCE_APP_TITLE`), DB ready, seed marker present, head SHA of the running build.
   - **Cleanup:** stop what you started by PID. Remove scratch data. Never touch the evidence dir.
3. Write one file per user-facing feature from the [template](references/feature-map-template.md).
   Start with the 3 to 5 features the open work touches. Add the rest as runs need them.
4. Write `README.md`: one line per feature (name, file, surface, last verified SHA).
5. Prove it: launch, doctor, drive one feature end to end with `/ansh-control` and `ui-evidence`, write its evidence,
   run cleanup, then confirm the evidence still exists. Fix and repeat until that holds. Run
   cleanup after every failed attempt too.
6. Log `ansh-log ansh-verify setup <PASS|BLOCKED>`.

### run `<task-id | plan | --checks file>`

1. Load the contract: `.ansh/tasks/<id>.md` `## Verification`, every packet listed in `plan.json` `subtasks[].packet`,
   or the given file. No contract: return BLOCKED. Don't invent one.
2. Pin the SHA. Normal mode: head of the task branch. `--red-first`: the base SHA, in a separate
   worktree. Record it before any check runs.
3. Doctor. Launch only if doctor fails and the stack is yours to start. Doctor again after launch.
4. Run each check by surface ([verification](../_shared/verification.md#by-surface)):
   - **visible:** read the feature's map file. Write a `ui-evidence` script from its selectors and
     the check (not from the diff), run it with `--app-build <sha>`. For lenses beyond functional,
     run `verify-web --yes --journey <plan>` (`verify-ios --yes` for iOS). Then the read-only data cross-check.
   - **data-visible:** the invisible checks, plus one read-only `ui-evidence` check with no write steps.
   - **CLI or API:** `/ansh-control cli`: the command or `curl`. Save the command, exit code, stdout and stderr.
   - **invisible:** the named tests, the DB check on a branch DB, perf (base and head, 3 runs
     each, limiter named), and the production signal firing locally.
5. Write the pack: copy each tool's output (`summary.json`, `pack.json`, screenshots) into the
   evidence dir, then `verdict.json` per [verification](../_shared/verification.md#evidence-pack), and
   update `<sha>/manifest.json` with every expected check from the PR's packets.
   A check passes only if it ran at the pinned SHA and its observable result matched.
6. `--red-first`: every check must fail for the stated reason. A check that passes on base is
   `weak`: report it so the author rewrites it. A check that fails for another reason is `broken`.
7. On Ansh's own PR, post the short evidence comment. No Linear upload, no `publishEvidence`.
8. Cleanup what you started. Confirm the evidence dir survived.
9. Log one event per check: `ansh-log ansh-verify run <PASS|REVISE> --task T --surface S --ids AC-n`.
10. Update the feature's `Last verified` SHA. Map drift found while driving: fix the map file now.

### maintain

1. Index hygiene: README entries match feature files. Fix missing, extra or dead entries.
2. Source wave: one read-only subagent per feature file, in parallel. Each returns: how the
   feature works from source (with `file:line`), likely drift, one live recipe. They never drive the app or edit.
3. Sweep recent merges for user-facing surfaces missing from the map. Need a concrete source path to add one.
4. Live pass: you drive, serially, on one doctored instance. Drive every feature at least once.
   Doctor again after any failed drive. A wedged UI on a healthy process: reset state or relaunch.
5. Triage each finding:
   - wrong or missing description: map drift. Fix the file.
   - working behavior the harness can't drive: harness gap. Fix the recipe, re-drive it live.
   - behavior that's broken: product regression. Report it with evidence. Don't edit the map to match it.
6. Final cleanup after the last re-drive. Log `ansh-log ansh-verify maintain <DONE|BLOCKED>`.

## Edge cases

| case | do |
|---|---|
| Port 3000 answers but doctor says it's foreign or unhealthy | Don't drive it. Don't kill it. Launch on a free port if the recipe allows, else BLOCKED. |
| Instance you didn't start is healthy | Drive it read-only only if doctor passes and its SHA is the pinned one. Never stop it. |
| Target is dev, staging or prod | Refuse. Local stack only. A PR preview only through the `ui-evidence` host guard, read-only. |
| Selector missing or ambiguous | Fix the map with a role, ARIA name or test id. Never a generated class or DOM position. |
| Precondition missing in seed data (auth, fixture, flag, service) | Check fails with the reason. Add it to the feature's preconditions. Never weaken the check. |
| Feature unreachable | `verified-unreachable` with the prerequisite and route tried. Missing from the map: drift. |
| Visual verdict `off`, `sloppy` or `unchecked` | REVISE. A cached or `unchanged` visual never stands in for the behavior check. |
| Running build SHA differs from the pinned SHA | Rebuild or relaunch. A check at another SHA is not a pass. |
| `verify-web`/`verify-ios` would ask a question | Pass `--yes`. A build or launch it can't resolve: BLOCKED with the error. |
| Check needs a write against shared or prod data | Park it per [autonomy](../_shared/autonomy.md). |
| Stack can't launch (missing tool, credential, service) | BLOCKED, naming the missing piece. |
| Cleanup would delete evidence | Fix the cleanup recipe first. Evidence survives every cleanup. |
| Called again on a check that failed before | Run it fresh at the new SHA. The caller owns the round cap ([autonomy](../_shared/autonomy.md#stop-conditions)). |

## Output

- `setup`: `PASS` with map path and the proven feature, or `BLOCKED` with what's missing.
- `run`: `PASS | REVISE | BLOCKED`, the SHA, per-check `id status evidence`, `weak`/`broken` checks in red-first mode, the evidence dir.
- `maintain`: `clean | changed | blocked`, features covered, drift fixed, harness gaps fixed, product regressions found.
