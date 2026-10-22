#!/bin/bash
# Build dependencies for xis/scripts/build-xis.sh on Ubuntu 22.04/24.04
# and Debian 12/13. Every name below exists on all four.
#
# Not listed on purpose: x11proto-dev / libdrm-dev (built from source into the
# prefix), libseat-dev (logind is used), libsystemd-dev.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    build-essential git ca-certificates meson ninja-build pkg-config python3 \
    libpciaccess-dev libpixman-1-dev libxfont-dev libxkbfile-dev libxcvt-dev \
    libudev-dev libdbus-1-dev libepoxy-dev libgbm-dev libegl-dev libgl-dev \
    libxshmfence-dev nettle-dev libunwind-dev libselinux1-dev libaudit-dev \
    libbsd-dev libxdmcp-dev libxau-dev libx11-dev libinput-dev \
    x11-utils xauth xkb-data x11-xkb-utils
