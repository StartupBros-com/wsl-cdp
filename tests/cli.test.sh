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

# --- launch argv suppresses in-process updater/background churn (v0.3.1:
#     a fresh agent profile must not kick off update churn; Brave relaunch loop)
assert_contains "argv disables background networking" "$argv" "--disable-background-networking"
assert_contains "argv stretches the component-update interval" "$argv" "--component-update-interval-in-sec="
assert_contains "argv stretches the staged-update poll" "$argv" "--check-for-update-interval="

# --- profile-browser affinity: the browser recorded next to the profile
#     outranks autodetect (v0.3.1: an autodetect reorder must never reopen an
#     existing profile with a different vendor); a stale record falls through
detect_argv(){ WSL_CDP_USERS_ROOT="$fx/users" WSL_CDP_WINUSER=testuser \
  WSL_CDP_PROGRAMFILES="$fx/pf" WSL_CDP_PROGRAMFILES_X86="$fx/pf86" \
  HOME="$fx/home" "$CLI" print-launch 2>/dev/null; }
mkdir -p "$fx/users/testuser/.wsl-cdp"
printf '%s' "$(fixture_brave "$fx")" >"$fx/users/testuser/.wsl-cdp/browser"
assert_contains "recorded profile browser outranks autodetect" "$(detect_argv)" "BraveSoftware"
printf '%s' "$fx/uninstalled.exe" >"$fx/users/testuser/.wsl-cdp/browser"
assert_contains "stale profile record falls back to autodetect" "$(detect_argv)" "pf/Google/Chrome"
rm -f "$fx/users/testuser/.wsl-cdp/browser"

# --- autodetect waterfall: the FULL documented order — Chrome (system, user),
#     Edge (x86, 64-bit), Brave (user, system) — asserted by deleting the
#     winner one rank at a time (v0.3.1: Brave last, updater contention)
i=0
while IFS= read -r exe; do
  i=$((i+1))
  assert_contains "autodetect rank $i is ${exe#"$fx"/}" "$(detect_argv)" "${exe#"$fx"/}"
  rm "$exe"
done < <(fixture_rank "$fx")

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

# --- browsers verb (v0.3.2): rank-ordered enumeration, flags, machine shape.
#     Fresh fixture: the waterfall above deleted $fx's browsers. A shimmed
#     no-output tasklist.exe ("interop down") makes `running` deterministic on
#     real WSL boxes, where the genuine tasklist would answer.
fx2="$(make_fixture)"
mkdir -p "$fx2/bin-down"
printf '#!/usr/bin/env bash\nexit 0\n' >"$fx2/bin-down/tasklist.exe"
chmod +x "$fx2/bin-down/tasklist.exe"
browsers_run(){ PATH="$fx2/bin-down:$PATH" WSL_CDP_USERS_ROOT="$fx2/users" \
  WSL_CDP_WINUSER=testuser \
  WSL_CDP_PROGRAMFILES="$fx2/pf" WSL_CDP_PROGRAMFILES_X86="$fx2/pf86" \
  HOME="$fx2/home" "$CLI" browsers "$@" 2>/dev/null; }
bt="$(browsers_run)"
assert_eq "browsers lists all six installs" 6 "$(printf '%s\n' "$bt" | wc -l)"
assert_contains "browsers rank 1 is system Chrome" "$(printf '%s\n' "$bt" | head -1)" "pf/Google/Chrome"
assert_contains "browsers rank 1 carries recommended" "$(printf '%s\n' "$bt" | head -1)" "recommended"
assert_exit "browsers --xml -> 2" 2 "$CLI" browsers --xml
assert_exit "browsers stray positional -> 2" 2 "$CLI" browsers stray

bj="$(browsers_run --json)"
if printf '%s' "$bj" | jq -e --arg p "$(fixture_chrome "$fx2")" '
     (.browsers|length)==6 and .browsers[0].name=="chrome"
     and .browsers[0].recommended==true and .browsers[0].running==null
     and .source=="autodetect" and .selected==$p' >/dev/null 2>&1; then
  _ok "browsers --json well-shaped (running null when interop absent)"
else
  _no "browsers --json shape wrong: $bj"
fi

# --- browsers: a recorded profile owner is flagged and wins selection
mkdir -p "$fx2/users/testuser/.wsl-cdp"
printf '%s' "$(fixture_brave "$fx2")" >"$fx2/users/testuser/.wsl-cdp/browser"
bj="$(browsers_run --json)"
if printf '%s' "$bj" | jq -e --arg p "$(fixture_brave "$fx2")" '
     .source=="recorded" and .selected==$p
     and ([.browsers[]|select(.recorded)] | length==1 and all(.name=="brave"))' >/dev/null 2>&1; then
  _ok "browsers --json surfaces the recorded profile owner"
else
  _no "browsers --json recorded shape wrong: $bj"
fi
rm -f "$fx2/users/testuser/.wsl-cdp/browser"

# --- browsers: running flags through a tasklist.exe seam (brave live, rest not)
mkdir -p "$fx2/bin"
cat >"$fx2/bin/tasklist.exe" <<'SHIM'
#!/usr/bin/env bash
case "$*" in
  *brave.exe*) printf '"brave.exe","4242","Console","1","123,456 K"\n' ;;
  *) printf 'INFO: No tasks are running which match the specified criteria.\n' ;;
esac
SHIM
chmod +x "$fx2/bin/tasklist.exe"
bj="$(PATH="$fx2/bin:$PATH" WSL_CDP_USERS_ROOT="$fx2/users" WSL_CDP_WINUSER=testuser \
  WSL_CDP_PROGRAMFILES="$fx2/pf" WSL_CDP_PROGRAMFILES_X86="$fx2/pf86" \
  HOME="$fx2/home" "$CLI" browsers --json 2>/dev/null)"
if printf '%s' "$bj" | jq -e '
     ([.browsers[]|select(.name=="brave")] | length==2 and all(.running==true))
     and ([.browsers[]|select(.name!="brave")] | length==4 and all(.running==false))' >/dev/null 2>&1; then
  _ok "browsers running flags via tasklist seam"
else
  _no "browsers running flags wrong: $bj"
fi

# --- browsers: a non-executable env override is previewed with a loud WARN
#     (selected/source document what `up` would use, and `up` would FAIL here)
b_err="$(WSL_CDP_USERS_ROOT="$fx2/users" WSL_CDP_WINUSER=testuser \
  WSL_CDP_PROGRAMFILES="$fx2/pf" WSL_CDP_PROGRAMFILES_X86="$fx2/pf86" \
  HOME="$fx2/home" WSL_CDP_BROWSER="$fx2/nope.exe" \
  "$CLI" browsers --json 2>&1 >/dev/null)"
assert_contains "browsers warns on a non-executable override" "$b_err" "not executable"

# --- browsers: zero installs is a loud exit 1, not an empty success
fx3="$(mktemp -d "${TMPDIR:-/tmp}/wslcdp-none.XXXXXX")"
mkdir -p "$fx3/users/testuser/AppData/Local/Temp" "$fx3/home"
assert_exit "browsers with no installs -> 1" 1 env WSL_CDP_USERS_ROOT="$fx3/users" \
  WSL_CDP_WINUSER=testuser WSL_CDP_PROGRAMFILES="$fx3/pf" \
  WSL_CDP_PROGRAMFILES_X86="$fx3/pf86" HOME="$fx3/home" "$CLI" browsers

# --- up over an already-live bridge with WSL_CDP_BROWSER set: the explicit
#     choice must not be DISCARDED silently (v0.3.2 review blocker). Fake
#     /json/version server on a scratch port makes up return at step 0 —
#     nothing is launched, no Windows state is touched.
srv_port=9345
python3 - "$srv_port" >/dev/null 2>&1 <<'PY' &
import http.server, json, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        b = json.dumps({"Browser": "FakeBrowser/1.0"}).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def log_message(self, *a):
        pass
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
srv_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf -m 1 "http://127.0.0.1:$srv_port/json/version" >/dev/null 2>&1 && break
  sleep 0.2
done
up_err="$(WSL_CDP_PORT=$srv_port WSL_CDP_PROXY_PORT=9346 \
  WSL_CDP_BROWSER=/mnt/c/fake/browser.exe "$CLI" up 2>&1 >/dev/null)"
up_rc=$?
up_out="$(WSL_CDP_PORT=$srv_port WSL_CDP_PROXY_PORT=9346 "$CLI" up 2>/dev/null)"
kill "$srv_pid" 2>/dev/null
assert_eq "up over a live bridge exits 0" 0 "$up_rc"
assert_contains "up warns when the browser override is not applied" "$up_err" "WSL_CDP_BROWSER is set"
assert_contains "up without an override stays note-free" "$up_out" "bridge up: FakeBrowser"

# --- status --json: valid JSON, documented shape, ok:false when the chain is down
sj="$(WSL_CDP_PORT=9333 WSL_CDP_PROXY_PORT=9334 "$CLI" status --json 2>/dev/null)"
if printf '%s' "$sj" | jq -e '.ok==false and (.exit|type=="number") and (.checks|length==3) and (.checks[0]|has("status") and has("name") and has("detail"))' >/dev/null 2>&1; then
  _ok "status --json is valid and well-shaped"
else
  _no "status --json shape wrong: $sj"
fi

t_summary
