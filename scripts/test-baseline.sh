#!/usr/bin/env bash
set -euo pipefail

baseline_file="tests/moon-test-baseline.env"
if [ ! -f "$baseline_file" ]; then
  echo "Baseline file not found: $baseline_file"
  echo "Run: just test-baseline-update"
  exit 1
fi

source "$baseline_file"

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

set +e
TERM=dumb moon test >"$log_file" 2>&1
moon_exit=$?
set -e

summary="$(rg 'Total tests: [0-9]+, passed: [0-9]+, failed: [0-9]+\.' "$log_file" | tail -n 1 || true)"
if [ -z "$summary" ]; then
  echo "Failed to parse moon test summary."
  tail -n 80 "$log_file" || true
  exit 1
fi

read -r current_total current_passed current_failed < <(echo "$summary" | sed -E 's/.*Total tests: ([0-9]+), passed: ([0-9]+), failed: ([0-9]+).*/\1 \2 \3/')

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

if [ "$moon_exit" -ne 0 ] && [ "$current_failed" -gt 0 ]; then
  echo "Known failures remain, but no regression from baseline."
fi

echo "Baseline check passed."
