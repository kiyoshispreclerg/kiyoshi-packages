#!/bin/bash
# Build XiS and everything it needs that the distro doesn't have, into PREFIX
# (default /opt/xis):
#
#   1. xorgproto   (headers, build-time only)
#   2. libdrm      (shipped in PREFIX/lib, found through RUNPATH)
#   3. the XiS X server (cloned from XIS_URL at XIS_REF, see versions.sh)
#   4. xf86-input-libinput, built against (3)
#
# Each piece is installed twice: really into PREFIX, because the next one needs
# it, and into DESTDIR=STAGE, which is what gets packaged later.
#
# Environment:
#   PREFIX        install prefix                      (default /opt/xis)
#   LOCALSTATEDIR variable data dir                   (default /var/opt/xis)
#   WORK          scratch dir                         (default ./packaging-work)
#   STAGE         staging tree                        (default $WORK/stage)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../versions.sh"

PREFIX="${PREFIX:-$XIS_PREFIX_DEFAULT}"
LOCALSTATEDIR="${LOCALSTATEDIR:-/var/opt/xis}"
WORK="${WORK:-$PWD/packaging-work}"
STAGE="${STAGE:-$WORK/stage}"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "$WORK/src" "$WORK/build" "$STAGE"
repo="$WORK/src/xis"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
# Binaries and modules find our libdrm (and nothing else) through RUNPATH.
export LDFLAGS="-Wl,-rpath,$PREFIX/lib${LDFLAGS:+ $LDFLAGS}"

# fetch_git NAME URL REF  -> $WORK/src/NAME (REF can be a tag or a full sha)
fetch_git() {
    local dir="$WORK/src/$1"
    rm -rf "$dir"
    git init -q "$dir"
    git -C "$dir" remote add origin "$2"
    git -C "$dir" fetch -q --depth 1 origin "$3"
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

# install_both BUILDDIR
install_both() {
    ninja -C "$1" install
    DESTDIR="$STAGE" ninja -C "$1" install
}

step() { printf '\n==== %s\n' "$*"; }

step "xorgproto @ $XORGPROTO_REF"
fetch_git xorgproto "$XORGPROTO_URL" "$XORGPROTO_REF"
meson setup "$WORK/build/xorgproto" "$WORK/src/xorgproto" \
    --prefix="$PREFIX" --libdir=lib --buildtype=release
install_both "$WORK/build/xorgproto"

step "libdrm @ $LIBDRM_REF"
fetch_git libdrm "$LIBDRM_URL" "$LIBDRM_REF"
meson setup "$WORK/build/libdrm" "$WORK/src/libdrm" \
    --prefix="$PREFIX" --libdir=lib --buildtype=release \
    -Dtests=false -Dman-pages=disabled -Dvalgrind=disabled -Dcairo-tests=disabled
ninja -C "$WORK/build/libdrm" -j"$JOBS"
install_both "$WORK/build/libdrm"

step "XiS X server @ $XIS_REF"
fetch_git xis "$XIS_URL" "$XIS_REF"
# Config/state paths: the server also reads /etc/X11/xorg.conf(.d) as usual.
# xkb data and the xkbcomp binary come from the distro; compiled keymaps go to
# a directory of our own so we don't share a cache with the distro's Xorg.
meson setup "$WORK/build/xis" "$repo" \
    --prefix="$PREFIX" --libdir=lib --buildtype=release \
    --sysconfdir="$PREFIX/etc" --localstatedir="$LOCALSTATEDIR" \
    -Dxorg=true -Dxvfb=true -Dxephyr=false -Dxnest=false -Dxfbdev=false \
    -Dglamor=true -Dglx=true -Ddri3=true -Dxcsecurity=true -Dlibunwind=true \
    -Dsystemd_logind=true -Dseatd_libseat=false -Dsystemd_notify=false \
    -Dudev=true -Dudev_kms=true \
    -Dxkb_dir=/usr/share/X11/xkb -Dxkb_bin_dir=/usr/bin \
    -Dxkb_output_dir="$LOCALSTATEDIR/xkb" \
    -Ddefault_font_path="catalogue:/etc/X11/fontpath.d,built-ins" \
    -Dtests=false -Ddocs=false -Ddevel-docs=false
ninja -C "$WORK/build/xis" -j"$JOBS"
install_both "$WORK/build/xis"

step "xf86-input-libinput @ $LIBINPUT_DRIVER_REF"
fetch_git libinput-driver "$LIBINPUT_DRIVER_URL" "$LIBINPUT_DRIVER_REF"
meson setup "$WORK/build/libinput-driver" "$WORK/src/libinput-driver" \
    --prefix="$PREFIX" --libdir=lib --buildtype=release
ninja -C "$WORK/build/libinput-driver" -j"$JOBS"
install_both "$WORK/build/libinput-driver"

{
    echo "prefix=$PREFIX"
    echo "xorgproto=$XORGPROTO_REF"
    echo "libdrm=$LIBDRM_REF"
    echo "libinput_driver=$LIBINPUT_DRIVER_REF"
    echo "xis=$(git -C "$repo" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$WORK/BUILD-INFO"

step "done: installed in $PREFIX, staged in $STAGE"
