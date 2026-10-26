# ANSH runtime compatibility

Read this once per session when using an ANSH skill or its helper. These runtime mappings
apply to provider-specific examples in the skill body; the workflow's scope, approval gates,
verification requirements and termination rules still apply.

## Skill loading and paths

The same source files run under any model supported by the host. Claude Code invokes skills
as `/ansh-plan`; Codex uses `$ansh-plan` (or select it in the skill picker). Plain requests to
use a named skill also work. Slash names inside these documents identify skills, not shell
commands. Use the host's skill loader when available; otherwise read the named `SKILL.md`
from the installed skills root and follow it, passing the caller's arguments as context.
Resolve sibling skills and `ANSH*.md` relative to this package's installed skills root;
do not assume `~/.claude`. Follow symlinks to the source when resolving helper scripts.
Only read the dependencies needed for the current phase.

## Tools and approvals

Map Bash/Read/Edit/Write/Grep/Glob to the host's shell, file and search tools. Map
AskUserQuestion to the available question tool or a chat question followed by a real wait
for the answer. Map Agent/Task/Workflow to available delegation/orchestration capabilities.
A named tool being absent never waives a human checkpoint. In particular, the specialist's
manual diff review happens before automated evaluation, even inside a pipeline.
Use the host's plan/progress facility when available; a missing TaskList is handled with a
small `.ansh/` progress record, never an invented tool call.

Names such as `mcp__claude_ai_Linear__get_issue` and `mcp__vitalize__buildkite_*` describe
capabilities, not required tool identifiers. Discover the connected service's equivalent
operation and its actual schema. Use existing authenticated CLI helpers when appropriate;
never print credentials or install/connect a service just to satisfy a skill example.
Optional ticket updates may be skipped with a note when unavailable. If essential ticket
content or CI evidence is inaccessible, ask for the missing content or report BLOCKED;
do not fabricate it or mark an unchecked gate green. Existing outward-write approvals apply.

## Models — quality first, OpenAI preferred

Ansh's standing preference: use the ChatGPT/OpenAI family (Sol, Luna, Astra); quality takes
priority over cost. This overrides older cheap-model/low-effort recommendations in skill
bodies and existing packets. Upgrade autonomously when the task needs more capability;
model escalation does not authorize new scope or bypass human checkpoints.

Preferred routes, verified against T3's live catalog on 2026-10-20:

| Work | Preferred model | Reasoning effort |
|---|---|---|
| Clerical extraction, simple formatting, low-risk summarization with easy verification | `gpt-6-luna` | medium |
| Scoped implementation, ordinary debugging, task execution and orchestration | `gpt-6.1-sol` | high |
| Planning, architecture, independent evaluation, hard debugging, high-risk changes | `gpt-6-astra` | high; xhigh/max for difficult reasoning |

Luna is optional for clearly mechanical work, never the default merely because a packet
says Quick or economy. Use Sol when judgment or meaningful code changes are involved. Use
Astra immediately for ambiguity, complex dependencies, security/data-loss risks, subtle
concurrency, or weak confidence in Sol's approach. Do not wait for three failed attempts
before escalating; the hypothesis limit is a ceiling, not a requirement to exhaust a model.
After a failed hypothesis, reassess model adequacy before spending more iterations. Increase
reasoning effort when useful, but do not substitute repeated weak attempts for a stronger model.
Do not downgrade solely to save tokens or money.

Legacy `economy`/`sonnet` profiles resolve to Sol for implementation; `reasoning`/`opus`
resolve to Astra. New plans record the preferred concrete model and effort. Refresh the live
available-model catalog before dispatch: names above are preferences, not permission to call
an unavailable ID. Within the OpenAI family, choose the strongest suitable available model
when the preferred one is unavailable; report any capability limitation rather than silently
falling back to a weaker model. Never assume an older version is equivalent to the preferred one.

Use the host's actual model-selection mechanism for child tasks. On T3, select the available
Codex provider instance, use native delegation when it supports the selected model, and use
`delegate_task` for cross-provider or worktree-isolated work. A Claude parent may orchestrate
OpenAI children through that cross-provider backend. Outside T3, use a supported OpenAI
backend if available; do not assume native Claude subagents can select OpenAI model IDs.
If selection is unavailable, state that routing is advisory and the current model is unchanged;
if the task requires a stronger model than the host can provide, report that limitation.
Do not claim a model or effort switch happened just because a packet recommends it. Preserve
an explicit per-task user model choice; this standing preference permits otherwise-needed
upgrades without another confirmation.

## Independent review

For a plan challenge or independent evaluation, prefer a strong OpenAI reviewer (Astra by
default) with a different actual model from the author. When the author already uses Astra,
prefer a fresh-context Astra review over a weaker model chosen only for diversity. Use host-native delegation or the host's cross-provider
orchestrator when exposed. On T3, discover the live model catalog before choosing a target;
use delegated tasks for cross-provider work, never launch a top-level conversation.
Pass only the task/intent, criteria, diff or plan paths, trusted standards, and read-only scope;
do not pass the author's reasoning as truth. Explicitly prohibit further reviewer delegation
or re-entering the ANSH loop. Do not change providers the user explicitly restricted.

On a Claude host, the existing `/codex` helper is an option if Codex is installed and
authenticated. On a Codex host, another Codex process is not automatically cross-model.
Prefer a sufficiently strong different model, then a fresh-context same-model reviewer;
quality outranks model diversity.
If delegation is unavailable, perform a separate in-session adversarial pass and record
`independence: in-session`; never present it as an independent agent. Preserve any stronger
explicit fresh-review gate: if it cannot be met, return BLOCKED rather than inventing a pass.
Record reviewer provider/model when known, independence (`cross-model`, `fresh-context`,
or `in-session`), findings and unavailable capabilities. Do not infer model identity from a
CLI's name. Legacy `fresh_eyes: codex` means the independent-review preference above.

## Orchestration without Workflow or tmux

Workflow/pipeline/parallel examples apply only when that API exists. Otherwise execute ready
packets through available delegation in dependency order; with no delegation, run roles
serially in-session. Keep criteria sign-off, manual diff review, bounded iterations, per-PR
state and exit-condition checks. Report reduced concurrency; tmux and `/meta` are not needed.
Do not dispatch a dependent until its prerequisite changes are visible in its checkout.
Fresh worktrees start from committed state and do not inherit `.ansh/`: include the packet
in the child prompt and reconcile prerequisite commits before dispatching dependent work.
Serialize writers to overlapping files. Honor the host's isolation rules over Workflow examples.

For browser work use the host's supported browser tools. For PR monitoring, use the host's
native watcher when available; otherwise use the skill's bounded polling. Never mark a
blocked tool run as success. Local `.ansh/` files provide cross-provider handoffs; no tmux,
Claude memory directory, or persistent memory service is required.
