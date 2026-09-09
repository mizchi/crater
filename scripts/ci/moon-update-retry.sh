#!/usr/bin/env bash
# Run `moon update` with retries.
#
# `moon update` clones the registry index from https://mooncakes.io/git/index/.
# That host occasionally times out in CI (observed: a ~135s connect timeout
# failing the whole prefetch job), which is a transient infra blip, not a real
# dependency problem. Retry with exponential backoff so a one-off mooncakes.io
# outage doesn't fail the run.
#
# A leading `-C <dir>` selects the module to update. It is hoisted in front of
# the subcommand (`moon -C <dir> update`) because `-C` is a common option that
# must precede it; `moon update` itself takes no `--manifest-path`. Any
# remaining args are forwarded to `moon update`.
set -euo pipefail

moon_common=()
if [[ "${1:-}" == "-C" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "usage: $(basename "$0") [-C <dir>] [moon update args...]" >&2
    exit 2
  fi
  moon_common=(-C "$2")
  shift 2
fi

attempts=4
delay=5
for attempt in $(seq 1 "$attempts"); do
  if moon ${moon_common[@]+"${moon_common[@]}"} update "$@"; then
    exit 0
  fi
  if [ "$attempt" -eq "$attempts" ]; then
    echo "moon update failed after ${attempt} attempts" >&2
    exit 1
  fi
  echo "moon update attempt ${attempt} failed (likely a transient mooncakes.io outage); retrying in ${delay}s" >&2
  sleep "$delay"
  delay=$((delay * 2))
done
