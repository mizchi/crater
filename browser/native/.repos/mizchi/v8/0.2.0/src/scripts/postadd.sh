#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/../.." && pwd)
stamp_path="$root_dir/src/build-stamps/rusty_v8_build.stamp"

echo "[mizchi/v8] building native bridge via postadd hook" >&2
bash "$root_dir/src/scripts/build-rusty-v8.sh" "$stamp_path"
echo "[mizchi/v8] consumer setup helper: node .mooncakes/mizchi/v8/src/scripts/setup-consumer.mjs --main-pkg cmd/main/moon.pkg" >&2
