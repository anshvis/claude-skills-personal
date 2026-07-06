# ansh-personal skills

Private Claude Code plugin bundling my personal `/ansh-*` Karpathy-loop skills (orchestrator + plan/task/review/debug/resolve/save), the glue skills they call (effort-dial, chill-describe, gold-star, linear-sync, lightweight-sql), and web-handoff/web-read. `ANSH.md` is the loop index.

Private repo → visible only to me and my agents.

## Install (terminal or Claude Code Web)

```
/plugin marketplace add anshvis/claude-skills-personal
/plugin install ansh-personal@ansh-personal-skills
```

Skills are namespaced under the plugin, e.g. `/ansh-personal:ansh-loop`.

## Caveats
- Namespacing: skills that call each other by bare name (e.g. `/ansh-plan`) may need the `ansh-personal:` prefix.
- On Claude Code Web, plugin sub-agents and hooks are limited (fully supported in Desktop/Cowork), so the loop is degraded there.
- The loop's `.ansh/` scratch state is per-machine/sandbox and does not sync.
