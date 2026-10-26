---
name: lightweight-sql
description: "Make a SQL query as lightweight as possible to avoid DB load and rate limiting (esp. row-read limits and Drizzle round-trips). Use when writing/reviewing a query that runs against a shared/metered DB, when a query is slow or trips rate limits, or when the user invokes /lightweight-sql. Rewrites the query to minimize rows scanned, columns materialized, and round-trips, then explains the change."
---

# lightweight-sql

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

Rewrite a SQL (or Drizzle) query to do the least work the database can get away with, then state what changed and why. The metric that matters is usually **rows read/scanned** (what most managed-DB rate limits count), then **round-trips**, then **bytes materialized**.

## When to apply

- The user invokes `/lightweight-sql` or asks to make a query lightweight / cheaper / rate-limit-safe.
- A query runs against a shared or metered DB (PlanetScale-style row-read limits, connection caps).
- A query is slow, fans out, or trips rate limits.

## Principles (apply in order, stop when the query is lean)

1. **Filter first on indexed columns.** Ensure the most selective `WHERE` predicates hit an index so the driving table is range/index-scanned, not full-scanned. Name the index you're relying on; if none exists, say so.
2. **Never `SELECT *`.** Select only the columns actually consumed. For existence/counts, select nothing from the inner relation — use `EXISTS`/`COUNT`.
3. **Prefer semi-joins (`EXISTS`) over join + `GROUP BY` when you only need existence.** `EXISTS` short-circuits at the first matching row and avoids the row-multiplication of a fan-out join — fewer rows read for one-to-many relationships.
4. **One round-trip, not N.** Compute everything in a single statement. This is the #1 Drizzle trap: don't `findMany` then loop with per-row follow-up queries (N+1), and don't pull rows into JS to filter/aggregate — push `count()`/`filter`/aggregates into SQL.
5. **Aggregate before joining; avoid Cartesian fan-out.** If a join multiplies rows only to be collapsed by `GROUP BY`/`DISTINCT`, pre-aggregate or use a semi-join instead.
6. **Push predicates down.** Move filters into subqueries/CTEs/join conditions so they cut scanned rows as early as possible.
7. **Bound the result.** Add `LIMIT` whenever a sample suffices; use `TABLESAMPLE` for estimates over huge tables. (Skip for single-row aggregates.)
8. **Avoid work you can reuse.** Classify small dimension sets (e.g. which unit ids are float pools) once, not per row.

## Drizzle-specific

- Use `db.select({...})` with explicit columns or `sql` aggregates; avoid `query.findMany()` + `.length` / `.filter()` in JS.
- Collapse multi-step reads into one query with joins/CTEs/`EXISTS` rather than chained awaits.
- Watch implicit `SELECT *` from `db.select().from(t)` with no projection.

## Output

Lead with a one-line verdict (lightweight already, or the main cost found). Give the rewritten query. Then a short list: each change → which principle → expected rows-read/round-trip impact. Name any index the plan depends on. If two formulations trade off (e.g. `EXISTS` short-circuit vs single-pass join) and the winner depends on data shape, say which to prefer and why. Don't change result semantics without flagging it.

## Reference example (gold standard)

A "count employees not under a concrete org" check kept tripping a managed-DB row-read limit. The
progression that fixed it — each step applies a principle above:

1. **Heavy (trips the limit):** `LEFT JOIN profile→profile_unit→unit` + `GROUP BY profile.id` with
   per-cohort `COUNT(... FILTER)`. Reads every membership row for every profile and fans out
   one-to-many before collapsing — violates P3/P5.
2. **Lighter:** two correlated `EXISTS` semi-joins per profile (has-non-float-unit, has-any-unit) to
   produce the full breakdown. Short-circuits, no fan-out (P3) — but still two probes per row.
3. **Lightest exact (the gold standard):** keep only the number that drives the decision
   (`at_risk = float_only + no_unit`), so it collapses to **one** short-circuiting `NOT EXISTS`,
   scoped on the child's `health_system_id`, with dead predicates dropped (a `NOT NULL` column needs
   no `IS NOT NULL`). One round-trip, ~1 row read per active profile:

   ```sql
   SELECT
     count(*) AS total_active_badged,
     count(*) FILTER (
       WHERE NOT EXISTS (
         SELECT 1 FROM profile_unit pu JOIN unit u ON u.id = pu.unit_id
         WHERE pu.profile_id = p.id
           AND pu.health_system_id = 46
           AND NOT (u.is_system_float_pool OR u.is_hospital_float_pool)
       )
     ) AS float_or_unorged_at_risk
   FROM profile p
   WHERE p.health_system_id = 46 AND p.is_active = true AND p.badge_number <> '';
   ```

4. **Fallback when even exact trips (approximate — flag the semantics change):** add
   `TABLESAMPLE BERNOULLI (10)` to the driving table and scale the result ×10.

The lesson the example encodes: **the cheapest exact query computes only the figure the decision
needs, as one short-circuiting semi-join scoped by the most selective indexed predicate.** Drop every
column, predicate, and subquery that the decision doesn't require before reaching for sampling.
