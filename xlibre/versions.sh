# Where the code and the Debian packaging come from.
#
# Code: always the official X11Libre repositories, by tag. A ref written as
#   latest:<regex>
# means "the newest tag whose whole name matches <regex>" (version order).
# Packaging: the debian/ directories of NexusSfan's repositories
# (github.com/xlibre-debian/<source>), copied into xlibre/packaging/ and put
# around the official tree of the tag. The builds read only that copy;
# PACKAGING_BASE and the *PACKAGING_REF values below are used just by
# scripts/vendor-packaging.sh, to refresh it.
UPSTREAM_BASE="${UPSTREAM_BASE:-https://github.com/X11Libre}"
PACKAGING_BASE="${PACKAGING_BASE:-https://github.com/xlibre-debian}"
PACKAGING_REF="${PACKAGING_REF:-xlibre/latest}"

# ---- the X server, per channel -------------------------------------------------
SERVER_URL="$UPSTREAM_BASE/xserver.git"
# beta   = XLibre 25.2.x
BETA_REF="${BETA_REF:-latest:xlibre-xserver-25\.2\.[0-9]+}"
# stable = XLibre 25.1.x. Its packaging is the one NexusSfan had for 25.1.7: the
# 25.2 one expects files the 25.1 tree does not have.
STABLE_REF="${STABLE_REF:-latest:xlibre-xserver-25\.1\.[0-9]+}"
STABLE_PACKAGING_REF=2eefc79ccda036c06ab717d1302bc179f695d1e7   # debian/ at 2:25.1.7-1

# ---- XiS -----------------------------------------------------------------------
# The Kiyoshi fork of XLibre, packaged as xserver-xis-core: a drop-in alternative
# to xserver-xlibre-core in both channels. It is built from the fork's tag that
# matches the XLibre tag of the channel: xlibre-xserver-25.1.10 -> xis-xserver-25.1.10
# (test-xis-release-25.1 for stable, test-xis-release-25.2 for beta). If the fork
# has no such tag yet, XiS is skipped for that channel with a warning.
XIS_URL="${XIS_URL:-https://github.com/kiyoshispreclerg/xserver.git}"
