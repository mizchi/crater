#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  fontconfig \
  fonts-liberation2 \
  cabextract \
  xfonts-utils

if ! apt-cache show ttf-mscorefonts-installer >/dev/null 2>&1; then
  sudo apt-get install -y --no-install-recommends software-properties-common
  sudo add-apt-repository -y multiverse
  sudo apt-get update
fi

echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections
sudo apt-get install -y --no-install-recommends ttf-mscorefonts-installer

sudo fc-cache -f

required_files=(
  "Arial.ttf"
  "Verdana.ttf"
  "Georgia.ttf"
  "Times_New_Roman.ttf"
  "Courier_New.ttf"
)

for file_name in "${required_files[@]}"; do
  if ! find /usr/share/fonts -type f -name "${file_name}" | grep -q .; then
    echo "::error title=Missing compatible font::${file_name} was not installed"
    exit 1
  fi
done

for family in "Arial" "Verdana" "Georgia" "Times New Roman" "Courier New"; do
  echo "[font-ci] ${family} => $(fc-match -f '%{file}\n' "${family}" || true)"
done
