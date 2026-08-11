#!/usr/bin/env bash
# Release-train policy regression. Parses the constrained workflow structure so
# a blessed SHA in a comment or unrelated job cannot satisfy the announce gate.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/release-train.yml"
HARDENED_SHA='08f7d22f3a5b59b1658ab2e96a20d0d3c352869c'
RETIRED_SHA='c981b872ebf650805200ad72c8b7142232f8b3f6'
EXPECTED_USES="StartupBros-com/hov-marketplace/.github/workflows/hov-tool-drop-announce.yml@$HARDENED_SHA"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/wslcdp-release-train.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$ROOT/tests/lib.sh"

validate_release_train() {
  python3 - "$1" "$EXPECTED_USES" "$RETIRED_SHA" <<'PY'
import sys
from pathlib import Path

workflow_path, expected_uses, retired_sha = sys.argv[1:]
source = Path(workflow_path).read_text(encoding="utf-8")

if retired_sha in source:
    raise SystemExit("retired announce workflow SHA remains")


def strip_comment(value: str) -> str:
    quote = None
    escaped = False
    for index, char in enumerate(value):
        if escaped:
            escaped = False
            continue
        if char == "\\" and quote == '"':
            escaped = True
            continue
        if char in ("'", '"'):
            if quote == char:
                quote = None
            elif quote is None:
                quote = char
            continue
        if char == "#" and quote is None and (
            index == 0 or value[index - 1].isspace()
        ):
            return value[:index]
    return value


def scalar(value: str):
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        return [item.strip().strip("'\"") for item in value[1:-1].split(",")]
    return value.strip("'\"")


def parse_mapping(text: str):
    root = {}
    stack = [(-1, root)]
    for line_number, raw_line in enumerate(text.splitlines(), 1):
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        indentation = len(raw_line) - len(raw_line.lstrip(" "))
        if "\t" in raw_line[: len(raw_line) - len(raw_line.lstrip())]:
            raise SystemExit(f"line {line_number}: tabs are not supported")
        line = strip_comment(raw_line.lstrip()).rstrip()
        if not line:
            continue
        if ":" not in line:
            raise SystemExit(f"line {line_number}: expected a mapping entry")
        key, value = line.split(":", 1)
        key = key.strip().strip("'\"")
        while stack[-1][0] >= indentation:
            stack.pop()
        parent = stack[-1][1]
        if key in parent:
            raise SystemExit(f"line {line_number}: duplicate key {key}")
        if value.strip():
            parent[key] = scalar(value)
        else:
            child = {}
            parent[key] = child
            stack.append((indentation, child))
    return root


def require_mapping(value, label: str):
    if not isinstance(value, dict):
        raise SystemExit(f"{label} must be a mapping")
    return value


workflow = parse_mapping(source)
release = require_mapping(
    require_mapping(workflow.get("on"), "on").get("release"), "on.release"
)
if release.get("types") != ["published", "edited"]:
    raise SystemExit("release types must be exactly published and edited")

jobs = require_mapping(workflow.get("jobs"), "jobs")
announce = require_mapping(jobs.get("announce"), "jobs.announce")
if announce.get("uses") != expected_uses:
    raise SystemExit("jobs.announce.uses is not the hardened immutable workflow")

effective_permissions = announce.get("permissions", workflow.get("permissions"))
if effective_permissions != {"contents": "read", "id-token": "write"}:
    raise SystemExit(
        "effective announce permissions must be exactly contents: read and id-token: write"
    )
PY
}

python3 - "$WORKFLOW" "$TMP" "$HARDENED_SHA" "$RETIRED_SHA" <<'PY'
import sys
from pathlib import Path

workflow_path, fixture_dir, hardened_sha, retired_sha = sys.argv[1:]
source = Path(workflow_path).read_text(encoding="utf-8")
fixtures = Path(fixture_dir)


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise SystemExit(f"fixture anchor must occur once: {old!r}")
    return text.replace(old, new, 1)


(fixtures / "retired.yml").write_text(
    replace_once(source, hardened_sha, retired_sha), encoding="utf-8"
)

announce_line = (
    "  announce:\n"
    "    uses: StartupBros-com/hov-marketplace/.github/workflows/"
    f"hov-tool-drop-announce.yml@{hardened_sha} # fix: bind Tool Drop intent to the promoted release"
)
decoy_jobs = (
    "  decoy:\n"
    f"    # StartupBros-com/hov-marketplace/.github/workflows/hov-tool-drop-announce.yml@{hardened_sha}\n"
    "    uses: StartupBros-com/hov-marketplace/.github/workflows/"
    f"hov-tool-drop-announce.yml@{hardened_sha}\n"
    "  announce:\n"
    "    uses: attacker/hov-marketplace/.github/workflows/"
    f"hov-tool-drop-announce.yml@{hardened_sha}"
)
(fixtures / "decoy.yml").write_text(
    replace_once(source, announce_line, decoy_jobs), encoding="utf-8"
)

(fixtures / "missing-edited.yml").write_text(
    replace_once(source, "types: [published, edited]", "types: [published]"),
    encoding="utf-8",
)

(fixtures / "shadowed-permissions.yml").write_text(
    replace_once(
        source,
        announce_line,
        announce_line.replace(
            "\n    uses:", "\n    permissions:\n      contents: read\n    uses:"
        ),
    ),
    encoding="utf-8",
)
PY

assert_exit "current release train satisfies hardened policy" 0 \
  validate_release_train "$WORKFLOW"
assert_exit "retired workflow pin is rejected" 1 \
  validate_release_train "$TMP/retired.yml"
assert_exit "comment and unrelated-job decoys cannot bless announce" 1 \
  validate_release_train "$TMP/decoy.yml"
assert_exit "missing edited trigger is rejected" 1 \
  validate_release_train "$TMP/missing-edited.yml"
assert_exit "job-level permission shadowing is rejected" 1 \
  validate_release_train "$TMP/shadowed-permissions.yml"

t_summary
