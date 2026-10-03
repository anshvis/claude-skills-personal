---
name: ansh-codex
description: CROSS-MODEL OUTSIDE VOICE in the Karpathy loop — runs the OpenAI Codex CLI directly (no gstack) on demand. Three modes — review (diff vs a base, [P1]/[P2] pass/fail gate), challenge (adversarially attack a plan, design, or diff), and consult (ask codex anything about the repo, with session resume for follow-ups). Same mechanism /ansh-plan and /ansh-review use internally (ANSH-codex.md), exposed as a standalone command. Use when the user says "/ansh-codex", "ask codex", "codex review", "codex challenge", "second opinion", or "outside voice".
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# /ansh-codex — Cross-model outside voice

A different model is structurally blind to different things than Claude. `/ansh-plan` (challenge)
and `/ansh-review` (review) already run codex automatically; this skill is the **manual** handle on
the same mechanism, for when I want codex's take outside the loop.

**Source of truth for invocation:** `~/.claude/skills/ANSH-codex.md` — read it first. It owns the
binary + auth check, the filesystem-boundary preamble, the exact `codex review` / `codex exec`
commands, the reasoning-effort rule, and the presentation format. This skill only adds mode
selection + consult mode; don't duplicate or drift from that file.

**Effort: cheap on Claude's side.** Codex does the thinking; Claude scopes the prompt, runs it,
presents the output verbatim, and gives one recommendation line.

## Step 0 — Pick the mode

From the args (`/ansh-codex <mode> [focus]`) or the ask:

| Mode | Trigger | What codex gets |
|---|---|---|
| **review** (default when there's a branch diff) | "review", "second opinion on this diff" | `git diff <base>...HEAD`, plus any done-criteria / focus the user gave |
| **challenge** | "challenge", "break this", "attack the plan" | `.ansh/plan.md` + packets if they exist, otherwise the diff or the file(s) named |
| **consult** (default otherwise) | "ask codex …", a question | the question + repo access, read-only |

Base branch: `dev` unless the user/PR says otherwise.

## Step 1 — Availability

Run the ANSH-codex.md setup check. If unavailable, say `CODEX_UNAVAILABLE: <reason>` and stop —
do not fake a codex answer with an in-session one.

## Step 2 — Run

Always `cd "$(git rev-parse --show-toplevel)"` and prepend the filesystem boundary from
ANSH-codex.md.

- **review** — the ANSH-codex.md review-mode command (`timeout 330 codex review "..."`), scoping
  the diff in the prompt (not `--base`). Gate: any `[P1]` → FAIL.
- **challenge** — the ANSH-codex.md challenge-mode command (`codex exec ... -s read-only`).
  Re-target the prompt at whatever is being challenged (plan files, a diff, a named file) and keep
  the "be adversarial, no compliments" framing.
- **consult** — read-only exec with the question:

  ```bash
  printf '%s' "<boundary>

  <question + any file/line pointers>" | timeout 600 codex exec - -s read-only -c 'model_reasoning_effort="high"'
  ```

  Follow-up in the same thread: `codex exec resume --last -` (same stdin pattern). If resume fails,
  start a fresh exec and say so.

Invocation gotchas (from experience): pipe long prompts via stdin rather than a giant argv string,
and run with the Bash sandbox disabled — otherwise codex can exit silently with no output or get
SIGKILLed. Output buffers until exit, so a 0-byte file mid-run is normal; wait for completion.
Sanity-check the diff range isn't polluted by a stale `origin/<base>` (fetch first if unsure).

## Step 3 — Present

Use the ANSH-codex.md presentation block verbatim (`CODEX SAYS (<mode>):` … full output, never
truncated or summarized; `GATE:` line in review mode only), then one line:

```
Recommendation: <action> because <one-line reason citing a specific finding>
```

If Claude disagrees with a codex finding, say so after the block with the cited code — never
silently drop it. Don't auto-fix findings; hand back (fixes go through `/ansh-task` / `/ansh-debug`).
