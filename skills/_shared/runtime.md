# Runtime

Read once per session when using an `/ansh` skill. It maps the skills onto whatever host runs
them (Claude Code, Cursor, Codex, T3). [Autonomy](autonomy.md) still decides what needs me (nothing
during a run).

## Loading and paths

- Claude Code and Cursor invoke `/ansh-plan`; Codex uses `$ansh-plan`. A plain request naming the skill works.
- Use the host's skill loader. Otherwise read the named `SKILL.md` from the installed skills root.
- Resolve sibling skills, `_shared/` and `ANSH*.md` relative to that root (follow symlinks). Don't
  assume `~/.claude`.
- Claude uses `~/.claude/skills`, Cursor `~/.cursor/skills`, and Codex `~/.agents/skills`.
  `setup.sh` installs the same catalog and shared references for all three.
- The `agents/` files are portable reviewer prompts. Claude also registers them as native agents;
  other hosts can read them through `ANSH-agents/` in the skills root and pass the prompt to their
  own delegation tool. Claude agent metadata does not require a Claude model or tool.
- Read only the dependencies the current phase needs.

## Tools

- Map Bash/Read/Edit/Write/Grep/Glob to the host's shell, file and search tools.
- Map Agent/Task/Workflow to whatever delegation exists. With none, run roles serially in-session.
- Tool names like `mcp__claude_ai_Linear__get_issue` or `mcp__vitalize__buildkite_*` name a
  capability. Find the connected equivalent and read its real schema.
- Prefer existing authenticated CLIs (`gh`, `bk`, `signoz`, see `_shared/cli-tools.md`). Never print
  credentials or connect a new service to satisfy an example.
- A missing ticket update is skipped with a note. Missing ticket content or CI logs that the work
  depends on: report BLOCKED with what's missing. Never fabricate it or mark an unchecked gate green.
- Track progress with the host's todo tool, or a small `.ansh/progress.md` when there isn't one.

## Models (Sonnet and Opus workers, Fable/Astra advisors)

| Work | Model | Effort |
|---|---|---|
| Routine implementation, exploration, orchestration and task-role fan-out | Claude Sonnet or `gpt-6.1-sol` | medium; high when needed |
| Demanding implementation, planning, review and hard debugging | Claude Opus; `gpt-6.1-sol` on OpenAI | high when needed |
| Advisor help for a genuinely challenging unresolved question | Fable or Astra through the host's advisor mechanism only | scoped to the question |

- Sonnet and Opus handle the bulk of Claude work. Use Sonnet for routine, bounded tasks and
  Opus when the task needs deeper judgment; Opus is a worker model, not advisor-only. GPT Sol
  remains the OpenAI worker. Choose each child's model explicitly from its own task rather
  than inheriting an expensive parent's model across all fan-out.
- Haiku/Luna are not part of normal routing. Use scripts for tiny deterministic chores where
  practical; otherwise keep the work on Sonnet/Sol. Do not create small-model subagents just
  to offload a trivial step. Use Haiku/Luna only when the user explicitly requests them.
- Give task children a clear scope, acceptance criteria and runnable checks; require evidence
  before accepting their results. A role name or Deep stamp alone does not justify escalation.
- Fable/Astra are advisor-only. Never select them as the primary session model, task worker,
  planner, orchestrator, reviewer or standalone delegated agent. For genuinely challenging
  unresolved questions, the Sonnet/Opus/Sol owner may seek focused help through an available
  host advisor mechanism, then verify the advice and own the decision. Routine uncertainty
  does not warrant an advisor call. If no advisor mechanism is available, continue on an
  allowed worker and surface unresolved uncertainty; do not launch a Fable/Astra child instead.
- Preserve model choices explicitly requested by the user. Old packet stamps and inherited
  defaults do not override this policy: `economy`/`sonnet` means Sonnet or Sol;
  `reasoning`/`opus` means Opus or Sol. Replace Fable/Astra worker stamps with an allowed worker,
  retaining the required checks and review depth. This policy does not change the PR gate's
  lenses or merge requirements.
- Refresh the live model catalog before dispatch. If the preferred worker is unavailable,
  choose an available Sonnet, Opus or Sol appropriate to the task and disclose the fallback.
  Do not fall back to Fable/Astra workers. Never claim a switch the host didn't make.
- On T3, prefer the Codex provider instance for OpenAI models; native Sonnet and Opus task
  children are also allowed. Use native delegation when it supports the chosen model and
  `delegate_task` for cross-provider or worktree-isolated work. A Claude parent may run Sol
  children that way.

## Independent review

- Use a fresh-context Sonnet, Opus or Sol reviewer suited to the change. Prefer a different
  worker model from the author when available; otherwise use a fresh context on the same model.
  Fable/Astra advisor output does not replace the independent review or its verification.
- Give the reviewer the intent, criteria, diff or plan path, standards and read-only scope. Not the
  author's reasoning. Forbid it from delegating or re-entering the loop.
- On Claude or Cursor, the `codex` skill works when Codex is installed and authenticated. A second Codex process on a
  Codex host isn't cross-model. Cursor can use its native subagents or an authenticated external
  reviewer; discover capabilities rather than assuming Claude's Agent/Task API is available.
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
