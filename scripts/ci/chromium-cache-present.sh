#!/usr/bin/env bash
# Print "true" if a Playwright Chromium browser binary is already present in the
# cache directory (e.g. restored from actions/cache via restore-keys), else
# "false".
#
# The CI jobs that drive Chrome cache ~/.cache/ms-playwright keyed on
# package.json/pnpm-lock.yaml. Any dependency change invalidates the exact key
# for every job at once; with restore-keys the previous browser is still
# restored, but the install step was gated on the *exact* cache hit and so re-ran
# `playwright install`, forcing a fresh, flaky download that fails the strict WPT
# gates. Gating the install step on this check instead lets a restored browser
# (exact or partial) skip the download entirely — the same path that is already
# proven green when the exact cache hits.
set -euo pipefail

cache_dir="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"

shopt -s nullglob
matches=("$cache_dir"/chromium-*/chrome-linux*/chrome)
if [ "${#matches[@]}" -gt 0 ] && [ -x "${matches[0]}" ]; then
  echo "true"
else
  echo "false"
fi
