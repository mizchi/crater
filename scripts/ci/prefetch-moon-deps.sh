#!/usr/bin/env bash
# Prefetch every registry dependency of a module so later steps run offline.
#
# A leading `-C <dir>` selects the module. It is hoisted in front of the
# subcommand (`moon -C <dir> tree`) because `-C` is a common option that must
# precede it; neither `moon tree` nor `moon fetch` accepts `--manifest-path`.
# Any remaining args are forwarded to `moon tree`.
set -euo pipefail

moon_common=()
if [[ "${1:-}" == "-C" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "usage: $(basename "$0") [-C <dir>] [moon tree args...]" >&2
    exit 2
  fi
  moon_common=(-C "$2")
  shift 2
fi

tmp_tree="$(mktemp)"
tmp_deps="$(mktemp)"
trap 'rm -f "$tmp_tree" "$tmp_deps"' EXIT

moon ${moon_common[@]+"${moon_common[@]}"} tree "$@" >"$tmp_tree"

awk '
  /->/ {
    split($0, parts, "-> ")
    dep = parts[2]
    if (dep ~ /\(local /) {
      next
    }
    sub(/ .*/, "", dep)
    print dep
  }
' "$tmp_tree" | sort -u >"$tmp_deps"

if [[ ! -s "$tmp_deps" ]]; then
  echo "No registry dependencies to prefetch"
  exit 0
fi

echo "Prefetching MoonBit dependencies"
cat "$tmp_deps"

# `moon fetch` pulls each archive from https://download.mooncakes.io/. That host
# drops connections often enough to fail a whole job on one dependency
# (observed: `client error (Connect) / Connection reset by peer` fetching
# mizchi/crater-aomx, before any build had started). It is the same class of
# transient registry blip that `moon-update-retry.sh` already guards `moon
# update` against, so retry on the same schedule; a dependency that is genuinely
# missing still fails after the last attempt.
fetch_with_retries() {
  local dep="$1"
  local attempts=4
  local delay=5
  local attempt
  for attempt in $(seq 1 "$attempts"); do
    if moon ${moon_common[@]+"${moon_common[@]}"} fetch --no-update "$dep"; then
      return 0
    fi
    if [[ "$attempt" -eq "$attempts" ]]; then
      echo "moon fetch ${dep} failed after ${attempt} attempts" >&2
      return 1
    fi
    echo "moon fetch ${dep} attempt ${attempt} failed (likely a transient mooncakes.io blip); retrying in ${delay}s" >&2
    sleep "$delay"
    delay=$((delay * 2))
  done
}

while IFS= read -r dep; do
  fetch_with_retries "$dep"
done <"$tmp_deps"
