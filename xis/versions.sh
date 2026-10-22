# Pinned inputs for the /opt/xis build. Sourced by the scripts in xis/scripts.

XIS_PREFIX_DEFAULT=/opt/xis

# Build-time only: the distros ship xorgproto older than the presentproto 1.4 /
# fixesproto 6.1 that meson.build requires (only Debian 13 is new enough).
XORGPROTO_URL=https://github.com/X11Libre/mirror.fdo.xorgproto.git
XORGPROTO_REF=cc9ce4a0cc3c99488d26b77a4f27192b0663cafa

# Shipped in $PREFIX/lib so every target gets the same libdrm (>= 2.4.122
# enables LIBDRM_HAS_PLANE_SIZE_HINTS, which Ubuntu 22.04 / Debian 12 lack).
LIBDRM_URL=https://github.com/X11Libre/mirror.fdo.drm.git
LIBDRM_REF=libdrm-2.4.123

# Same version the XLibre Debian packages ship.
LIBINPUT_DRIVER_URL=https://github.com/X11Libre/xf86-input-libinput.git
LIBINPUT_DRIVER_REF=xlibre-xf86-input-libinput-25.0.1

# The XiS server itself. REF is a branch, tag or full sha; override from the
# environment (or workflow_dispatch input) to build something else.
XIS_URL="${XIS_URL:-https://github.com/kiyoshispreclerg/xserver.git}"
XIS_REF="${XIS_REF:-experiments}"
