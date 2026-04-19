#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-18080}"
VUS="${VUS:-128}"
DURATION="${DURATION:-20s}"
BODY_SIZE="${BODY_SIZE:-16384}"
BASE_URL="http://127.0.0.1:${PORT}"
TARGETS="${TARGETS:-js native}"

JS_RESULT_SUMMARY="${JS_RESULT_SUMMARY:-/tmp/k6_js_summary.json}"
NATIVE_RESULT_SUMMARY="${NATIVE_RESULT_SUMMARY:-/tmp/k6_native_summary.json}"
COMPARE_SUMMARY="${COMPARE_SUMMARY:-/tmp/k6_http_compare_summary.json}"
SERVER_LOG_DIR="${SERVER_LOG_DIR:-/tmp}"
SERVER_PID=""

stop_server() {
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
    SERVER_PID=""
  fi
}

cleanup() {
  stop_server
}
trap cleanup EXIT

wait_server_ready() {
  local server_log="$1"
  for _ in $(seq 1 150); do
    if curl -fsS "${BASE_URL}/ping" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  echo "[bench] server did not become ready: ${server_log}" >&2
  tail -n 80 "${server_log}" >&2 || true
  return 1
}

render_target_summary() {
  local ping_summary="$1"
  local consume_summary="$2"
  local discard_summary="$3"
  local out_summary="$4"
  jq -n \
    --slurpfile ping "${ping_summary}" \
    --slurpfile consume "${consume_summary}" \
    --slurpfile discard "${discard_summary}" \
    '{
      ping: {
        req_rate: $ping[0].metrics.http_reqs.rate,
        avg_ms: $ping[0].metrics.http_req_duration.avg,
        p95_ms: $ping[0].metrics.http_req_duration["p(95)"]
      },
      consume: {
        req_rate: $consume[0].metrics.http_reqs.rate,
        avg_ms: $consume[0].metrics.http_req_duration.avg,
        p95_ms: $consume[0].metrics.http_req_duration["p(95)"]
      },
      discard: {
        req_rate: $discard[0].metrics.http_reqs.rate,
        avg_ms: $discard[0].metrics.http_req_duration.avg,
        p95_ms: $discard[0].metrics.http_req_duration["p(95)"]
      }
    }' >"${out_summary}"
}

run_for_target() {
  local target="$1"
  local out_summary="$2"
  local ping_summary="/tmp/k6_${target}_ping_summary.json"
  local consume_summary="/tmp/k6_${target}_consume_summary.json"
  local discard_summary="/tmp/k6_${target}_discard_summary.json"
  local server_log="${SERVER_LOG_DIR}/httpbench_${target}.log"

  rm -f "${ping_summary}" "${consume_summary}" "${discard_summary}" "${out_summary}"

  echo "[bench] starting target=${target}"
  cd "${ROOT_DIR}"
  PORT="${PORT}" moon run --target "${target}" src/httpbench --release >"${server_log}" 2>&1 &
  SERVER_PID=$!

  wait_server_ready "${server_log}"

  BASE_URL="${BASE_URL}" VUS="${VUS}" DURATION="${DURATION}" \
    k6 run --summary-export "${ping_summary}" scripts/k6/http_ping.js
  BASE_URL="${BASE_URL}" VUS="${VUS}" DURATION="${DURATION}" BODY_SIZE="${BODY_SIZE}" \
    k6 run --summary-export "${consume_summary}" scripts/k6/http_consume.js
  BASE_URL="${BASE_URL}" VUS="${VUS}" DURATION="${DURATION}" BODY_SIZE="${BODY_SIZE}" \
    k6 run --summary-export "${discard_summary}" scripts/k6/http_discard.js

  stop_server
  render_target_summary "${ping_summary}" "${consume_summary}" "${discard_summary}" "${out_summary}"
  echo "[bench] target=${target} summary=${out_summary}"
  jq . "${out_summary}"
}

run_js=false
run_native=false
for target in ${TARGETS}; do
  case "${target}" in
    js)
      run_for_target "js" "${JS_RESULT_SUMMARY}"
      run_js=true
      ;;
    native)
      run_for_target "native" "${NATIVE_RESULT_SUMMARY}"
      run_native=true
      ;;
    *)
      echo "unsupported target: ${target}" >&2
      exit 1
      ;;
  esac
done

if [[ "${run_js}" == "true" && "${run_native}" == "true" ]]; then
  jq -n \
    --slurpfile js "${JS_RESULT_SUMMARY}" \
    --slurpfile native "${NATIVE_RESULT_SUMMARY}" \
    '
    def ratio(a; b): if (b == null or b == 0) then null else a / b end;
    {
      js: $js[0],
      native: $native[0],
      compare: {
        ping: {
          req_rate_ratio_js_over_native: ratio($js[0].ping.req_rate; $native[0].ping.req_rate),
          avg_ms_ratio_js_over_native: ratio($js[0].ping.avg_ms; $native[0].ping.avg_ms),
          p95_ms_ratio_js_over_native: ratio($js[0].ping.p95_ms; $native[0].ping.p95_ms)
        },
        consume: {
          req_rate_ratio_js_over_native: ratio($js[0].consume.req_rate; $native[0].consume.req_rate),
          avg_ms_ratio_js_over_native: ratio($js[0].consume.avg_ms; $native[0].consume.avg_ms),
          p95_ms_ratio_js_over_native: ratio($js[0].consume.p95_ms; $native[0].consume.p95_ms)
        },
        discard: {
          req_rate_ratio_js_over_native: ratio($js[0].discard.req_rate; $native[0].discard.req_rate),
          avg_ms_ratio_js_over_native: ratio($js[0].discard.avg_ms; $native[0].discard.avg_ms),
          p95_ms_ratio_js_over_native: ratio($js[0].discard.p95_ms; $native[0].discard.p95_ms)
        }
      }
    }' | tee "${COMPARE_SUMMARY}"
elif [[ "${run_js}" == "true" ]]; then
  cat "${JS_RESULT_SUMMARY}"
elif [[ "${run_native}" == "true" ]]; then
  cat "${NATIVE_RESULT_SUMMARY}"
else
  echo "no targets selected" >&2
  exit 1
fi
