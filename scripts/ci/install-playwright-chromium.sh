#!/usr/bin/env bash
# Install Playwright's Chromium and its system libraries for CI without invoking
# Playwright's own browser downloader, which hangs on these runners.
#
# Symptom: `playwright install chromium` prints the download, the byte counter
# reaches 100%, and then the process stalls for the entire timeout — identically
# on every retry, and (as proven by routing the download through a localhost
# mirror) regardless of where the bytes come from. So the stall is not the
# network: it is Playwright's post-download phase (the out-of-process
# download/extract child in oopDownloadBrowserMain.js — finalising the stream
# and/or `extract`ing the archive) wedging on these runners. Because it fails at
# the same point every attempt, retry/timeout cannot recover it, and the
# actions/cache layer cannot help either: the cache only populates after a
# *successful* install, which never happens — a chicken-and-egg deadlock.
#
# Fix: bypass Playwright's downloader and extractor entirely. `curl` fetches each
# artifact (it finalises connections correctly) and `unzip` extracts it straight
# into the install directory Playwright expects. Because we extract the very same
# archive Playwright would, the on-disk layout is identical, the executable bit
# is preserved by the zip, and writing the INSTALLATION_COMPLETE marker is all
# Playwright needs to treat the browser as installed (see registry index.js:1246
# and oopDownloadBrowserMain.js). Install locations and URLs come from `playwright
# install --dry-run`, so nothing here is pinned to a browser revision.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

deps_timeout="${PLAYWRIGHT_DEPS_TIMEOUT:-300}"

# --- System libraries -------------------------------------------------------
# Install the system libraries Chromium needs to *run*, separately from the
# browser binary. The runners already ship these (apt reports "0 upgraded"), so
# a stall or failure here is bounded and non-fatal.
echo "::group::playwright install-deps chromium"
deps_status=0
timeout "${deps_timeout}" pnpm exec playwright install-deps chromium || deps_status=$?
echo "::endgroup::"
if [ "$deps_status" -ne 0 ]; then
  echo "playwright install-deps chromium exited ${deps_status}; continuing (runner libs are preinstalled)" >&2
fi

# --- Resolve which artifacts to fetch, and to where -------------------------
# Each `chromium` install pulls chromium, chrome-headless-shell and ffmpeg. Pair
# every "Install location:" with its primary "Download url:" (dedupe — ffmpeg is
# listed twice).
echo "::group::resolve playwright artifacts"
dry_run="$(pnpm exec playwright install --dry-run chromium 2>/dev/null || true)"
echo "$dry_run"
echo "::endgroup::"

mapfile -t pairs < <(printf '%s\n' "$dry_run" | awk '
  /Install location:/ { loc = $3 }
  /Download url:/ && loc != "" { print loc "\t" $3; loc = "" }
' | sort -u)

if [ "${#pairs[@]}" -eq 0 ]; then
  echo "could not resolve Playwright artifacts from --dry-run output" >&2
  exit 1
fi

tmp_zips="$(mktemp -d)"
trap 'rm -rf "$tmp_zips"' EXIT

# --- Fetch + extract each artifact ------------------------------------------
for pair in "${pairs[@]}"; do
  loc="${pair%%$'\t'*}"
  url="${pair#*$'\t'}"
  zip="${tmp_zips}/$(basename "${url%%\?*}")"

  echo "::group::install $(basename "$loc")"
  echo "curl ${url}"
  # curl finalises the connection correctly where Playwright's downloader stalls.
  if ! curl --fail --location --show-error --silent \
            --retry 5 --retry-all-errors --retry-delay 2 \
            --connect-timeout 30 --max-time 600 \
            --output "$zip" "$url"; then
    echo "failed to download ${url}" >&2
    exit 1
  fi

  # Mirror Playwright: clear any partial directory, then extract the archive
  # into the install location (the zip's own top-level dir lands inside it).
  rm -rf "$loc"
  mkdir -p "$loc"
  if ! unzip -q -o "$zip" -d "$loc"; then
    echo "failed to extract $(basename "$zip") into ${loc}" >&2
    exit 1
  fi
  # Marker file is what registry.isInstalled() checks; without it Playwright
  # would try to re-download (and re-hang).
  : > "${loc}/INSTALLATION_COMPLETE"
  echo "::endgroup::"
done

# --- Validate ---------------------------------------------------------------
# Resolve Chromium's executable through Playwright itself, harden its mode bit
# (unzip preserves it, but be explicit), and confirm it is present.
echo "::group::validate chromium install"
chrome_path="$(pnpm exec node -e 'process.stdout.write(require("playwright").chromium.executablePath())')"
echo "chromium executable: ${chrome_path}"
if [ ! -f "$chrome_path" ]; then
  echo "expected Chromium executable missing after install: ${chrome_path}" >&2
  exit 1
fi
chmod 0755 "$chrome_path"
echo "::endgroup::"

echo "Chromium installed via curl + unzip (Playwright downloader bypassed)"
