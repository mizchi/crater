#!/usr/bin/env bash
#
# Remove the mizchi/v8-pulling workspace members from a moon.work so that a
# `moon` invocation over the workspace never resolves `mizchi/v8` — and thus
# never runs its `postadd` hook, which `git clone`s denoland/rusty_v8 at
# dependency-resolution time. That clone is the wrong thing to pay for in
# JS/wasm-only jobs (vrt-bench, benchmarks): it is slow, flakes on transient
# network, and is hard-blocked (403) in the Claude-Code-on-the-web sandbox,
# where it aborts resolution for the *whole* workspace even for a v8-unrelated
# `--target js` build. See crater #312.
#
# `mizchi/v8` enters the graph through exactly two members:
#   - ./browser/native  (direct dep on mizchi/v8)
#   - ./testing         (dep on crater-browser-native -> mizchi/v8)
# Dropping those two removes V8 from the dependency graph entirely.
#
# This edits moon.work IN PLACE (no restore) — intended for ephemeral CI
# runners and for callers that manage their own backup (see
# scripts/moon-test-no-v8.sh). It is idempotent: re-running drops nothing more.
#
# Usage:
#   bash scripts/ci/drop-v8-members.sh                # edits ./moon.work
#   bash scripts/ci/drop-v8-members.sh path/to/moon.work
set -euo pipefail

work="${1:-moon.work}"
if [[ ! -f "$work" ]]; then
  echo "error: $work not found" >&2
  exit 1
fi

# The two members that transitively pull mizchi/v8. Keep this list in sync with
# the dependency graph (a new direct consumer of mizchi/v8 must be added here).
v8_member_re='^[[:space:]]*"\./(browser/native|testing)",[[:space:]]*$'

before="$(grep -cE "$v8_member_re" "$work" || true)"
if [[ "$before" -eq 0 ]]; then
  echo "[drop-v8-members] no V8-pulling members present in $work (already trimmed)" >&2
  exit 0
fi

tmp="$(mktemp)"
grep -vE "$v8_member_re" "$work" >"$tmp"
mv "$tmp" "$work"
echo "[drop-v8-members] dropped $before V8-pulling member(s) from $work" >&2
