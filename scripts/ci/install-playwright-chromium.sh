#!/usr/bin/env bash
# Install Playwright's Chromium and its system libraries for CI, working around
# a deterministic stall in Playwright's own browser downloader.
#
# Symptom (observed on every strict WPT gate and the playwright-bidi job):
# `playwright install chromium` prints the Chrome-for-Testing download, the byte
# counter reaches 100% in ~2s, and then the process hangs in the post-download
# phase for the entire timeout — identically on all retries. The bytes arrive
# fine; it is Node's HTTP stream finalisation against cdn.playwright.dev that
# never settles (the socket does not close at 100%). Because it fails at the same
# point every attempt, retry/timeout cannot recover it, and the actions/cache
# layer cannot help either: the cache only populates after a *successful*
# install, which never happens — a chicken-and-egg deadlock.
#
# Fix: bypass Playwright's flaky downloader without re-implementing its on-disk
# layout. `curl` fetches each artifact (curl finalises the connection correctly),
# we serve the fetched files on localhost, and point Playwright at localhost via
# PLAYWRIGHT_DOWNLOAD_HOST. Playwright then performs its own extraction and writes
# its INSTALLATION_COMPLETE marker, so the result is byte-for-byte what a normal
# install produces — just sourced over a connection that actually closes.
#
# The artifact list and URLs are read from `playwright install --dry-run` so
# nothing here is pinned to a browser revision. PLAYWRIGHT_DOWNLOAD_HOST replaces
# the mirror host but keeps Playwright's bare download *path*, which does not
# match a mirror URL that carries its own path prefix (e.g. ffmpeg's
# `dbazure/download/playwright/...`). Each artifact's zip basename is unique,
# however, so the localhost server resolves requests by basename and is immune to
# whatever prefix Playwright asks for.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
# Keep any browser restored from actions/cache instead of GC'ing and
# re-downloading it on every invocation.
export PLAYWRIGHT_SKIP_BROWSER_GC=1

attempts="${PLAYWRIGHT_INSTALL_ATTEMPTS:-3}"
per_attempt_timeout="${PLAYWRIGHT_INSTALL_TIMEOUT:-420}"
deps_timeout="${PLAYWRIGHT_DEPS_TIMEOUT:-300}"

# --- System libraries -------------------------------------------------------
# Install the system libraries once, separately from the browser. The runners
# already ship these (apt reports "0 upgraded"), so a stall or failure here is
# bounded and non-fatal — the browser install below is what actually matters.
echo "::group::playwright install-deps chromium"
deps_status=0
timeout "${deps_timeout}" pnpm exec playwright install-deps chromium || deps_status=$?
echo "::endgroup::"
if [ "$deps_status" -ne 0 ]; then
  echo "playwright install-deps chromium exited ${deps_status}; continuing (runner libs are preinstalled)" >&2
fi

# --- Pre-fetch artifacts over curl, serve them on localhost -----------------
mirror_root="$(mktemp -d)"
server_pid=""
cleanup() {
  if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$mirror_root"
}
trap cleanup EXIT

# Ask Playwright (not a hard-coded revision) which artifacts a `chromium` install
# pulls and from which URLs. Each primary "Download url:" line is one artifact.
echo "::group::resolve playwright download URLs"
dry_run="$(pnpm exec playwright install --dry-run chromium 2>/dev/null || true)"
echo "$dry_run"
echo "::endgroup::"

mapfile -t urls < <(printf '%s\n' "$dry_run" | awk '/Download url:/ {print $3}' | sort -u)

mirror_ready=false
if [ "${#urls[@]}" -gt 0 ]; then
  mirror_ready=true
  echo "::group::pre-fetch ${#urls[@]} artifact(s) via curl"
  for url in "${urls[@]}"; do
    # Serve by basename: Playwright requests the artifact under its own path, but
    # the zip filename is the same regardless of mirror prefix.
    dest="${mirror_root}/$(basename "${url%%\?*}")"
    echo "curl ${url} -> $(basename "$dest")"
    # curl handles connection finalisation correctly where Node's fetch stalls.
    if ! curl --fail --location --show-error --silent \
              --retry 5 --retry-all-errors --retry-delay 2 \
              --connect-timeout 30 --max-time 600 \
              --output "$dest" "$url"; then
      echo "curl failed for ${url}; falling back to direct playwright install" >&2
      mirror_ready=false
      break
    fi
  done
  echo "::endgroup::"
fi

if [ "$mirror_ready" = true ]; then
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"

  # Minimal static server that resolves every request to a prefetched file by
  # basename, so it does not matter which path prefix Playwright requests.
  read -r -d '' server_py <<'PY' || true
import http.server, os, sys
root, port = sys.argv[1], int(sys.argv[2])
files = {f: os.path.join(root, f) for f in os.listdir(root)}
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        name = os.path.basename(self.path.split('?')[0])
        path = files.get(name)
        if not path or not os.path.exists(path):
            self.send_error(404); return
        self.send_response(200)
        self.send_header('Content-Length', str(os.path.getsize(path)))
        self.end_headers()
        with open(path, 'rb') as fh:
            while True:
                chunk = fh.read(1 << 20)
                if not chunk:
                    break
                self.wfile.write(chunk)
    def log_message(self, *a):
        pass
http.server.HTTPServer(('127.0.0.1', port), H).serve_forever()
PY
  python3 -c "$server_py" "$mirror_root" "$port" &
  server_pid=$!

  # Wait for the server to accept connections (a 404 still means it is up).
  for _ in $(seq 1 50); do
    if curl --silent --output /dev/null "http://127.0.0.1:${port}/ping"; then
      break
    fi
    sleep 0.2
  done

  export PLAYWRIGHT_DOWNLOAD_HOST="http://127.0.0.1:${port}"
  echo "serving prefetched browsers at ${PLAYWRIGHT_DOWNLOAD_HOST}"
fi

# --- Install the browser ----------------------------------------------------
# With the mirror in place this is a fast localhost copy + extract; without it
# (parse/curl fallback) it degrades to the prior bounded-retry direct install.
for attempt in $(seq 1 "$attempts"); do
  echo "::group::playwright install chromium (attempt ${attempt}/${attempts})"
  status=0
  timeout "${per_attempt_timeout}" pnpm exec playwright install chromium || status=$?
  echo "::endgroup::"

  if [ "$status" -eq 0 ]; then
    exit 0
  fi
  if [ "$status" -eq 124 ]; then
    echo "attempt ${attempt} timed out after ${per_attempt_timeout}s" >&2
  else
    echo "attempt ${attempt} failed with exit ${status}" >&2
  fi
  sleep $((attempt * 5))
done

echo "playwright install chromium failed after ${attempts} attempts" >&2
exit 1
