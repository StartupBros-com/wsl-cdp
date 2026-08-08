#!/usr/bin/env bash
# Shared assertions + fixtures for wsl-cdp behavioral tests. Sourced by each
# tests/*.test.sh. Requires WSL_CDP_BIN (path to the wsl-cdp CLI).
#
# SAFETY: tests only ever exercise the DOWN paths on scratch ports (9333/9334)
# that nothing listens on. They NEVER invoke up/down/setup-windows/mcp-add and
# never mutate a live bridge, a firewall, or a portproxy rule.
set -uo pipefail

WSL_CDP_BIN="${WSL_CDP_BIN:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/wsl-cdp}"
export WSL_CDP_PORT="${WSL_CDP_TEST_PORT:-9333}"
export WSL_CDP_PROXY_PORT="${WSL_CDP_TEST_PROXY_PORT:-9334}"

_P=0 _F=0
_ok(){ _P=$((_P+1)); printf '  ok   %s\n' "$1"; }
_no(){ _F=$((_F+1)); printf '  FAIL %s\n' "$1"; }

assert_eq(){ # label expected actual
  [ "$2" = "$3" ] && _ok "$1" || _no "$1 (expected [$2] got [$3])"
}
assert_exit(){ # label want-code cmd...
  local l="$1" w="$2"; shift 2
  "$@" >/dev/null 2>&1
  assert_eq "$l" "$w" "$?"
}
assert_contains(){ # label haystack needle
  case "$2" in *"$3"*) _ok "$1" ;; *) _no "$1 (missing [$3])" ;; esac
}

t_summary(){ printf -- '-- %s: %d passed, %d failed\n' "${0##*/}" "$_P" "$_F"; [ "$_F" -eq 0 ]; }

# Build a throwaway Windows-users fixture tree with a fake (executable) Brave, so
# detection is testable with no real C: drive and no WSL interop. Echoes the
# fixture root; caller wires WSL_CDP_USERS_ROOT="$root/users" + WSL_CDP_BROWSER.
make_fixture(){
  local d br
  d="$(mktemp -d "${TMPDIR:-/tmp}/wslcdp-fix.XXXXXX")"
  br="$d/users/testuser/AppData/Local/BraveSoftware/Brave-Browser/Application"
  mkdir -p "$d/users/testuser/AppData/Local/Temp" "$br" "$d/home" "$d/home2"
  touch "$br/brave.exe"; chmod +x "$br/brave.exe"
  printf '%s' "$d"
}
fixture_brave(){ printf '%s' "$1/users/testuser/AppData/Local/BraveSoftware/Brave-Browser/Application/brave.exe"; }
