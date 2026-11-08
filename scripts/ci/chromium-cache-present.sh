#!/usr/bin/env bash
# A restored cache is usable only when it contains the Chromium revision that
# the installed Playwright requires, including the executable headless shell.
# An older browser restored through a cache prefix must trigger a new install.
set -euo pipefail

if ! chrome_path="$(pnpm exec node -e 'process.stdout.write(require("playwright").chromium.executablePath())' 2>/dev/null)"; then
  echo "false"
  exit 0
fi
if [ ! -x "$chrome_path" ]; then
  echo "false"
  exit 0
fi

if ! dry_run="$(pnpm exec playwright install --dry-run chromium 2>/dev/null)"; then
  echo "false"
  exit 0
fi
headless_location="$(printf '%s\n' "$dry_run" | awk '
  /Install location:/ {
    sub(/^[[:space:]]*Install location:[[:space:]]*/, "")
    if ($0 ~ /\/chromium_headless_shell-[0-9]+$/) { print; exit }
  }
')"
if [ -z "$headless_location" ]; then
  echo "false"
  exit 0
fi

shopt -s nullglob
for executable in \
  "$headless_location"/chrome-headless-shell-*/chrome-headless-shell \
  "$headless_location"/chrome-*/headless_shell \
  "$headless_location"/headless_shell; do
  if [ -f "$executable" ] && [ -x "$executable" ]; then
    echo "true"
    exit 0
  fi
done
echo "false"
