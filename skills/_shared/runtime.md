# Runtime

Read once per session when using an `/ansh` skill. It maps the skills onto whatever host runs
them (Claude Code, Codex, T3). [Autonomy](autonomy.md) still decides what needs me (nothing
during a run).

## Loading and paths

- Claude Code invokes `/ansh-plan`; Codex uses `$ansh-plan`. A plain request naming the skill works.
- Use the host's skill loader. Otherwise read the named `SKILL.md` from the installed skills root.
- Resolve sibling skills, `_shared/` and `ANSH*.md` relative to that root (follow symlinks). Don't
  assume `~/.claude`.
- Read only the dependencies the current phase needs.

## Tools

- Map Bash/Read/Edit/Write/Grep/Glob to the host's shell, file and search tools.
- Map Agent/Task/Workflow to whatever delegation exists. With none, run roles serially in-session.
- Tool names like `mcp__claude_ai_Linear__get_issue` or `mcp__vitalize__buildkite_*` name a
  capability. Find the connected equivalent and read its real schema.
- Prefer existing authenticated CLIs (`gh`, `bk`, `signoz`, see `ANSH-cli-tools.md`). Never print
  credentials or connect a new service to satisfy an example.
- A missing ticket update is skipped with a note. Missing ticket content or CI logs that the work
  depends on: report BLOCKED with what's missing. Never fabricate it or mark an unchecked gate green.
- Track progress with the host's todo tool, or a small `.ansh/progress.md` when there isn't one.

## Models (quality first, OpenAI preferred)

| Work | Model | Effort |
|---|---|---|
| Mechanical edits, formatting, easy-to-check summaries | `gpt-6-luna` | medium |
| Implementation, ordinary debugging, orchestration | `gpt-6.1-sol` | high |
| Planning, review, hard debugging, high-risk changes | `gpt-6-astra` | high; xhigh or max when hard |

- Luna only for clearly mechanical work. Sol when judgment or real code is involved.
- Go to Astra at once for ambiguity, tangled dependencies, security or data-loss risk, concurrency,
  or low confidence. Don't burn failed attempts first. Reassess the model after every failed
  hypothesis.
- Never downgrade to save cost. Legacy `economy`/`sonnet` stamps mean Sol; `reasoning`/`opus` mean Astra.
- Refresh the live model catalog before dispatch. If the preferred model is missing, use the
  strongest available one in the family and say so. Never claim a switch the host didn't make.
- On T3, pick the Codex provider instance; use native delegation when it supports the model and
  `delegate_task` for cross-provider or worktree-isolated work. A Claude parent may run OpenAI
  children that way. Keep any model I named for a task.

## Independent review

- Prefer a strong reviewer on a different model from the author (Astra by default). If the author
  already used Astra, a fresh-context Astra beats a weaker model picked for diversity.
- Give the reviewer the intent, criteria, diff or plan path, standards and read-only scope. Not the
  author's reasoning. Forbid it from delegating or re-entering the loop.
- On Claude, `/codex` works when Codex is installed and authenticated. A second Codex process on a
  Codex host isn't cross-model.
- No delegation available: run a separate in-session adversarial pass and record
  `independence: in-session`. Never call it independent.
- Record reviewer provider, model and independence (`cross-model`, `fresh-context`, `in-session`).
  If a skill requires fresh context and none is available, return BLOCKED.

## Orchestration

- Workflow/`pipeline()`/`parallel()` only when that API exists. Otherwise dispatch ready packets
  through available delegation in dependency order, or serially.
- Don't dispatch a dependent until its prerequisite commits are visible in its checkout. Fresh
  worktrees don't inherit `.ansh/`: put the packet in the child's prompt.
- Serialize writers to overlapping files.
- Browser work: the host's browser tools or `ui-evidence`. PR watching: the host's native watcher,
  else the skill's bounded polling. A blocked tool run is never a success.
