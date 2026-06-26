#!/usr/bin/env bash
#
# Run `moon test` with the mizchi/v8-dependent workspace members excluded, so
# packages that don't need V8 (dom, layout, renderer, css, ...) can be tested in
# environments where the rusty_v8 native bridge can't be built — e.g. the
# Claude-Code-on-the-web sandbox, where outbound git access to
# denoland/rusty_v8 is blocked by egress policy (403). See crater #312.
#
# Why this is needed: `moon test` resolves and installs deps for the WHOLE
# workspace before running any test, and `mizchi/v8`'s postadd hook builds
# rusty_v8 during that install. With no network access to rusty_v8 the install
# fails, so even a v8-unrelated `moon test -p mizchi/crater-dom` never runs.
# `mizchi/v8` enters the graph through two members:
#   - ./browser/native  (direct dep on mizchi/v8)
#   - ./testing         (dep on crater-browser-native -> mizchi/v8)
# Dropping those two members from moon.work for the duration of the run removes
# V8 from the dependency graph entirely.
#
# Usage:
#   scripts/moon-test-no-v8.sh -p mizchi/crater-layout/grid
#   scripts/moon-test-no-v8.sh -p mizchi/crater-dom --target js
#
# moon.work is restored on exit (including on failure/interrupt).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

work="moon.work"
if [[ ! -f "$work" ]]; then
  echo "error: $work not found in $repo_root" >&2
  exit 1
fi

backup="$(mktemp)"
cp "$work" "$backup"
restore() { cp "$backup" "$work"; rm -f "$backup"; }
trap restore EXIT

# Remove the V8-pulling members. Matches lines like `  "./browser/native",`.
grep -vE '^[[:space:]]*"\./(browser/native|testing)",[[:space:]]*$' "$backup" > "$work"

# Belt-and-suspenders: if a V8-adjacent prebuild still runs, degrade instead of
# failing (browser/scripts/mizchi-v8-consumer-prebuild.mjs honors this).
export MIZCHI_V8_OPTIONAL=1

echo "[moon-test-no-v8] running: moon test $*" >&2
moon test "$@"
