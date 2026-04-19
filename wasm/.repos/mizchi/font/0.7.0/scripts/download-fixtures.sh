#!/usr/bin/env bash
set -euo pipefail

REPO="mizchi/font"
TAG="fixtures-v1"
ASSET="noto-fixtures.tar.gz"
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -f "$DIR/fixtures/NotoSansMono-Regular.ttf" ]; then
  echo "NotoSans fixtures already exist, skipping download"
  exit 0
fi

echo "Downloading NotoSans fixtures from $REPO release $TAG..."
cd "$DIR"

if command -v gh &>/dev/null; then
  gh release download "$TAG" --repo "$REPO" --pattern "$ASSET" --dir /tmp --clobber
else
  curl -fsSL -o /tmp/"$ASSET" \
    "https://github.com/$REPO/releases/download/$TAG/$ASSET"
fi

tar xzf /tmp/"$ASSET"
rm -f /tmp/"$ASSET"
echo "NotoSans fixtures extracted successfully"
