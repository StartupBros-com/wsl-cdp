# Changelog

All notable changes to wsl-cdp. Format follows [Keep a Changelog](https://keepachangelog.com/); versions are [GitHub releases](https://github.com/StartupBros-com/wsl-cdp/releases).

## [0.3.3] — 2026-08-08

**Enforced profile hygiene: the agent profile keeps sessions, never passwords.**

- Every `up` launch seeds the agent profile's `Preferences` so the save-password bubble, credential auto-signin, and "sign in to Chrome" never render — per-profile, so your daily browser is untouched (deliberately not Windows policy registry keys, which are machine-wide). Launches with `--disable-sync`.
- Saved passwords that slip in anyway are scrubbed automatically at the next launch, with a counted notice. Password stores (`Login Data`) are separate SQLite files from `Cookies`, so sessions survive the scrub.
- New `harden` verb applies the same on demand, with honest exit codes and a guard that refuses only when the Windows-side browser is actually serving.
- `doctor` gains a `profile-hygiene` row; `doctor --json` gains `env.profile.saved_passwords`. Hygiene applies at launch — `up` and `doctor` warn when a scrub is pending behind an open window.
- Every load-bearing claim (pref names, policy→pref mappings, prefs merge-on-first-run, `logins` table name, cookie separation, journal mode) verified against chromium source.

## [0.3.2] — 2026-08-08

**Explicit browser choice at setup.**

- New `browsers [--json]` verb: installed browsers in autodetect rank order, flagged `recommended` / `running` / `recorded`, plus which one `up` would use (`selected` + `source`). `running` is honest tri-state (`null` when Windows interop is down, never assumed false).
- `/wsl-cdp:setup` now asks one single-select question on multi-browser machines (recommended first, honest trade-offs), never re-asks once the profile is bound, and warns when the only choice is a running Brave.
- No silent choice-discard: `up` over an already-live bridge says loudly when `WSL_CDP_BROWSER` was set but nothing was (re)launched or recorded.
- Fixed: an interop call inside the enumeration loop drained stdin and truncated the browser list to one row.

## [0.3.1] — 2026-08-08

**Chrome-first defaults + profile-browser affinity.**

- Autodetect reordered to Chrome (system, user) → Edge (x86, 64-bit) → Brave (user, system). Brave moved last because its updater stages a versioned-install swap that cannot complete while any `brave.exe` runs — an agent instance launched beside a daily-driver Brave relaunch-loops on "update pending". Chrome/Edge are different installs and cannot contend.
- Profile-browser affinity: `up` records which browser launched the agent profile and keeps using it, so an autodetect reorder can never silently reopen your logged-in profile with a different vendor. `WSL_CDP_BROWSER` overrides; stale records fall back.
- Updater-suppression launch flags (source-verified): `--disable-background-networking`, `--component-update-interval-in-sec=31536000`, `--check-for-update-interval=31536000`.
- README: Brave update-loop troubleshooting (mechanism + unstick steps).

## [0.3.0] — 2026-08-08

**Hardening + the first behavioral test suite.**

- 19 defects fixed from an adversarial review pass, including: TOCTOU-free `setup-windows` (script body passed inline via `-EncodedCommand`, no swappable staged file), relay half-close handling (large reverse streams / screenshots no longer truncated), driver `ws.onclose` rejects pending calls (no 20 s hang), control-character stripping on untrusted page text, port and tab-id validation, idempotent `up`.
- `--json` machine output for `status` / `doctor` / `tabs`; documented exit-code contract.
- `doctor` warns when co-resident WSL distros share the loopback namespace (the debug port has no auth).
- Behavioral test suite (`tests/run.sh`) + CI job.

## [0.2.2] — 2026-08-08

- TCP probes outrank `netsh` output and process identity in health checks: a working chain served by a sibling relay (or mirrored-mode loopback) is reported healthy; interop flakiness is retried instead of misread as "rule missing".

## [0.2.1] — 2026-08-08

- Windows-username detection survives interop outages: cmd/powershell first, then the WSL-username mirror, then freshest profile heuristics. Lazy resolution — read-only verbs keep working when interop is down.

## [0.2.0] — 2026-08-08

- Claude Code plugin: skill + guided `/wsl-cdp:setup` command, local-mode installer, listed on the [House of Vibe marketplace](https://github.com/StartupBros-com/hov-marketplace).

## [0.1.0] — 2026-08-08

- Initial release: the WSL2 → Windows browser CDP bridge (relay + portproxy + dedicated profile), `up`/`down`/`status`/`doctor`/`tabs`/`open`/`close`/`eval`/`text`/`screenshot`/`print-launch`/`setup-windows`/`mcp-add`, one-time elevated Windows setup, `curl | bash` installer.
