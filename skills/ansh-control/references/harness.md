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

## Profiling

- Page load: base and head under the same machine, env and route, 3 runs each.
- Slow action: CPU profile around the action, compare top self-time functions.
- Leak: GC, heap snapshot, repeat the action, GC, snapshot again, diff.
- Hang: screenshot, console, CPU sample, then interrupt.
