#!/usr/bin/env bash
# Install Playwright's Chromium (plus the system libraries pulled in by
# `--with-deps`), bounded by a per-attempt timeout and retried.
#
# `pnpm exec playwright install --with-deps chromium` has been observed to
# stall indefinitely after the browser download reaches 100% (extraction /
# post-install hang). The CI jobs that call it have no step or job timeout, so
# a single stall pins the job to GitHub's 6-hour default and the whole run has
# to be cancelled by hand. Bound each attempt with `timeout` and retry a few
# times so a transient stall fails fast and self-recovers instead of hanging
# the workflow.
set -euo pipefail

attempts="${PLAYWRIGHT_INSTALL_ATTEMPTS:-3}"
per_attempt_timeout="${PLAYWRIGHT_INSTALL_TIMEOUT:-420}"

for attempt in $(seq 1 "$attempts"); do
  echo "::group::playwright install --with-deps chromium (attempt ${attempt}/${attempts})"
  status=0
  timeout "${per_attempt_timeout}" pnpm exec playwright install --with-deps chromium || status=$?
  echo "::endgroup::"

  if [ "$status" -eq 0 ]; then
    exit 0
  fi
  if [ "$status" -eq 124 ]; then
    echo "attempt ${attempt} timed out after ${per_attempt_timeout}s" >&2
  else
    echo "attempt ${attempt} failed with exit ${status}" >&2
  fi
  sleep $((attempt * 5))
done

echo "playwright install --with-deps chromium failed after ${attempts} attempts" >&2
exit 1
