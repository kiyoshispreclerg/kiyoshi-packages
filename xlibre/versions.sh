# ---- XLibre channels ---------------------------------------------------------
# beta   = XLibre 25.2.x: NexusSfan's packaging as it is (sources.txt, branch tip)
# stable = XLibre 25.1.x: the packaging as it was for 25.1.x, with the server tree
#          replaced by the upstream 25.1 tag below. The drivers/metapackage are
#          taken as they were at STABLE_CUTOFF (the last commit before it), i.e.
#          before the 25.2 work, so they match the 25.1 server ABI. Empty
#          STABLE_CUTOFF = branch tip.
STABLE_UPSTREAM_URL=https://github.com/X11Libre/xserver.git
STABLE_UPSTREAM_REF=xlibre-xserver-25.1.9
STABLE_PACKAGING_URL=https://github.com/xlibre-debian/xlibre-server.git
STABLE_PACKAGING_REF=2eefc79ccda036c06ab717d1302bc179f695d1e7   # debian/ at 2:25.1.7-1
STABLE_CUTOFF=2026-06-20

# ---- XiS ---------------------------------------------------------------------
# The Kiyoshi fork of XLibre (25.2 based), packaged as xlibre-xis-core: a drop-in
# alternative to the beta xserver-xlibre-core. REF is a branch, tag or full sha;
# override from the environment or the workflow inputs.
XIS_URL="${XIS_URL:-https://github.com/kiyoshispreclerg/xserver.git}"
XIS_REF="${XIS_REF:-experiments}"
# Debian packaging XiS is built with (the beta one).
PACKAGING_URL=https://github.com/xlibre-debian/xlibre-server.git
PACKAGING_REF=xlibre/latest
