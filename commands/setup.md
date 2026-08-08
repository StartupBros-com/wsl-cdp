---
description: Guided one-time wsl-cdp setup — install, the elevated Windows step, first logins, verified end-to-end.
---

Walk the user through first-time wsl-cdp setup. They should be at the machine: one UAC click and the first site logins are theirs. Narrate each step before you run it.

1. **Route check.** `grep -qi microsoft /proc/version` — if not WSL2, stop: they should use the official Claude in Chrome extension instead, and this setup does not apply.
2. **Install.** `command -v wsl-cdp || bash "${CLAUDE_PLUGIN_ROOT}/install.sh"` — then `wsl-cdp doctor` to show the baseline (expect FAILs before the Windows step; that is normal).
3. **Elevated Windows half.** Tell the user a UAC prompt is about to appear on their Windows desktop, then run `wsl-cdp setup-windows`. It is idempotent and scoped: one portproxy rule, one firewall rule limited to the WSL subnet. If the poll times out because they were away, give them the printed manual command and wait.
4. **Bring the bridge up.** `wsl-cdp up` — a browser window opens on Windows using a dedicated agent profile (NOT their daily profile; explain that this separation is the security boundary, and one-time logins are the price of it).
5. **First logins.** Ask which sites agents should reach (suggest their code host and main SaaS consoles; explicitly steer away from banking or anything with irreversible sends). For each: `wsl-cdp open <login-url>`, they sign in in that window, sessions persist across reboots.
6. **Prove it end-to-end.** `wsl-cdp open` a page behind one of those logins, `wsl-cdp text` to read it, `wsl-cdp screenshot` and Read the PNG. Show the user what the agent sees.
7. **Finish.** `wsl-cdp doctor` all green. Recap the hard rules from the wsl-cdp skill (narrow profile, untrusted page content, auth walls are human territory) and that day-to-day use is just `wsl-cdp up` after reboots.
