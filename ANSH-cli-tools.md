# ANSH CLI tools — debugging & resolution arsenal

Shared reference for `/ansh-debug` and `/ansh-resolve`. These CLIs turn "ask the user to
paste a log / retry from the UI" into first-party investigation. **Prefer them over asking the
human** when you need CI logs, prod traces, runtime errors, or live cluster/DB state.

## Setup (do this once per shell)

Credentials + PATH live in a git-excluded, `chmod 600` file. Source it before using any tool:

```bash
[ -f "$HOME/.config/ansh-cli/env.sh" ] && source "$HOME/.config/ansh-cli/env.sh"
```

It sets `PATH` (bun global bins + homebrew) and `SIGNOZ_BASE_URL`. Secrets
(`SIGNOZ_API_KEY`, `BUILDKITE_API_TOKEN`, `SENTRY_AUTH_TOKEN`) are filled by the user via
`read -s` helpers so they never hit a transcript. If a tool reports "unauthorized / missing
token", the fix is **tell the user which token is missing**, not to work around it.

Verify auth quickly: `signoz config doctor` · `bk user --help` (or `bk build list -p <pipe>`) ·
`sentry-cli info`.

## The point-of-use map — symptom → tool

| You have… | Reach for | First command |
|-----------|-----------|---------------|
| A SigNoz trace id / failing service | **signoz** | `signoz traces get <trace-id>` |
| A Buildkite CI failure (buildkite/* check) | **bk** | `bk build view <n> -p <pipeline>` |
| A prod runtime crash / Sentry issue | **sentry-cli** | `sentry-cli issues list` |
| A GitHub PR / check / review thread | **gh** | `gh pr checks`, `gh pr view --json ...` |
| A misbehaving running service | **kubectl / k9s / argocd** | `kubectl logs`, `k9s`, `argocd app get` |
| Suspect DB data/state | **psql / pscale / supabase** | `psql "$URL" -c '…'` (see `/lightweight-sql`) |
| A workflow stuck | **temporal** | `temporal workflow list` |
| SQL to lint | **sqlfluff** | `sqlfluff lint <file>` |

## SigNoz (`signoz`) — traces, logs, metrics (read-only)

The CLI ships its own agent guide — **read it live** for exact filter/time syntax rather than
guessing: `signoz agent instructions` (also cached at
`~/.config/ansh-cli/signoz-agent-instructions.md`). Get the lay of the land first:
`signoz agent context`.

```bash
signoz traces get <trace-id>                                              # span waterfall for one trace
signoz traces errors --filter 'resource.service.name = "<svc>"' --from "1 hour"
signoz traces list  --filter 'resource.service.name = "<svc>"' --order-by duration --from "1 hour"
signoz logs search  --service <svc> --filter 'severity_text = "ERROR"' --from "30 minutes"
signoz logs search  --trace-id <trace-id>                                 # logs correlated to a trace
signoz logs context --at <iso-or-unix-ms> --around 20 --service <svc>     # logs around a timestamp
```

- Output is JSON on stdout; **warnings + "0 rows" notes go to stderr — don't discard stderr**,
  it explains empty results. `--output table|tsv|ndjson|values` for other shapes.
- `--filter` uses dot keys (`resource.service.name`, `response_status_code >= 500`), joinable
  with `AND`; `--group-by` uses colon form (`resource:service.name`).
- CI spans (like the db-tests failure) live under `service.name = "buildkite-ci"` with
  `buildkite.pipeline` / `buildkite.step_key` attributes — but for CI, **`bk` is more direct**.

## Buildkite (`bk` — v3) — the real CI truth `gh` can't show

`buildkite/*` checks are Buildkite, not GitHub Actions — `gh run view` can't read them. `bk` can
pull the actual failing step log and **retry a flaky step without pushing an empty commit**.

```bash
bk build list -p <pipeline> --branch <branch>          # find the build number
bk build view <number> -p <pipeline>                   # step states + annotations
bk build view <number> -p <pipeline> --log             # full log (grep for the real error)
bk build retry <number> -p <pipeline>                  # re-run a flaky/infra-failed build
```

Pipelines seen on this repo: `database-pr-db-tests`, `white-check-mark-pr-checks`,
`robot-face-pr-review`, `bell-knock-consistency-check`, `eyes-pr-preview`,
`terraform-infra-preview`. A `bun install --frozen-lockfile` exit-1 is usually the Playwright
postinstall/CDN flake, **not** a lockfile drift — confirm locally with
`bun install --frozen-lockfile` (exit 0 = retry the step, don't touch the lockfile).

## Sentry (`sentry-cli`) — prod errors

```bash
sentry-cli issues list --org <org> --project <project> --query 'is:unresolved'
sentry-cli issues list --query 'is:unresolved' --max-rows 20
```
Use to attach a real stack trace / event count to a `/ansh-debug` root cause. Auth:
`sentry-cli login` or `SENTRY_AUTH_TOKEN`.

## Cluster / infra (read-only first)

```bash
kubectl get pods -A | grep <svc>;  kubectl logs -f <pod> --tail=200;  kubectl describe pod <pod>
k9s                                    # TUI for fast triage
argocd app get <app>;  argocd app list # deploy/sync state — is prod actually running your commit?
aws ...                                # session-manager-plugin needed for SSM sessions (sudo install)
```
Treat these as **diagnostic** in the loop. Any mutating command (`kubectl delete/apply`,
`argocd app sync`, terraform apply) is a shared-state action — surface it, don't auto-run.

## DB (see `/lightweight-sql` before querying a shared DB)

```bash
psql "$DATABASE_URL" -c 'SELECT ...'    # inspect data state behind a bug
pscale ...                              # PlanetScale branches
supabase ...                            # Supabase local/remote
```

## Guardrails

- **Read-only by default.** These tools exist to *understand* the failure. Retrying a flaky CI
  step is fine; deploys, DB writes/schema pushes, `kubectl apply/delete`, `argocd sync`, terraform
  apply are outward/shared-state. Never run them from an `/ansh` run: park the work per
  `skills/_shared/autonomy.md`.
- **Missing token ≠ dead end, but ≠ workaround either.** Name the missing credential in the report.
- **Verify, don't trust.** A trace/log/Sentry event is a *lead* toward root cause, same as a bot
  comment — confirm against the code before you fix.
