# Backend recipes

Adapt these to the current repo. Never hard-code ports, paths or configs from another repo. Keep
one-off probes in `/tmp`. Run anything that needs secrets under the config from
[`/ansh-backend`](../SKILL.md#secrets-and-config), e.g. `vitalize run -c local -- <cmd>`.

## HTTP API

```bash
curl -sS -o "<evidence>/resp.json" -w 'status=%{http_code} time=%{time_total}\n' \
  -H "Authorization: Bearer $LOCAL_TEST_TOKEN" http://127.0.0.1:<port>/<path>
```

Save the command with the token redacted, the status, the body and the timing. Seeded local
credentials only. Prefer the repo's own client or RPC test helper when one exists: it carries the
real auth and schema.

## DB, read-only

```bash
vitalize run -c local -- psql "$DATABASE_URL" -c 'SELECT id, status FROM <table> WHERE id = $1'
pscale shell <db> <branch>          # PlanetScale branch databases
```

Select only the columns and rows the check names. Run the same query before and after the action.

## CLI or TUI

```bash
SESSION="ansh-backend-$(date +%s)"
tmux new-session -d -s "$SESSION" -x 120 -y 40 -- <command>
tmux capture-pane -pt "$SESSION"          # before
tmux send-keys -t "$SESSION" "help" Enter
until tmux capture-pane -pt "$SESSION" | grep -q "<expected prompt>"; do sleep 0.2; done
tmux capture-pane -pt "$SESSION"          # after
tmux kill-session -t "$SESSION"
```

A plain command: save the command, exit code, stdout and stderr. Node CLIs: start with
`NODE_OPTIONS="--inspect=127.0.0.1:0"` and read the inspector URL when you need a profile.

No tmux: a PTY probe.

```python
import os, pty, select, subprocess, time

master, slave = pty.openpty()
proc = subprocess.Popen(["<command>", "<arg>"], stdin=slave, stdout=slave, stderr=slave, close_fds=True)
os.close(slave)
buf, deadline = b"", time.time() + 30
while time.time() < deadline:
    ready, _, _ = select.select([master], [], [], 0.25)
    if ready:
        buf += os.read(master, 4096)
        if b"<ready text>" in buf:
            os.write(master, b"help\n")
            break
print(buf.decode(errors="replace"))
proc.terminate(); os.close(master)
```

## CI for the head SHA

```bash
gh pr checks <n> --json name,state,bucket,link             # which checks, which system
bk build view <number> -p <pipeline>                       # buildkite/* step states
bk build view <number> -p <pipeline> --log                 # the failing step's log
gh run view <run-id> --log-failed                          # GitHub Actions
```

Compare the build's commit with the head SHA before reading anything into it.
