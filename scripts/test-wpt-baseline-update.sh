#!/usr/bin/env bash
set -euo pipefail

baseline_file="tests/wpt-baseline.env"
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

read -r passed failed < <(echo "$summary" | sed -E 's/.*Summary: ([0-9]+) passed, ([0-9]+) failed.*/\1 \2/')
total=$((passed + failed))
updated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat >"$baseline_file" <<EOF
BASELINE_TOTAL=$total
BASELINE_PASSED=$passed
BASELINE_FAILED=$failed
BASELINE_UPDATED_AT=$updated_at
EOF

echo "Updated WPT baseline: $baseline_file"
echo "Summary: total=$total passed=$passed failed=$failed"
if [ "$wpt_exit" -ne 0 ] && [ "$failed" -gt 0 ]; then
  echo "wpt run exited non-zero due to known failures; baseline was recorded."
fi
