#!/usr/bin/env bash
#
# Per-module WPT baseline check. Runs scripts/wpt-runner.ts for a single
# module and compares the result against tests/wpt-baselines/<module>.env.
#
# Used by the compat.css-*-baseline pkspec scenarios. The aggregate
# tests/wpt-baseline.env covers --all; this script extends the same
# mechanism to one module at a time so a single module can be promoted
# to approved without dragging in the rest.
#
# Usage:
#   scripts/test-wpt-module-baseline.sh css-color

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <module-name>" >&2
  exit 2
fi

module="$1"
baseline_file="tests/wpt-baselines/${module}.env"

if [ ! -f "$baseline_file" ]; then
  echo "Baseline file not found: $baseline_file" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$baseline_file"

if [ -z "${BASELINE_TOTAL:-}" ] || [ -z "${BASELINE_PASSED:-}" ] || [ -z "${BASELINE_FAILED:-}" ]; then
  echo "Baseline file $baseline_file is missing BASELINE_TOTAL / BASELINE_PASSED / BASELINE_FAILED" >&2
  exit 1
fi

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

set +e
TERM=dumb npx tsx scripts/wpt-runner.ts "$module" >"$log_file" 2>&1
wpt_exit=$?
set -e

summary="$(grep -E 'Summary: [0-9]+ passed, [0-9]+ failed' "$log_file" | tail -n 1 || true)"
if [ -z "$summary" ]; then
  echo "Failed to parse WPT summary from $module run." >&2
  tail -n 60 "$log_file" || true
  exit 1
fi

current_passed="$(echo "$summary" | sed -E 's/.*Summary: ([0-9]+) passed, ([0-9]+) failed.*/\1/')"
current_failed="$(echo "$summary" | sed -E 's/.*Summary: ([0-9]+) passed, ([0-9]+) failed.*/\2/')"
current_total=$((current_passed + current_failed))

echo "Module:   $module"
echo "Baseline: total=$BASELINE_TOTAL passed=$BASELINE_PASSED failed=$BASELINE_FAILED"
echo "Current:  total=$current_total passed=$current_passed failed=$current_failed"

if [ "$current_total" -lt "$BASELINE_TOTAL" ]; then
  echo "Regression: total tests decreased ($current_total < $BASELINE_TOTAL)" >&2
  exit 1
fi

if [ "$current_failed" -gt "$BASELINE_FAILED" ]; then
  echo "Regression: failed tests increased ($current_failed > $BASELINE_FAILED)" >&2
  tail -n 60 "$log_file" || true
  exit 1
fi

if [ "$current_passed" -lt "$BASELINE_PASSED" ]; then
  echo "Regression: passed tests decreased ($current_passed < $BASELINE_PASSED)" >&2
  tail -n 60 "$log_file" || true
  exit 1
fi

if [ "$wpt_exit" -ne 0 ] && [ "$current_failed" -gt 0 ]; then
  echo "Known WPT failures remain for $module, but no regression from baseline."
fi

echo "WPT $module baseline check passed."
