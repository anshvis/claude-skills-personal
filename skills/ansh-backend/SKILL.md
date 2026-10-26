---
name: ansh-backend
description: "Verify the backend directly: API responses, DB state, jobs, crons and projections, events, logs and traces, and CI at the head SHA, under the right secrets config, with evidence. Use for the backend half of a verification check, to reproduce a backend bug, or to read what CI says."
---

# /ansh-backend

**Goal:** prove what the backend did at a given SHA, with evidence another agent can rerun.

**Uses:** [verification](../_shared/verification.md), [autonomy](../_shared/autonomy.md),
[principles](../_shared/principles.md), [ledger](../_shared/ledger.md) (`../_shared/ansh-log`), [memory](../_shared/memory.md),
[CLI tools](../_shared/cli-tools.md), [recipes](references/recipes.md),
[CI triage](../ansh-resolve/references/ci-triage.md), `_stack.md` from
[/ansh-verify](../ansh-verify/SKILL.md), [/ansh-control](../ansh-control/SKILL.md),
[/lightweight-sql](../lightweight-sql/SKILL.md).

`/ansh-verify` calls it for the `backend` half of a check ([surface](../_shared/verification.md#surface)):
alone for `backend` and for CLI or API checks, first for `data-visible` (then one read-only
`/ansh-control` look), and together with `/ansh-control` for `full-stack`, where `/ansh-control`
performs the user action and this skill asserts that action's side effects at the same SHA.
`/ansh-debug` uses it to reproduce a backend bug.

## Secrets and config

- web-app reads secrets from AWS SSM through the `vitalize` CLI, not Doppler (the doc is still
  named `apps/docs/codebase/getting-started/doppler.mdx`). Run commands with
  `vitalize run -c <config> -- <cmd>`. No `vitalize`: `bash scripts/with-secrets.sh
  --config=<config> -- <cmd>`.
- `doppler run` only in repos that use Doppler: check for `doppler.yaml` or a doppler setup first.
- `ExpiredToken` or no credentials: BLOCKED with "run `aws sso login`".
- Never print secret values. Never put `vitalize env` output in logs or evidence.

| Config | Use |
|---|---|
| `local` | Local Postgres test mode (`IS_TEST=true`). The default, and the only one where writes are allowed. |
| `dev` | Shared PlanetScale dev DB. Read-only, queries kept light per `/lightweight-sql`. |
| `dev_preview` | Read-only, through the API only. |
| `prod`, `prod_local`, `dev_deploy` | Never touched. Refuse, and park per autonomy if a check truly needs them. |

## Steps

1. **Load the check** from the caller: the contract line, the SHA, the config (default `local`).
2. **Doctor.** Run the `_stack.md` doctor. Server not running: start the local stack per
   `_stack.md`, then doctor again. Record the running build's SHA; it must be the pinned one.
3. **Read before.** Capture the DB rows, columns and invariants the check names, read-only
   (`psql` via the config's URL, `pscale` for PlanetScale branches, the repo's Drizzle helpers).
   Apply `/lightweight-sql`.
4. **Act.** By what the check exercises ([recipes](references/recipes.md)):
   - **API:** hit the real local server (`curl`, or the repo's client or RPC test helper) with
     seeded local auth. Save the request (secrets redacted), status, body and timing.
   - **CLI:** run the command. Save it, the exit code, stdout and stderr.
   - **Job, cron, projection, queue:** trigger it through the repo's own local entry point (the
     dev command, test harness or job runner). Run it twice when the contract asks for
     idempotency.
   - **full-stack:** don't act. `/ansh-control` performs the action; take its time window.
5. **Read after and assert.** Assert the response shape and the side effect, not only the status
   code: the rows after, the log line or metric the job emits, the event published. Writes and
   migrations happen only on `local` or a PlanetScale branch DB, never a shared one.
6. **Signals.** Read-only: `signoz` traces, logs and metrics for the request or job, `sentry-cli`
   for errors, per [CLI tools](../_shared/cli-tools.md).
7. **CI**, when a check is "the suite passes": pull the result for the exact head SHA. `bk` or the
   Buildkite MCP for `buildkite/*` checks (`gh` can't read Buildkite), `gh run view` for GitHub
   Actions, Test Engine for per-test results.
8. **Perf**, when the contract has a budget: base and head, same method, 3 runs each. Name the
   limiter before trusting the number.
9. **Save evidence** under `~/.agentic-workflow/<repo-slug>/evidence/<branch>/<sha>/backend/` (or
   the task's dir when `/ansh-verify` passes one): the command, the config name (never values),
   the output and the verdict. Clean up what you started. Log
   `ansh-log ansh-backend check <PASS|FAIL|BLOCKED> --surface backend --task <id> --ids <AC-n>`.
   A config, seed or environment trap you had to work around goes to project memory as a `gotcha`
   candidate per [memory](../_shared/memory.md).

## Edge cases

| case | do |
|---|---|
| Credentials expired (`ExpiredToken`, no credentials) | BLOCKED: "run `aws sso login`". |
| Server not running | Start the local stack per `_stack.md`, doctor first and after. |
| Instance running at another SHA | Rebuild or relaunch. A check at another SHA is not a pass. |
| A check needs a prod or shared write | Don't. Park per autonomy. |
| A query would scan a big shared table | Rewrite it per `/lightweight-sql`, or run it on `local`. |
| CI build is for a different SHA, or superseded | Not evidence. Wait for the head's build. |
| Flaky CI job | One retry per job per head, per [CI triage](../ansh-resolve/references/ci-triage.md). |
| Trace or log not found | Read stderr, then widen the time window. |
| Response passes but the DB is wrong | FAIL. The side effect is the truth. |
| CLI hangs | Capture the screen, logs and a stack or CPU sample before interrupting. |
| Repo uses Doppler, not `vitalize` | `doppler run` with the matching config. Same config rules. |

## Output

`PASS` (response and side effects matched), `FAIL` (with the first wrong value, before and after),
or `BLOCKED` (name the missing piece). Include the SHA, the config name, each command with its
result, and the evidence path.
