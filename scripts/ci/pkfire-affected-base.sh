#!/usr/bin/env bash
set -euo pipefail

zero_sha="0000000000000000000000000000000000000000"

if [[ -n "${PKF_AFFECTED_BASE:-}" ]]; then
  git rev-parse --verify "${PKF_AFFECTED_BASE}^{commit}" >/dev/null
  git rev-parse "${PKF_AFFECTED_BASE}^{commit}"
  exit 0
fi

if [[ "${GITHUB_EVENT_NAME:-}" == pull_request* && -n "${GITHUB_BASE_REF:-}" ]]; then
  git fetch --no-tags --prune origin "${GITHUB_BASE_REF}" >/dev/null 2>&1 || true
  if git rev-parse --verify "origin/${GITHUB_BASE_REF}^{commit}" >/dev/null 2>&1; then
    git merge-base HEAD "origin/${GITHUB_BASE_REF}"
    exit 0
  fi
fi

if [[ -n "${GITHUB_EVENT_BEFORE:-}" && "${GITHUB_EVENT_BEFORE}" != "${zero_sha}" ]]; then
  if git rev-parse --verify "${GITHUB_EVENT_BEFORE}^{commit}" >/dev/null 2>&1; then
    git rev-parse "${GITHUB_EVENT_BEFORE}^{commit}"
    exit 0
  fi
fi

if git rev-parse --verify "origin/main^{commit}" >/dev/null 2>&1; then
  git rev-parse "origin/main^{commit}"
  exit 0
fi

git rev-parse "HEAD~1^{commit}"
