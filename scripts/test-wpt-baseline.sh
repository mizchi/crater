#!/usr/bin/env bash
set -euo pipefail

baseline_file="tests/wpt-baseline.env"
if [ ! -f "$baseline_file" ]; then
  echo "Baseline file not found: $baseline_file"
  echo "Run: just wpt-baseline-update"
  exit 1
fi

source "$baseline_file"

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

set +e
TERM=dumb npx tsx scripts/wpt-runner.ts --all >"$log_file" 2>&1
wpt_exit=$?
set -e

summary="$(rg 'Summary: [0-9]+ passed, [0-9]+ failed' "$log_file" | tail -n 1 || true)"
if [ -z "$summary" ]; then
  echo "Failed to parse WPT summary."
  tail -n 120 "$log_file" || true
  exit 1
fi

read -r current_passed current_failed < <(echo "$summary" | sed -E 's/.*Summary: ([0-9]+) passed, ([0-9]+) failed.*/\1 \2/')
current_total=$((current_passed + current_failed))

echo "Baseline: total=$BASELINE_TOTAL passed=$BASELINE_PASSED failed=$BASELINE_FAILED"
echo "Current : total=$current_total passed=$current_passed failed=$current_failed"

if [ "$current_total" -lt "$BASELINE_TOTAL" ]; then
  echo "Regression: total tests decreased ($current_total < $BASELINE_TOTAL)"
  exit 1
fi

if [ "$current_failed" -gt "$BASELINE_FAILED" ]; then
  echo "Regression: failed tests increased ($current_failed > $BASELINE_FAILED)"
  tail -n 120 "$log_file" || true
  exit 1
fi

if [ "$current_passed" -lt "$BASELINE_PASSED" ]; then
  echo "Regression: passed tests decreased ($current_passed < $BASELINE_PASSED)"
  tail -n 120 "$log_file" || true
  exit 1
fi

if [ "$wpt_exit" -ne 0 ] && [ "$current_failed" -gt 0 ]; then
  echo "Known WPT failures remain, but no regression from baseline."
fi

echo "WPT baseline check passed."
