#!/usr/bin/env bash
# Decide which heavy CI gates need to run based on `pkf affected`.
# Writes gate booleans (wpt_css, wpt_dom, wpt_webdriver, paint_vrt, wpt_vrt)
# to $GITHUB_OUTPUT and prints a summary to stdout.
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

gates=(wpt_css wpt_dom wpt_webdriver paint_vrt wpt_vrt)

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

affected_args=()
if [[ ${#changed_files[@]} -gt 0 ]]; then
  for file in "${changed_files[@]}"; do
    affected_args+=(--files "$file")
  done
elif [[ -n "$base" ]]; then
  affected_args+=(--since "$base")
else
  base="$(bash scripts/ci/pkfire-affected-base.sh)"
  affected_args+=(--since "$base")
fi
if [[ -n "$base" ]]; then
  echo "affected base: ${base}"
fi
if [[ ${#changed_files[@]} -gt 0 ]]; then
  printf 'affected files:'
  printf ' %s' "${changed_files[@]}"
  printf '\n'
fi

set +e
plan="$(pkf affected \
  "${affected_args[@]}" \
  --dry-run \
  test-wpt-css test-wpt-dom test-wpt-webdriver test-vrt test-wpt-vrt 2>&1)"
status=$?
set -e
echo "${plan}"

if [[ $status -ne 0 ]]; then
  echo "pkf affected exited with ${status}; running every heavy gate to be safe"
  emit_all_true "pkf affected error"
  exit 0
fi

# `pkf affected --dry-run` prints a plan table whose rows look like:
#   uncached                test-wpt-css        just wpt-all
# We grep each task name. When the task name appears in a plan row, the
# gate is considered affected.
declare -A task_for=(
  [wpt_css]=test-wpt-css
  [wpt_dom]=test-wpt-dom
  [wpt_webdriver]=test-wpt-webdriver
  [paint_vrt]=test-vrt
  [wpt_vrt]=test-wpt-vrt
)

for gate in "${gates[@]}"; do
  task="${task_for[$gate]}"
  if echo "${plan}" | awk -v t="${task}" '$0 ~ ("[[:space:]]" t "[[:space:]]")' | grep -q .; then
    value=true
  else
    value=false
  fi
  echo "${gate}=${value}"
  echo "${gate}=${value}" >> "${GITHUB_OUTPUT:-/dev/stdout}"
done
