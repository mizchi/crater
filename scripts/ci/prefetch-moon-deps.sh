#!/usr/bin/env bash
set -euo pipefail

tmp_tree="$(mktemp)"
tmp_deps="$(mktemp)"
trap 'rm -f "$tmp_tree" "$tmp_deps"' EXIT

if [[ $# -gt 0 ]]; then
  moon tree "$@" >"$tmp_tree"
else
  moon tree >"$tmp_tree"
fi

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
  if [[ $# -gt 0 ]]; then
    moon fetch --no-update "$@" "$dep"
  else
    moon fetch --no-update "$dep"
  fi
done <"$tmp_deps"
