# Blast radius

How `/ansh-review` rates what breaks if a change is wrong. Classify each file, then the PR or task,
by its riskiest part.

| Kind | What it does | Base blast radius |
|---|---|---|
| setup | New type, schema, table, config or dependency. Nothing calls it yet. | low |
| logic | A behavior: function, facade method, model or rule. Tests reach it. Not switched on. | medium |
| wiring | Registers a layer, route, RPC, cron, flag, UI entry or caller. Makes it run in prod. | high |

- Logic hiding in a wiring PR (new branching, calculations, error handling) is a large plan gap.
- Mixed kinds is a small plan gap: recommend a split unless tiny.
- Raise to **high** when the change edits something existing with callers (shared type, contract,
  schema, RPC, public function, even in setup), touches a migration or prod data or deletes
  anything, touches auth, permissions, payments, payroll, pay rules or patient data, changes what
  customers see or what runs on a schedule without a flag (or flag on), or changes CI, deploy or
  infra config.
- Lower one level when the new path is unreachable in prod: flag off by default, unregistered or
  uncalled.
