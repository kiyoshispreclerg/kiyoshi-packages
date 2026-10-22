# Where the code and the Debian packaging come from.
#
# Code: always the official X11Libre repositories, by tag. A ref written as
#   latest:<regex>
# means "the newest tag whose whole name matches <regex>" (version order).
# Packaging: only the debian/ directory of NexusSfan's repositories
# (github.com/xlibre-debian/<source>, branch xlibre/latest), put around the
# official tree of the tag.
UPSTREAM_BASE="${UPSTREAM_BASE:-https://github.com/X11Libre}"
PACKAGING_BASE="${PACKAGING_BASE:-https://github.com/xlibre-debian}"
PACKAGING_REF="${PACKAGING_REF:-xlibre/latest}"

# ---- the X server, per channel -------------------------------------------------
SERVER_URL="$UPSTREAM_BASE/xserver.git"
# beta   = XLibre 25.2.x
BETA_REF="${BETA_REF:-latest:xlibre-xserver-25\.2\.[0-9]+}"
BETA_PACKAGING_REF="$PACKAGING_REF"
# stable = XLibre 25.1.x. Its packaging is the one NexusSfan had for 25.1.7: the
# 25.2 one expects files the 25.1 tree does not have.
STABLE_REF="${STABLE_REF:-latest:xlibre-xserver-25\.1\.[0-9]+}"
STABLE_PACKAGING_REF=2eefc79ccda036c06ab717d1302bc179f695d1e7   # debian/ at 2:25.1.7-1

# ---- XiS -----------------------------------------------------------------------
# The Kiyoshi fork of XLibre (25.2 based), packaged as xlibre-xis-core: a drop-in
# alternative to the beta xserver-xlibre-core. Built from a tag of the fork's
# release branch, taken from the same 25.2 tag as the beta plus the XiS changes.
# XIS_REF: a tag, a branch, a sha, or latest:<regex> (e.g. latest:xis-25\.2\..*).
XIS_URL="${XIS_URL:-https://github.com/kiyoshispreclerg/xserver.git}"
XIS_REF="${XIS_REF:-experiments}"
