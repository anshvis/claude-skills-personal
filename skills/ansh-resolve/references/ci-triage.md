# CI triage

Owned by `/ansh-resolve`. `/ansh-pr-loop` and `/ansh-backend` read it. One copy.

Every failing check gets its own investigation. Never treat "CI is red" as one item. Never guess
the cause from the check name. Never push an empty commit to see if it passes.

## 1. List the checks on the head

```bash
gh pr view <n> --json headRefOid,baseRefName,headRefName
gh pr checks <n> --json name,state,bucket,link
```

Each `buildkite/*` check links to `https://buildkite.com/vitalize/<pipeline>/builds/<number>`.
Parse the pipeline slug and build number from the link. Anything else is usually GitHub Actions.

## 2. Make sure the build is for the head

Fetch the build (`buildkite_get_build`, or `buildkite_list_builds` with `branch`) and compare its
`commit` with `headRefOid`. A build for an older commit is stale. A build `canceled` because a
newer push superseded it is stale. Ignore stale builds and look at the head's build. Only a
failure on the head counts.

## 3. Pull the failure

**Buildkite.** Prefer the Buildkite MCP tools, always with `org_slug: "vitalize"`. Use `bk` only
when it is on `PATH` (source `~/.config/ansh-cli/env.sh` first, see `_shared/cli-tools.md`).
`gh run view` can't read Buildkite logs.

- Start with `buildkite_get_failed_job_logs` (pipeline slug, build number). It returns the failed
  jobs, the build annotations and each job's log tail in one call.
- Trust the annotation's own count (e.g. "5365 tests, 1 failures") over shard noise in the logs.
- If the tail doesn't show the cause, call it again with a runner-specific `grep_pattern`:

  | Runner | Pattern |
  |---|---|
  | bun, vitest, jest | `\(fail\)\|✗` |
  | tsc | `error TS\d+` |
  | DB tests | `deadlock\|constraint\|violates` |
  | lint, format | `Error:\|FAILED` |

  Avoid `error|fail`. It matches wrapper noise.
- Go deeper with `buildkite_search_logs` (needs the job UUID) or `buildkite_get_job_logs`.
- Test Engine suites: `buildkite_get_build_test_engine_runs`, then `buildkite_get_failed_executions`
  with `include_failure_expanded: true` for the full assertion and stack trace.
- `bk` fallback: `bk build list -p <pipeline> --branch <branch>`, then
  `bk build view <number> -p <pipeline> --log`.

**GitHub Actions.** `gh run view <run-id> --log-failed`, or the `github_get_job_logs` capability.

**Neither works** (no MCP, no `bk`, no token): report BLOCKED and name the missing piece. Never
mark the check green or guess its cause.

Write down, per failure: pipeline, build number, job (step label), the exact error lines, and the
file or test they name. Every later decision cites this record.

## 4. Classify from the evidence

| Class | Evidence | Do |
|---|---|---|
| Code failure | The error names code, a test or a type this PR touches, or the step passes on the base and fails here. | Reproduce locally with the step's own command (from the job log or `.buildkite/**/pipeline.yml`). Fix through `/ansh-task`, or `/ansh-debug` if the cause isn't obvious. Not fixed until the same step passes on the new head's build. Ledger reason: `regression`, `lint`, `types` or `missed-edge-case`. |
| Stale base | The failure is in code the diff never touches, and `git merge-base --is-ancestor origin/<base> HEAD` fails. | Merge `origin/<base>` in per [stacking](../../_shared/stacking.md), re-run verification, push. Don't retry. Reason: `ci-stale-base`. |
| Flaky or infra | Agent lost, a timeout with no test failure, a registry or network error (CodeArtifact 401, `ECONNRESET`), an OOM kill, or a test unrelated to the diff that passes on the base. | Retry that job once: `buildkite_retry_job` with the job UUID (`buildkite_rebuild_build` only when the whole build died before running jobs; `bk build retry <n> -p <pipeline>` as fallback). Reason: `ci-flake`. |
| Outside the PR | The same step fails on the base at its current tip. | Don't fix it in this PR. Report it with the base build link. It blocks the merge only if the check is required. Merge the base in again once the base is green. |
| Known | Memory or the repo documents this failure as expected for this branch (e.g. playwright on the cba base). | Note it in the status line. Don't retry or loop on it. Counts as green only if the check isn't required. |
| Unclear | The log supports no reading. | Run one deeper search (step 3). Still unclear: report it with the evidence. No blind retry. |

Rules:
- At most one retry per job per head commit. A retried job that fails the same way isn't flaky.
  Reclassify it from the log.
- A `bun install --frozen-lockfile` exit 1 is usually the Playwright postinstall or CDN flake, not
  lockfile drift. Confirm with `bun install --frozen-lockfile` locally. Exit 0 means retry the
  step. Don't touch the lockfile.
- A `reviewDecision: CHANGES_REQUESTED` from a required-review bot (`clearpath-it`,
  `robot-face-pr-review`) is a review block, not a red check. Pushing the fix makes the bot
  re-review.
- A head build still `running` or `scheduled` is pending, not failed. Watch it (see
  `/ansh-pr-loop` cadence) instead of retrying.

## 5. Report per check

One line per check in each status update:

```
<check>: passed | running | failed (<step>: <one-line cause>) -> fixed in <sha> | retried | stale-base merged | outside PR | known | unclear
```

A failure is gone only when the head's build for that check has passed.
