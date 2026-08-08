# wsl-cdp

Let AI agents (Claude Code, Codex, cron jobs, plain scripts) running **inside WSL2** drive your **real, logged-in Windows browser** (Chrome, Edge, or Brave) over the Chrome DevTools Protocol.

```
WSL 127.0.0.1:9223 ──(local relay)──► WIN_IP:9224 ──(netsh portproxy)──► 127.0.0.1:9223 browser
                                                                          (dedicated agent profile)
```

```bash
wsl-cdp setup-windows   # once, elevated (UAC): portproxy + scoped firewall rule
wsl-cdp up              # launches the browser (agent profile) + the relay, verifies end-to-end
wsl-cdp open https://github.com/notifications
wsl-cdp text            # read the page as the agent sees it
wsl-cdp screenshot      # PNG through the agent's eyes
```

Log the agent profile into a site once; sessions persist across restarts and reboots.

> [!WARNING]
> **A CDP debug port is full control of that browser profile.** Any process that can reach `127.0.0.1:9223` (and any process on Windows that can reach the browser's loopback port) can read and act as every account that profile is logged into. wsl-cdp mitigates by design: the browser only ever listens on loopback, the portproxy is closed to the LAN by a firewall rule scoped to the WSL NAT range, and everything runs in a **dedicated profile**. The mitigation that matters most is still yours: **log the agent profile into only what agents should touch. Never your primary profile, never banking, never anything with irreversible sends.** If you point agents at pages you don't control, treat page content as untrusted input (prompt injection against an authenticated session is the live threat model).
>
> **On a multi-distro machine, "loopback" is shared.** Every WSL2 distro shares one network namespace ([microsoft/WSL#4304](https://github.com/microsoft/WSL/issues/4304), by design), so a process in a *different* distro can reach `127.0.0.1:9223` too — the relay is byte-blind and does not authenticate. The Windows firewall does not isolate co-resident distros, and its NAT-range scope (`172.16.0.0/12`) also admits Docker networks and other hosts in that range. If you run untrusted code in another distro or a container, that is the boundary to think about. `wsl-cdp doctor` warns when it sees other distros installed.

## Why this exists

Extension-based integrations (e.g. Claude in Chrome) pair the browser with the CLI over a **native messaging host**: the browser spawns the CLI as a child process. A Windows browser cannot spawn a process inside the WSL2 VM, so that architecture is structurally dead for WSL users. Claude Code additionally hard-gates it (*"Chrome integration isn't supported in WSL"*; see [anthropics/claude-code#41625](https://github.com/anthropics/claude-code/issues/41625), closed not-planned, and [#23907](https://github.com/anthropics/claude-code/issues/23907)). The pain is well documented: an [open chrome-devtools-mcp issue](https://github.com/ChromeDevTools/chrome-devtools-mcp/issues/405) for WSL2, multiple recipe blog posts, unanswered HN questions.

The working practitioner path is raw CDP into a dedicated, persistently-logged-in profile. wsl-cdp packages that path so it stops being folklore.

## What's actually hard (and handled)

Each of these is a silent failure if you wire the bridge by hand:

- **Chromium 136+ ignores `--remote-debugging-port` on the default profile.** The flag only works with a dedicated `--user-data-dir` ([announcement](https://developer.chrome.com/blog/remote-debugging-port)). Conveniently, the dedicated profile is also the security boundary you want.
- **`--remote-debugging-address` is gone.** The DevTools server binds loopback only, so WSL2 (NAT mode) cannot reach it without a Windows-side `netsh portproxy`.
- **DevTools echoes the request Host into `webSocketDebuggerUrl`.** Clients get `ws://127.0.0.1:9223/...`, which only resolves from WSL through a *same-port* local relay. This is why `wsl-cdp-forward.py` exists (byte-blind, so WebSocket upgrades and multi-MB screenshot frames pass through).
- **Stale portproxy rules self-loop.** A leftover rule on the browser's own port grabs `127.0.0.1:9223` first, pushing the browser to `[::1]` and looping IPv4 traffic into empty replies. `setup-windows` sweeps both ports before adding its one rule (idempotent: run twice, get one rule).
- **The WSL gateway IP changes across reboots.** `up` re-resolves it and restarts a stale relay automatically.
- **`--remote-allow-origins` is required** for cross-host WebSocket handshakes, a separate failure mode that looks like a network problem.
- **WSL interop is flaky.** `netsh.exe` can transiently return empty output with exit 0; wsl-cdp retries instead of misreading it as "rule missing".
- **Brave's updater fights a second instance of a shared install.** Brave's `Application\brave.exe` is a version stub; a background scheduled task (`BraveSoftwareUpdateTaskMachineUA`) stages updates into a new versioned directory that can only swap in once **no** `brave.exe` is running. Launch an agent instance while your daily Brave is open and the pending update relaunch-loops the new window — `--user-data-dir` isolates the profile, not the install. wsl-cdp therefore autodetects Chrome/Edge before Brave (a different install can't contend with your daily browser) and passes updater-suppression flags. If you pin Brave via `WSL_CDP_BROWSER` and hit the loop: close **every** Brave window, launch Brave once so the update completes, then `wsl-cdp up`.
- **Chromium profiles are not portable across vendors**, and the agent profile dir is browser-independent — so `up` records which browser first launched the profile (`%USERPROFILE%\.wsl-cdp\browser`) and keeps using it even if the autodetect order changes in a later release. Your logged-in sessions stay with the browser that created them. To switch vendors deliberately, set `WSL_CDP_BROWSER` (or delete that file) — and expect to log in again. Upgrading from ≤ v0.3.0, where Brave ranked first and nothing was recorded: your first v0.3.1 `up` autodetects fresh, so if you had a logged-in Brave agent profile, pin Brave with `WSL_CDP_BROWSER` before running `up`.

`wsl-cdp doctor` checks every link independently and names the first broken one with its exact remediation. A live relay is never allowed to mask a dead Windows side.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/StartupBros-com/wsl-cdp/main/install.sh | bash
```

Or clone and symlink `wsl-cdp` onto your PATH; the scripts resolve their siblings via their own location. Claude Code users can instead install the plugin (skill + guided `/wsl-cdp:setup`) from the [House of Vibe marketplace](https://github.com/StartupBros-com/hov-marketplace): `/plugin marketplace add StartupBros-com/hov-marketplace`, then `/plugin install wsl-cdp@hov`. Requirements: WSL2 (NAT networking), `jq`, `python3` (stdlib only), node ≥ 22 for the `eval`/`text`/`screenshot` verbs (built-in WebSocket; no npm installs).

## Commands

| Command | What it does |
|---|---|
| `up` / `down` | bring the chain up (self-healing) / stop the relay |
| `status [--json]` / `doctor [--json]` | per-link health, exit code = first broken link, remediation attached; `--json` emits `{ok, exit, checks:[…]}` for scripts |
| `tabs [--json]` / `open URL` / `close ID` | tab management (HTTP CDP endpoints) |
| `eval JS [TAB]` / `text [TAB]` / `screenshot [FILE] [TAB]` | page access over the WebSocket layer (needs node ≥ 22) |
| `print-launch` | show the exact browser command line (port + profile are emitted as a unit) |
| `setup-windows` | the one elevated step, once; idempotent |
| `mcp-add` | write a per-repo `.mcp.json` entry for `chrome-devtools-mcp --browserUrl=http://127.0.0.1:9223` |

`tabs` and `open` print tab-separated rows: `<id>\t<url>` (one page target per line) — pipe to `cut -f1` for ids, `cut -f2` for urls. `tabs --json` gives `[{id, url}, …]` instead.

**Exit codes:** `0` ok · `1` chain/forwarder down (or a CDP call failed after the chain proved healthy) · `2` usage error / invalid argument / unknown flag · `3` end-to-end check failed. Unknown flags and stray arguments are rejected loudly rather than ignored, so a wrong guess never returns a false success.

Environment: `WSL_CDP_PORT` (9223) · `WSL_CDP_PROXY_PORT` (9224) · `WSL_CDP_WINUSER` (autodetected) · `WSL_CDP_BROWSER` (autodetected: Chrome → Edge → Brave, Brave last because of the updater contention above; once a profile has been launched, its recorded browser outranks autodetection) · `WSL_CDP_USERS_ROOT` (`/mnt/c/Users`; override the Windows users root, mainly for tests).

## How it compares

Several tools touch this space. None has this shape:

| Tool | What it is | vs wsl-cdp |
|---|---|---|
| [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) | Google's official MCP server; generic `--browserUrl` attach | The best *driver* once a bridge exists, but it does not build the WSL2 bridge. Use both: `wsl-cdp mcp-add` wires it to this bridge. |
| [chrome-cdp-skill](https://github.com/pasky/chrome-cdp-skill) | Popular CDP verb CLI | Same-host only; no WSL awareness at all. If your agent and browser share an OS, use that. |
| [browser-ipc-cdp](https://github.com/alexis14kl/browser-ipc-cdp) | MCP server that automates the WSL portproxy/firewall | Real engineering (its dynamic-port design is clever; credit where due), but MCP-only distribution, no operator CLI, no doctor. |
| Claude in Chrome extension | Native-messaging pairing with your real profile | Structurally unavailable from WSL2; Chrome/Claude-only even where it works. |
| Recipe blogs / setup-script repos | The same chain, hand-rolled | Where this knowledge lived before; no health model, no idempotency, no stale-rule handling. |

## Limitations (read before relying on it)

- **NAT networking assumed** (the WSL2 default). Under `networkingMode=mirrored` you may not need the portproxy at all, but mirrored-mode loopback has [documented reliability issues](https://github.com/microsoft/WSL/issues/40343), which is why this bridge doesn't build on it.
- **Attended use is the sweet spot.** For sustained unattended automation, a Linux-side headless browser (Playwright in WSL) is more robust than any cross-VM bridge. Use this tool for what only a real logged-in browser can do.
- **Logins/2FA/CAPTCHA are yours.** By design. Sessions persist after you log in once; nothing here automates authentication walls (and per industry consensus, nothing else reliably does either).
- **Chromium vendors periodically harden CDP** (the 136 profile change broke this tool class industry-wide). Expect occasional breakage; `doctor` is built to localize it.

## License

MIT. Extracted from a personal agent harness where every design constant above was learned the verified-failure way.
