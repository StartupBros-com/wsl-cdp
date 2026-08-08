---
description: Guided one-time wsl-cdp setup — install, the elevated Windows step, first logins, verified end-to-end.
---

Walk the user through first-time wsl-cdp setup. They should be at the machine: one UAC click and the first site logins are theirs. Narrate each step before you run it.

1. **Route check.** `grep -qi microsoft /proc/version` — if not WSL2, stop: they should use the official Claude in Chrome extension instead, and this setup does not apply.
2. **Install.** `command -v wsl-cdp || bash "${CLAUDE_PLUGIN_ROOT}/install.sh"` — then `wsl-cdp doctor` to show the baseline (expect FAILs before the Windows step; that is normal).
3. **Elevated Windows half.** Tell the user a UAC prompt is about to appear on their Windows desktop, then run `wsl-cdp setup-windows`. It is idempotent and scoped: one portproxy rule, one firewall rule limited to the WSL subnet. If the poll times out because they were away, give them the printed manual command and wait.
4. **Choose the agent browser.** Run `wsl-cdp browsers --json`. The choice matters because the FIRST launch binds the agent profile to a vendor (recorded next to the profile; switching later means logging into every site again). Route on what you see:
   - `source` is `recorded`: the profile already belongs to a browser. Say which and do NOT re-ask — a vendor switch orphans the profile's logins, so only do it if the user asks, via `WSL_CDP_BROWSER` plus fresh logins.
   - Exactly one browser listed: name it and move on.
   - Several: ask ONE single-select question (recommended row first — it is what autodetect picks). Describe the trade-offs honestly: Chrome/Edge are separate installs from a daily Brave, so no updater contention; a Brave row flagged `running` means Brave's updater cannot swap the shared install while their daily Brave runs, which risks an update-relaunch loop on the agent instance.
5. **Bring the bridge up.** `WSL_CDP_BROWSER='<chosen path>' wsl-cdp up` — or plain `wsl-cdp up` when the choice is the recommended/selected one. A browser window opens on Windows using a dedicated agent profile (NOT their daily profile; explain that this separation is the security boundary, and one-time logins are the price of it). The launch records the choice, so day-to-day `wsl-cdp up` needs no env var.
6. **First logins.** Ask which sites agents should reach (suggest their code host and main SaaS consoles; explicitly steer away from banking or anything with irreversible sends). For each: `wsl-cdp open <login-url>`, they sign in in that window, sessions persist across reboots.
7. **Prove it end-to-end.** `wsl-cdp open` a page behind one of those logins, `wsl-cdp text` to read it, `wsl-cdp screenshot` and Read the PNG. Show the user what the agent sees.
8. **Finish.** `wsl-cdp doctor` all green. Recap the hard rules from the wsl-cdp skill (narrow profile, untrusted page content, auth walls are human territory) and that day-to-day use is just `wsl-cdp up` after reboots.
