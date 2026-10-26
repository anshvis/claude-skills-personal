# ansh-personal skills

Personal, provider-neutral skill sources: my `/ansh-*` skills, which take a ticket or TDD to a merged, verified PR without a human in the loop, the glue skills they call, and a few standalone helpers. `ANSH.md` is the index.

Private repo → visible only to me and my agents.

## Install for Claude Code and Codex

```bash
git clone https://github.com/anshvis/claude-skills-personal.git ~/claude-skills-personal
~/claude-skills-personal/setup.sh
```

Defaults to Claude and Codex. Claude keeps the complete existing skill catalog under
`~/.claude/skills/` and its agent definitions under `~/.claude/agents/`. Codex and local ChatGPT coding sessions get the complete skill catalog, including every
`ansh-*` skill and every helper/nested workflow, under `~/.agents/skills/`. Claude links directly to the sources. Codex links to a complete local mirror outside the
Claude plugin directory so names stay plain, such as `$ansh-plan`. The mirror includes
the full runtime guide, CLI references and reviewer prompts. Re-run setup after source
updates to refresh it.
Existing conflicting entries are backed up outside skill discovery under
`~/.local/state/ansh-skills/backups/`. Re-running setup keeps matching links unchanged.

```bash
./setup.sh --dry-run
./setup.sh --providers claude,codex,cursor  # optional Cursor install
./setup.sh --providers codex              # only Codex
```

Claude: `/ansh-plan <goal>`, `/ansh-task T1`, `/ansh-review`, `/ansh-save`.
Codex: `$ansh-plan <goal>`, `$ansh-task T1`,
`$ansh-review`, `$ansh-save`, or select the
skill in the picker. Newly installed skills appear on the next turn; start a new session
if the picker has cached an older catalog. The local ChatGPT desktop coding runtime uses
these filesystem skills too. ChatGPT web workspace Skills have a separate installation
lifecycle; this local setup does not upload or publish the private repository.

[Runtime compatibility](skills/_shared/runtime.md) defines capability-based tool/model routing,
independent review and execution when Workflow is absent. Model profiles are recommendations;
a skill never changes the current model by declaring a tier. Missing services or a required
fresh-review capability are reported explicitly. No hooks, tmux, `/meta`, provider defaults or
new service connections are installed by this setup.

## Install as a plugin (Claude Code Web)

```
/plugin marketplace add anshvis/claude-skills-personal
/plugin install ansh-personal@ansh-personal-skills
```

Skills are namespaced under the plugin, e.g. `/ansh-personal:ansh-loop`.

## Caveats
- The iteration ledger (`skills/_shared/ansh-log`) needs `jq`. Without it, events are skipped with a warning and nothing else breaks.
- Namespacing: skills that call each other by bare name (e.g. `/ansh-plan`) may need the `ansh-personal:` prefix.
- On Claude Code Web, plugin sub-agents and hooks are limited (fully supported in Desktop/Cowork), so the loop is degraded there.
- The loop's `.ansh/` scratch state is per-machine/sandbox and does not sync.
