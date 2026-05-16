#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

prepare_mscorefonts_dirs() {
  sudo mkdir -p /var/lib/update-notifier/package-data-downloads/partial
}

install_mscorefonts() {
  echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections
  prepare_mscorefonts_dirs
  sudo apt-get install -y --no-install-recommends ttf-mscorefonts-installer
}

recover_mscorefonts_install() {
  prepare_mscorefonts_dirs
  sudo rm -f /var/lib/update-notifier/package-data-downloads/partial/* || true
  sudo apt-get install -f -y || true
  sudo apt-get install -y --reinstall --no-install-recommends ttf-mscorefonts-installer || true
  sudo dpkg-reconfigure ttf-mscorefonts-installer || true
}

has_font_file() {
  local file_name="$1"
  find /usr/share/fonts -type f -name "${file_name}" | grep -q .
}

verify_required_fonts() {
  local file_name
  for file_name in "${required_files[@]}"; do
    if ! has_font_file "${file_name}"; then
      return 1
    fi
  done
}

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  fontconfig \
  fonts-liberation2 \
  fonts-roboto \
  fonts-noto-core \
  cabextract \
  xfonts-utils

if ! apt-cache show ttf-mscorefonts-installer >/dev/null 2>&1; then
  sudo apt-get install -y --no-install-recommends software-properties-common
  sudo add-apt-repository -y multiverse
  sudo apt-get update
fi

required_files=(
  "Arial.ttf"
  "Verdana.ttf"
  "Georgia.ttf"
  "Times_New_Roman.ttf"
  "Courier_New.ttf"
)

# Medium / non-default weight files supplied by fonts-roboto and
# fonts-noto-core. paint.font-weight-numeric (GitHub issue #48) needs at
# least one of these on disk so FONT_FILE_MAP.byWeight in
# webdriver/bidi_main/start-with-font.ts can populate FontEntry.byWeight
# with a real medium face. Required at least one in the list, not all.
medium_weight_files=(
  "Roboto-Medium.ttf"
  "Roboto-Light.ttf"
  "NotoSans-Medium.ttf"
  "NotoSans-SemiBold.ttf"
)

for attempt in 1 2 3; do
  if install_mscorefonts; then
    sudo fc-cache -f
    if verify_required_fonts; then
      break
    fi
  fi

  echo "[font-ci] compatible font install attempt ${attempt} did not produce all required files"
  recover_mscorefonts_install
  sudo fc-cache -f
done

for file_name in "${required_files[@]}"; do
  if ! has_font_file "${file_name}"; then
    echo "::error title=Missing compatible font::${file_name} was not installed"
    exit 1
  fi
done

for family in "Arial" "Verdana" "Georgia" "Times New Roman" "Courier New"; do
  echo "[font-ci] ${family} => $(fc-match -f '%{file}\n' "${family}" || true)"
done

# Verify at least one medium-weight face landed so paint.font-weight-numeric
# Layer B has something to dispatch to.
found_medium=0
for file_name in "${medium_weight_files[@]}"; do
  if has_font_file "${file_name}"; then
    echo "[font-ci] medium-weight font available: ${file_name}"
    found_medium=1
  fi
done
if [ "${found_medium}" -eq 0 ]; then
  echo "::warning title=No medium-weight font found::None of ${medium_weight_files[*]} are installed; font-weight: 500 will fall back to regular"
fi
