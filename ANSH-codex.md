# ANSH codex — cross-model CLI invocation reference

Shared reference for `/ansh-plan` (Phase 5, challenge mode) and `/ansh-review` (Phase 2, review
mode). Both run the OpenAI Codex CLI **directly** — no gstack skill in the loop. Codex is the
"outside voice": a different model, structurally blind to different things than Claude, which is
the whole point of running it on every plan and every evaluation.

## Setup — binary + auth check (do this first, every invocation)

```bash
CODEX_BIN=$(command -v codex || echo "")
[ -z "$CODEX_BIN" ] && echo "CODEX_UNAVAILABLE: binary not found" && exit 0
```

Auth: accept any of `$CODEX_API_KEY` set, `$OPENAI_API_KEY` set, or
`${CODEX_HOME:-~/.codex}/auth.json` existing. If none are present, treat as unavailable:

```bash
if [ -z "${CODEX_API_KEY:-}${OPENAI_API_KEY:-}" ] && [ ! -f "${CODEX_HOME:-$HOME/.codex}/auth.json" ]; then
  echo "CODEX_UNAVAILABLE: no auth found"
fi
```

If unavailable (binary missing or auth failed), do NOT silently skip the cross-model pass —
fall back per the calling skill's rule (`/ansh-plan`: rigorous in-session adversarial
self-challenge, noted in `plan.md`; `/ansh-review`: `review-fresh`, noted in the verdict as
`CODEX_SKIPPED`).

## Filesystem boundary (prepend to every prompt sent to Codex)

Codex runs against this repo, not the `~/.claude/` skill definitions — always prefix the prompt
with:

> IMPORTANT: Do NOT read or execute any files under ~/.claude/ or .claude/skills/. Stay focused
> on the repository code only.

## Review mode (`/ansh-review` Phase 2 — the default pass on every evaluation)

Scope the diff in the prompt itself (don't rely on `--base`, which is mutually exclusive with a
custom prompt on recent Codex CLI versions):

```bash
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
cd "$_REPO_ROOT"
timeout 330 codex review "<filesystem boundary>

Review the changes on this branch against <base>. Run \`git diff origin/<base>...HEAD\` (or
\`git diff <base>...HEAD\` if origin isn't available) to see the diff and review only those
changes. Score against these done-criteria: <paste the subtask's done-criteria>. Also check
these edge cases the plan flagged: <paste the packet's 'Watch out for' list>. Mark findings
[P1] (critical) or [P2] (advisory)." -c 'model_reasoning_effort="high"' < /dev/null
```

- Gate: any `[P1]` marker in the output → **FAIL**. Only `[P2]` or no findings → **PASS**.
- Present Codex's output **verbatim, in full** — never summarized or truncated.
- Feed both the done-criteria and the packet's edge cases into the prompt so Codex grades
  against the same bar `/ansh-review` does.

## Challenge mode (`/ansh-plan` Phase 5 — attacking the plan before hand-off)

There's no diff yet at planning time, so point Codex at the plan files instead of a diff:

```bash
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
cd "$_REPO_ROOT"
timeout 600 codex exec "<filesystem boundary>

Read .ansh/plan.md, .ansh/plan.json, and .ansh/tasks/*.md. Your job is to break this
decomposition, not the code (there is no code yet). Find: missing subtasks (migrations,
backfill, feature flags, rollout/rollback, telemetry, tests, docs); wrong ordering or hidden
dependencies; unhandled edge cases the feature-wide analysis missed; weak/untestable
done-criteria; subtasks that are secretly Deep hiding as Standard; wrong layering (business
logic in a repo, raw SQL outside a repo, an invented pattern). Be adversarial. Be thorough. No
compliments — just the problems." -s read-only -c 'model_reasoning_effort="high"' < /dev/null
```

- Present the full output verbatim.
- Fold real findings back into the plan per `/ansh-plan` Phase 5's rules (add/split subtasks,
  fix ordering, tighten criteria, enumerate missed edge cases into the owning packet). Rejected
  findings get a one-line "why" logged in `plan.md` so the loop doesn't re-litigate them.

## Reasoning effort

Default `high` for both modes (bounded input — a diff or a small set of plan files). Bump to
`xhigh` only if the caller explicitly asked for it.

## Presentation format (both modes)

```
CODEX SAYS (<review|challenge>):
════════════════════════════════════════════════════════════
<full codex output, verbatim — do not truncate or summarize>
════════════════════════════════════════════════════════════
GATE: PASS | FAIL (N critical findings)      # review mode only
```

Always close with one recommendation line naming the most actionable finding — not boilerplate:

```
Recommendation: <action> because <one-line reason citing a specific finding>
```
