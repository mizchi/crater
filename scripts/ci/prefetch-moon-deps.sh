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

while IFS= read -r dep; do
  moon ${moon_common[@]+"${moon_common[@]}"} fetch --no-update "$dep"
done <"$tmp_deps"
