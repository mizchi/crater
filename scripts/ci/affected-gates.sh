#!/usr/bin/env bash
# Decide which heavy CI gates need to run based on `pkf affected`.
# Writes gate booleans (wpt_css, wpt_dom, wpt_webdriver, paint_vrt, wpt_vrt,
# gfx_vrt) to $GITHUB_OUTPUT and prints a summary to stdout.
#
# Falls back to running everything when:
# - the event is `schedule` (nightly runs the full matrix)
# - the `--force-all` flag is given (debugging knob)
set -euo pipefail

force_all=false
base=""
changed_files=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-all) force_all=true; shift ;;
    --base) base="$2"; shift 2 ;;
    --files) changed_files+=("$2"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

gates=(wpt_css wpt_dom wpt_webdriver paint_vrt wpt_vrt gfx_vrt)

emit_all_true() {
  local reason="$1"
  echo "all gates -> true (reason: ${reason})"
  for gate in "${gates[@]}"; do
    echo "${gate}=true" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  done
}

event="${GITHUB_EVENT_NAME:-}"
if $force_all; then
  emit_all_true "--force-all"
  exit 0
fi
if [[ "$event" == "schedule" ]]; then
  emit_all_true "schedule event"
  exit 0
fi

# pkfire >= 0.12 (MoonBit rewrite): `pkf affected <path>...` takes the changed
# file paths and prints the affected task names, one per line. (Older `pkf
# affected --since <base>` / `--files` / `--dry-run` flags were removed.) So
# resolve the changed file set first, then ask pkf which tasks it affects.
if [[ ${#changed_files[@]} -eq 0 ]]; then
  if [[ -z "$base" ]]; then
    base="$(bash scripts/ci/pkfire-affected-base.sh)"
  fi
  if [[ -n "$base" ]]; then
    echo "affected base: ${base}"
    mapfile -t changed_files < <(git diff --name-only "${base}...HEAD")
  fi
fi

if [[ ${#changed_files[@]} -eq 0 ]]; then
  # Couldn't determine a changed-file set — run everything to be safe rather
  # than risk skipping a needed gate.
  emit_all_true "no changed files resolved"
  exit 0
fi

printf 'affected files:'
printf ' %s' "${changed_files[@]}"
printf '\n'

set +e
plan="$(pkf affected "${changed_files[@]}" 2>&1)"
status=$?
set -e
echo "${plan}"

if [[ $status -ne 0 ]]; then
  echo "pkf affected exited with ${status}; running every heavy gate to be safe"
  emit_all_true "pkf affected error"
  exit 0
fi

# Each gate maps to a pkf task; the gate is affected iff that task name appears
# (as a whole line) in pkf's affected-task output.
declare -A task_for=(
  [wpt_css]=test-wpt-css
  [wpt_dom]=test-wpt-dom
  [wpt_webdriver]=test-wpt-webdriver
  [paint_vrt]=test-vrt
  [wpt_vrt]=test-wpt-vrt
  [gfx_vrt]=test-image-vrt
)

for gate in "${gates[@]}"; do
  task="${task_for[$gate]}"
  if grep -qxF "${task}" <<<"${plan}"; then
    value=true
  else
    value=false
  fi
  echo "${gate}=${value}"
  echo "${gate}=${value}" >> "${GITHUB_OUTPUT:-/dev/stdout}"
done
