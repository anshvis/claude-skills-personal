---
name: add-otel
description: Add observability (logs, traces, metrics) to the code in a PR/diff, following Vitalize's observability-101 conventions and SigNoz. Use when asked to "add otel", "add observability", "instrument this", "add logs/traces/metrics", or before shipping a feature that has new error paths, external calls, background jobs, RPC endpoints, or slow operations. Instruments code only; hands SigNoz Terraform alert authoring off to /observability.
---

# add-otel

Instrument the code in a PR so we can understand it in production. This skill is the **code-instrumentation half** of observability. Authoring SigNoz alerts/dashboards in Terraform is `/observability`'s job — this skill ends by handing off to it.

Gold-star reference: `docs.vitalize.care/codebase/debugging/observability-101` (the rubric below is derived from it) and the in-repo exemplar `apps/api-server/src/utils/avatar-metrics.ts` (metric-on-error + log-beside pattern, cited by the doc).

## Inputs

- **Scope** — the diff to instrument. Default: the current branch vs its base (`git merge-base origin/<base> HEAD`). If the user names a file/feature, respect that scope literally.
- If there is no diff and no named scope, ask what to instrument.

## The three signals (pick the right one — this is the first rubric check)

| Use | When | Cardinality |
|-----|------|-------------|
| **Log** | a human needs the exact message/context: errors, startup/crash, breadcrumbs, audit context | high-card attributes fine |
| **Trace span** | understand ONE request/job/workflow end-to-end: where time went, which downstream failed | high-card attributes fine |
| **Metric** | graph or alert on a value over time: counts, gauges, latency percentiles | tags MUST stay low-cardinality |

Wrong-signal smell: a `request_id`/`trace_id`/`user.id` on a **metric** tag. Those belong on logs/traces. A threshold you want paging on belongs on a **metric**, not a log alert (log alerts are a last resort).

## Rubric (derived from observability-101 — hold the diff to these)

1. **Right signal.** Threshold/trend → metric. Exact message → log. End-to-end investigation → trace span. Don't reach for a log alert when a counter would do.
2. **Metric tags are low-cardinality.** Allowed: `environment`, `service.name`, `status_code`, normalized `route`, `job_name`, `queue`, bounded enums (e.g. `source`, `had_error`). Forbidden on metrics: `user.id`, `email`, `request.id`, `trace.id`, raw ids, free text.
3. **Attribute naming is predictable.** `snake_case` words, `.` for namespaces, stable IDs over display names, reuse existing names, prefer OpenTelemetry semantic conventions for platform fields (`service.name`, `http.request.method`, `url.path`, `db.system.name`, `messaging.destination.name`). Canonical domain attrs: `user.id`, `user.email_id`, `user.hospital_id`, `health_system.id`, `company_id`, `shift_id`/`schedule_id`, `rpc.tag`, `job.name`/`cron_name`, `integration.name`, `external.request_id`, `posthog.session_id`. Plain names only when globally obvious: `environment`, `reason`, `status`.
4. **Error paths get a counter + a log beside it.** The doc's load-bearing pattern: emit a counter ONLY on error paths (keeps it low-noise and alertable) and log rich context right next to the emit, so a responder jumps alert → logs in one step. Don't emit the counter on success paths.
5. **Domain context, not just infra.** SigNoz already attaches `service.name`, k8s fields, trace/span IDs. Add attributes that explain the *business operation* (which hospital, which rpc, which integration, which shift).
6. **Effect-native instrumentation for Effect code.** Use `Effect.withSpan` + `Effect.annotateCurrentSpan` for spans, `Effect.annotateLogs` for log attributes, and `Metric.counter/gauge/timer` for metrics — not raw `@opentelemetry/api` calls inside Effect services.

## Repo idioms (instrument like the code already does)

- **Spans:** `Effect.withSpan("redis.lock.acquire", { attributes: {...} })` + `Effect.annotateCurrentSpan({...})`. Exemplar: `packages/database/src/redis/redis.ts`.
- **Metrics (Effect):** define named metrics once in a `metrics.ts` module and apply with `.pipe(metric(...))` / `Metric.increment`. Exemplar: `packages/database/src/integrations/ukg/metrics.ts` (`Metric.counter("ukg.api.requests")`, `Metric.timer("ukg.api.duration")`). Metric names are dotted, snake_case segments.
- **Log attributes (Effect):** `Effect.logInfo(msg).pipe(Effect.annotateLogs({ component, ...domainAttrs }))` — the `logSourceInfo` helper in `IngestionAdapter.ts` is this shape.
- **Metric + log error pairing (non-Effect / handler):** `apps/api-server/src/utils/avatar-metrics.ts` — counter emitted only when `had_error`, `logger.error` beside every emit.
- **Local trace verification:** `bun run otel:local` (see AGENTS.md / `apps/docs/codebase/debugging/local-traces-grafana.mdx`).
- Deps already present: `@effect/opentelemetry`, `@opentelemetry/api`.

## Process

1. **Scan the scope.** `git diff <base>...HEAD` (or the named files). Build a short list of instrumentation candidates:
   - new/changed **error paths** (catchAll, rejected/failed branches, thrown errors) → counter + log (rubric 4)
   - new **external calls** (HTTP, vendor API, DB, queue, auth) → span + duration metric + error counter
   - new **background jobs / crons / RPC endpoints** → span around the unit of work; `job.name`/`rpc.tag` attribute; failure counter
   - **slow or fan-out operations** → span so the time is visible
   - high-value **breadcrumbs** (startup, config, batch sizes, parity/anomaly gaps) → structured log with domain attrs
2. **For each candidate, pick the signal** via the table + rubric 1. State the choice in one line.
3. **Instrument** using the repo idioms above. Reuse existing metric modules / log helpers; only create a new `metrics.ts` if the area has none. Apply rubric 2–6 to every attribute and metric name.
4. **Verify** — type-check the touched packages and run their unit tests. If a metric module changed, confirm names compile. Report results plainly.
5. **Hand off alerts.** For any counter/gauge worth paging or graphing, do NOT hand-write the Terraform here. List the alert-worthy metrics and recommend: "Run `/observability` to author the SigNoz alert (Terraform in `infra/observability/*.tf`), route to the team channel, page only if someone must act." If the user wants the alert in this same PR, invoke `/observability` (the doc encourages metrics + alerts in the same PR while the behavior is fresh).

## Guardrails

- **Code only.** This skill does not author SigNoz alerts/dashboards — `/observability` does (it interviews, verifies real metric/service names, keeps tags low-cardinality, opens the PR). Recommend or invoke it; don't reinvent it.
- **No high-cardinality metric tags.** If you're tempted to tag a metric with a user/request/trace id, that's a log/trace attribute instead. Hard rule.
- **Don't over-instrument.** Instrument error paths, boundaries, and slow/critical operations — not every line. A span per trivial pure function is noise. Match the density of the surrounding code.
- **Reuse names.** Before inventing an attribute or metric name, grep for an existing one. Drift makes SigNoz unqueryable.
- **Stay in scope.** Instrument the diff's behavior; don't refactor working code to add spans.

## Output

Lead with a one-line verdict (what signals were added, and what's left for `/observability`). Then a compact list: `signal — location — attribute/metric name — why`. Then verification results, then the alert hand-off recommendation (the specific metric names worth alerting on). Quote the rubric criterion when you skip or reshape an instrumentation request so the convention is visible.
