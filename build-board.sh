#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Build the firmware image for the Raspberry Pi 4 (rpi_4b/bcm2711) with the OpenGL ES (YakoGL) settings.
#
# Usage: ./build-board.sh [build-directory]     (default: ./build-board)
#
# Required environment variables (no defaults; the paths are specific to each machine):
#   ZEPHYR_WORKSPACE     west workspace that contains zephyr/ (ZEPHYR_BASE is $ZEPHYR_WORKSPACE/zephyr)
#   ZEPHYR_VENV          python venv of that workspace (the one that has west)
#   ZEPHYR_SDK_DIR       Zephyr SDK install directory
#   QT6_FOR_ZEPHYR       the zephyr-module directory of signal-slot/qt6-for-zephyr
#   QT_ZEPHYR_PREFIX     install prefix of the static Qt 6.12 cross build for Zephyr (Graphs enabled)
#   QT_HOST_PATH         install prefix of the host Qt of the same version
#   YAKOGL               YakoGL source tree (see "YakoGL" in README.md: the Qt Graphs lines need a change)
# Optional:
#   RUSTUP_TOOLCHAIN     Rust toolchain for YakoGL (default: nightly)
#
# The output is <build-directory>/zephyr/zephyr.bin. Writing it to the SD card is not done here.
set -euo pipefail

for v in ZEPHYR_WORKSPACE ZEPHYR_VENV ZEPHYR_SDK_DIR QT6_FOR_ZEPHYR QT_ZEPHYR_PREFIX QT_HOST_PATH YAKOGL; do
  if [ -z "${!v:-}" ]; then
    echo "error: $v is not set (see the header of $0)" >&2
    exit 1
  fi
done

APP=$(cd "$(dirname "$0")" && pwd)
B=${1:-$APP/build-board}
M=$QT6_FOR_ZEPHYR

# shellcheck disable=SC1091
source "$ZEPHYR_VENV/bin/activate"
cd "$ZEPHYR_WORKSPACE/zephyr"
export ZEPHYR_BASE=$PWD ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR=$ZEPHYR_SDK_DIR
export RUSTUP_TOOLCHAIN=${RUSTUP_TOOLCHAIN:-nightly}
export QT_ZEPHYR_PREFIX

west build -p auto -b rpi_4b/bcm2711 -d "$B" "$M/qt-app" -- \
  -DZEPHYR_EXTRA_MODULES="$M;$YAKOGL" \
  -DQT_APP_DIR="$APP" \
  -DQT_HOST_PATH="$QT_HOST_PATH" \
  "-DEXTRA_CONF_FILE=$M/qt-app/boards/rpi_4b_bcm2711_gl.conf;$APP/zephyr/sensehat.conf" \
  "-DEXTRA_DTC_OVERLAY_FILE=$M/qt-app/boards/rpi_4b_bcm2711_gl.overlay;$APP/zephyr/sensehat.overlay"
