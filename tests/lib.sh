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

# Build a throwaway Windows fixture tree with fake (executable) browsers at
# EVERY path detect_browser() probes, so the full detection order is testable
# with no real C: drive and no WSL interop. Echoes the fixture root; caller
# wires WSL_CDP_USERS_ROOT="$root/users" (+ WSL_CDP_PROGRAMFILES{,_X86}=
# "$root/pf{,86}" for autodetect tests, or WSL_CDP_BROWSER to bypass detection).
# fixture_rank echoes the browser paths in the exact order detect_browser()
# documents, so tests can assert the waterfall by deleting winners one at a time.
make_fixture(){
  local d p
  d="$(mktemp -d "${TMPDIR:-/tmp}/wslcdp-fix.XXXXXX")"
  mkdir -p "$d/users/testuser/AppData/Local/Temp" "$d/home" "$d/home2"
  while IFS= read -r p; do
    mkdir -p "${p%/*}"; touch "$p"; chmod +x "$p"
  done < <(fixture_rank "$d")
  printf '%s' "$d"
}
fixture_rank(){
  printf '%s\n' \
    "$1/pf/Google/Chrome/Application/chrome.exe" \
    "$1/users/testuser/AppData/Local/Google/Chrome/Application/chrome.exe" \
    "$1/pf86/Microsoft/Edge/Application/msedge.exe" \
    "$1/pf/Microsoft/Edge/Application/msedge.exe" \
    "$1/users/testuser/AppData/Local/BraveSoftware/Brave-Browser/Application/brave.exe" \
    "$1/pf/BraveSoftware/Brave-Browser/Application/brave.exe"
}
fixture_brave(){ printf '%s' "$1/users/testuser/AppData/Local/BraveSoftware/Brave-Browser/Application/brave.exe"; }
fixture_chrome(){ printf '%s' "$1/pf/Google/Chrome/Application/chrome.exe"; }
