#!/usr/bin/env node
// wsl-cdp-drive: WebSocket-layer CDP verbs for the wsl-cdp bridge.
// Needs node >= 22 (global WebSocket + fetch). No npm dependencies.
//
//   eval <js> [tabId]         Runtime.evaluate, returnByValue, prints the value as JSON
//   text [tabId]              document.body.innerText of the tab
//   screenshot <file> [tabId] Page.captureScreenshot (png) written to <file>
//
// Tab selection: explicit tabId, else the first "page" target.
const PORT = process.env.WSL_CDP_PORT || "9223";
const BASE = `http://127.0.0.1:${PORT}`;
const TIMEOUT_MS = 20000;

async function target(tabId) {
  const list = await (await fetch(`${BASE}/json/list`)).json();
  const t = tabId
    ? list.find((x) => x.id === tabId)
    : list.find((x) => x.type === "page");
  if (!t) throw new Error(tabId ? `no tab ${tabId}` : "no page targets (wsl-cdp open URL first)");
  return t;
}

function connect(wsUrl) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const pending = new Map();
    let nextId = 1;
    ws.onopen = () =>
      resolve({
        send(method, params = {}) {
          const id = nextId++;
          return new Promise((res, rej) => {
            pending.set(id, { res, rej });
            ws.send(JSON.stringify({ id, method, params }));
            setTimeout(() => {
              if (pending.delete(id)) rej(new Error(`${method} timed out after ${TIMEOUT_MS}ms`));
            }, TIMEOUT_MS);
          });
        },
        close: () => ws.close(),
      });
    ws.onerror = () => reject(new Error(`websocket connect failed: ${wsUrl}`));
    ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && pending.has(msg.id)) {
        const { res, rej } = pending.get(msg.id);
        pending.delete(msg.id);
        msg.error ? rej(new Error(msg.error.message)) : res(msg.result);
      }
    };
  });
}

async function evaluate(cdp, expression) {
  const r = await cdp.send("Runtime.evaluate", {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || "evaluation threw");
  return r.result.value;
}

const [cmd, a1, a2] = process.argv.slice(2);
try {
  if (cmd === "eval") {
    if (!a1) throw new Error("usage: wsl-cdp-drive eval <js> [tabId]");
    const t = await target(a2 || undefined);
    const cdp = await connect(t.webSocketDebuggerUrl);
    console.log(JSON.stringify(await evaluate(cdp, a1)));
    cdp.close();
  } else if (cmd === "text") {
    const t = await target(a1 || undefined);
    const cdp = await connect(t.webSocketDebuggerUrl);
    console.log(await evaluate(cdp, "document.body.innerText"));
    cdp.close();
  } else if (cmd === "screenshot") {
    if (!a1) throw new Error("usage: wsl-cdp-drive screenshot <file> [tabId]");
    const t = await target(a2 || undefined);
    const cdp = await connect(t.webSocketDebuggerUrl);
    const { data } = await cdp.send("Page.captureScreenshot", { format: "png" });
    const { writeFileSync } = await import("node:fs");
    const buf = Buffer.from(data, "base64");
    writeFileSync(a1, buf);
    console.log(`${a1} (${buf.length} bytes, tab ${t.id})`);
    cdp.close();
  } else {
    console.error("usage: wsl-cdp-drive <eval|text|screenshot> ...");
    process.exit(2);
  }
  process.exit(0);
} catch (e) {
  console.error(`wsl-cdp-drive: ${e.message}`);
  process.exit(1);
}
