# Harness recipes

Adapt these to the current repo. Never hard-code ports, selectors or paths from another repo. Keep
one-off probes in `/tmp`.

## Playwright against a local URL

```javascript
import { chromium } from "playwright";

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on("console", (m) => console.log(`[console:${m.type()}] ${m.text()}`));
page.on("requestfailed", (r) => console.log(`[requestfailed] ${r.url()} ${r.failure()?.errorText}`));

await page.goto("http://127.0.0.1:<port>/<route>");
await page.getByRole("button", { name: /save/i }).click();
await page.getByText("Saved").waitFor();
await page.screenshot({ path: "<evidence>/after.png", fullPage: true });
await browser.close();
```

## Electron or a Chromium debug port (CDP)

```javascript
import { chromium } from "playwright";

const browser = await chromium.connectOverCDP("http://127.0.0.1:<debug-port>");
const pages = browser.contexts().flatMap((c) => c.pages());
let page;
for (const p of pages) {
  if (await p.locator("<app-root-marker>").count()) { page = p; break; }
}
if (!page) {
  console.log(await Promise.all(pages.map(async (p) => ({ title: await p.title(), url: p.url() }))));
  throw new Error("no matching app page");
}
await page.screenshot({ path: "<evidence>/cdp.png", fullPage: true });
await browser.close();
```

Raw CDP only when Playwright can't: CPU profiles and traces, heap snapshots with forced GC,
network throttling or blocking, color scheme and reduced-motion emulation.

## tmux for a CLI or TUI

```bash
SESSION="ansh-control-$(date +%s)"
tmux new-session -d -s "$SESSION" -x 120 -y 40 -- <command>
tmux capture-pane -pt "$SESSION"          # before
tmux send-keys -t "$SESSION" "help" Enter
until tmux capture-pane -pt "$SESSION" | grep -q "<expected prompt>"; do sleep 0.2; done
tmux capture-pane -pt "$SESSION"          # after
tmux kill-session -t "$SESSION"
```

Node CLIs: start with `NODE_OPTIONS="--inspect=127.0.0.1:0"` and read the inspector URL from the
screen when you need a profile.

## PTY probe (no tmux)

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

## HTTP API

```bash
curl -sS -o "<evidence>/resp.json" -w '%{http_code}\n' \
  -H "Authorization: Bearer $LOCAL_TEST_TOKEN" http://127.0.0.1:<port>/<path>
```

Save the command, status code and body. Use seeded local credentials only.

## Profiling

- Startup: base and head under the same machine, env and command, 3 runs each.
- Slow action: CPU profile around the action, compare top self-time functions.
- Leak: GC, heap snapshot, repeat the action, GC, snapshot again, diff.
- Hang: screen, active handles, stack or CPU sample, then interrupt.
