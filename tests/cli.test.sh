#!/usr/bin/env bash
# Behavioral tests for the wsl-cdp bash CLI: argument parsing, flag rejection,
# exit-code contract, detection seams, and machine (--json) output. Portable —
# no WSL interop required (detection is bypassed via WSL_CDP_WINUSER override).
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CLI="$WSL_CDP_BIN"

# --- help is success on stdout; a typo is an error (contract for capability probes)
out="$("$CLI" --help)"; rc=$?
assert_eq "--help exits 0" 0 "$rc"
assert_contains "--help prints usage" "$out" "usage: wsl-cdp"
assert_exit "help subcommand exits 0" 0 "$CLI" help
assert_exit "unknown command -> 2" 2 "$CLI" frobnicate

# --- unknown flags / stray args are rejected loudly, never silently swallowed
assert_exit "status --xml -> 2" 2 "$CLI" status --xml
assert_exit "tabs --verbose -> 2" 2 "$CLI" tabs --verbose
assert_exit "doctor positional -> 2" 2 "$CLI" doctor stray
assert_exit "up extra arg -> 2" 2 "$CLI" up extra
assert_exit "url extra arg -> 2" 2 "$CLI" url extra

# --- ports are validated numeric before they reach any URL / jq program / pgrep
assert_exit "PORT=abc -> 2" 2 env WSL_CDP_PORT=abc "$CLI" url
assert_exit "PROXY_PORT=9x -> 2" 2 env WSL_CDP_PROXY_PORT=9x "$CLI" url

# --- url honors the port
u="$(WSL_CDP_PORT=9333 "$CLI" url)"
assert_eq "url reflects PORT" "http://127.0.0.1:9333" "$u"

# --- required args are validated (exit 2) BEFORE any network call
assert_exit "open (no URL) -> 2" 2 "$CLI" open
assert_exit "close (no ID) -> 2" 2 "$CLI" close
assert_exit "eval (no JS) -> 2" 2 "$CLI" eval

# --- close tab-id is validated: path traversal / shell metacharacters rejected
assert_exit "close ../etc/passwd -> 2" 2 "$CLI" close '../etc/passwd'
assert_exit "close 'zzz;rm' -> 2" 2 "$CLI" close 'zzz;rm'

# --- detection seam: print-launch under a fixture root, no interop, and the
#     debug port + dedicated profile are emitted as an inseparable unit
fx="$(make_fixture)"; brave="$(fixture_brave "$fx")"
argv="$(WSL_CDP_USERS_ROOT="$fx/users" WSL_CDP_WINUSER=testuser \
        WSL_CDP_BROWSER="$brave" WSL_CDP_PORT=9333 HOME="$fx/home" \
        "$CLI" print-launch)"; rc=$?
assert_eq "print-launch exits 0" 0 "$rc"
assert_contains "print-launch carries the debug port" "$argv" "--remote-debugging-port=9333"
assert_contains "print-launch pairs the dedicated profile" "$argv" 'user-data-dir=C:\Users\testuser\.wsl-cdp\profile'

# --- launch argv suppresses updater/background churn (v0.3.1: a fresh agent
#     profile must not kick off update checks; Brave's relaunch loop)
assert_contains "argv disables background networking" "$argv" "--disable-background-networking"
assert_contains "argv disables the Brave updater" "$argv" "--disable-brave-update"
assert_contains "argv stretches the component-update interval" "$argv" "--component-update-interval-in-sec="

# --- autodetect order: Chrome > Edge > Brave (v0.3.1: Brave last — its updater
#     contends with a daily-driver Brave over the shared versioned install)
detect_argv(){ WSL_CDP_USERS_ROOT="$fx/users" WSL_CDP_WINUSER=testuser \
  WSL_CDP_PROGRAMFILES="$fx/pf" WSL_CDP_PROGRAMFILES_X86="$fx/pf86" \
  HOME="$fx/home" "$CLI" print-launch 2>/dev/null; }
assert_contains "autodetect prefers Chrome when all three exist" "$(detect_argv)" "chrome.exe"
rm "$(fixture_chrome "$fx")"
assert_contains "autodetect falls back to Edge without Chrome" "$(detect_argv)" "msedge.exe"
rm "$(fixture_edge "$fx")"
assert_contains "autodetect falls back to Brave last" "$(detect_argv)" "brave.exe"

# --- a WSL_CDP_WINUSER override must NOT persist into the winuser cache
h="$fx/home2"
WSL_CDP_USERS_ROOT="$fx/users" WSL_CDP_WINUSER=testuser \
  WSL_CDP_BROWSER="$brave" WSL_CDP_PORT=9333 HOME="$h" \
  "$CLI" print-launch >/dev/null 2>&1
if [ -f "$h/.local/state/wsl-cdp/winuser" ]; then
  _no "override poisoned the winuser cache"
else
  _ok "override leaves the winuser cache unwritten"
fi

# --- status --json: valid JSON, documented shape, ok:false when the chain is down
sj="$(WSL_CDP_PORT=9333 WSL_CDP_PROXY_PORT=9334 "$CLI" status --json 2>/dev/null)"
if printf '%s' "$sj" | jq -e '.ok==false and (.exit|type=="number") and (.checks|length==3) and (.checks[0]|has("status") and has("name") and has("detail"))' >/dev/null 2>&1; then
  _ok "status --json is valid and well-shaped"
else
  _no "status --json shape wrong: $sj"
fi

t_summary
