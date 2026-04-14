#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <log-name> <command...>" >&2
  exit 2
fi

log_name="$1"
shift

mkdir -p ci-logs
log_path="ci-logs/${log_name}.log"

dump_prelude() {
  echo "== date =="
  date -u +"%Y-%m-%dT%H:%M:%SZ"
  echo
  echo "== uname =="
  uname -a
  echo
  echo "== pwd =="
  pwd
  echo
  echo "== moon version =="
  moon version --all || true
  echo
  echo "== command =="
  printf '%q ' "$@"
  echo
}

run_and_capture() {
  local status
  set +e
  (
    dump_prelude "$@"
    echo
    echo "== output =="
    "$@"
  ) 2>&1 | tee "$log_path"
  status=${PIPESTATUS[0]}
  set -e
  return "$status"
}

run_with_trace() {
  local status
  set +e
  (
    echo
    echo "== retry with --trace --verbose =="
    printf '%q ' "$@" --trace -v
    echo
    "$@" --trace -v
  ) 2>&1 | tee -a "$log_path"
  status=${PIPESTATUS[0]}
  set -e
  return "$status"
}

if run_and_capture "$@"; then
  exit 0
fi

run_with_trace "$@"
