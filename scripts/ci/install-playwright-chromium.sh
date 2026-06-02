#!/usr/bin/env bash
# Install Playwright's Chromium and its system libraries, bounded by a
# per-attempt timeout and retried.
#
# `pnpm exec playwright install --with-deps chromium` has two distinct, observed
# hang vectors when run as a single command:
#
#   1. Post-download stall: the browser download reaches 100% and then `install`
#      stalls indefinitely in the extraction / validation phase.
#   2. apt stall: the `--with-deps` system-dependency phase hangs before the
#      download even starts (e.g. waiting on an interactive apt frontend).
#
# Because both phases share one un-decomposable command, a stall in either pins
# the job to GitHub's 6-hour default and forces a manual cancel. Worse, on each
# retry Playwright's browser GC removes the cached browser ("Removing unused
# browser …") and re-downloads from scratch, so the cache restored by
# actions/cache never short-circuits the install.
#
# This script splits the work and hardens each phase:
#   * DEBIAN_FRONTEND=noninteractive removes the interactive-apt hang vector.
#   * PLAYWRIGHT_SKIP_BROWSER_GC=1 stops Playwright deleting the restored cached
#     browser, so a warm cache makes the browser install a fast verify.
#   * System deps install once, bounded and tolerant — the CI runners already
#     ship every required library, so a failure here is non-fatal.
#   * The browser install runs in its own bounded retry loop, decoupled from the
#     apt phase, so an apt stall can never force a fresh browser re-download.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
# Keep the browser restored from actions/cache instead of GC'ing and
# re-downloading it on every install invocation.
export PLAYWRIGHT_SKIP_BROWSER_GC=1

attempts="${PLAYWRIGHT_INSTALL_ATTEMPTS:-3}"
per_attempt_timeout="${PLAYWRIGHT_INSTALL_TIMEOUT:-420}"
deps_timeout="${PLAYWRIGHT_DEPS_TIMEOUT:-300}"

# Install the system libraries once, separately from the browser. The runners
# already have these (apt reports "0 upgraded"), so a stall or failure here is
# bounded and non-fatal — the browser install below is what actually matters.
echo "::group::playwright install-deps chromium"
deps_status=0
timeout "${deps_timeout}" pnpm exec playwright install-deps chromium || deps_status=$?
echo "::endgroup::"
if [ "$deps_status" -ne 0 ]; then
  echo "playwright install-deps chromium exited ${deps_status}; continuing (runner libs are preinstalled)" >&2
fi

# Install the browser binary in its own bounded retry loop.
for attempt in $(seq 1 "$attempts"); do
  echo "::group::playwright install chromium (attempt ${attempt}/${attempts})"
  status=0
  timeout "${per_attempt_timeout}" pnpm exec playwright install chromium || status=$?
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

echo "playwright install chromium failed after ${attempts} attempts" >&2
exit 1
