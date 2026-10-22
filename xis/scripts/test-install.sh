#!/bin/bash
# Installs the .deb files from DEBDIR on a clean system (no build tools, no
# source tree needed beyond xis/) and checks that the result works and
# stays out of the distribution's X server's way. Run as root, in a container.
#
#   test-install.sh DEBDIR
set -euo pipefail

debdir="${1:?usage: test-install.sh DEBDIR}"
PREFIX="${PREFIX:-/opt/xis}"
LOCALSTATEDIR="${LOCALSTATEDIR:-/var/opt/xis}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok:   $*"; }
step() { printf '\n==== %s\n' "$*"; }

shopt -s nullglob
server=("$debdir"/xis-server_*.deb)
dev=("$debdir"/xis-dev_*.deb)
[ "${#server[@]}" -eq 1 ] && [ "${#dev[@]}" -eq 1 ] || fail "expected one xis-server and one xis-dev in $debdir"

apt-get update -qq
# xdpyinfo for the smoke test, pkg-config for the xis-dev check.
apt-get install -y -qq --no-install-recommends x11-utils pkg-config >/dev/null

step "install xis-server (dependencies come from the distribution)"
apt-get install -y --no-install-recommends "${server[0]}"
dpkg -s xis-server | grep -E '^(Package|Version|Status):'
ok "xis-server installed"

step "every file is under $PREFIX or $LOCALSTATEDIR (plus the two helpers)"
stray="$(dpkg -L xis-server | grep -vE "^(/|/\.|/opt|/var|/var/opt|/usr|/usr/bin)$|^/usr/bin/(startxis|xis-dm)$|^($PREFIX|$LOCALSTATEDIR)(/|$)" || true)"
[ -z "$stray" ] || fail "files outside the prefix:
$stray"
ok "no stray files"
[ -d "$LOCALSTATEDIR/log" ] || fail "$LOCALSTATEDIR/log missing"
[ "$(stat -c %a "$LOCALSTATEDIR/xkb")" = 1777 ] || fail "$LOCALSTATEDIR/xkb is not 1777"
ok "$LOCALSTATEDIR/{log,xkb} present"

step "startxis and xis-dm"
# A stand-in for startx that prints what it receives, so no X server is started.
fake="$(mktemp -d)"
printf '#!/bin/sh\nfor a in "$@"; do printf "[%%s]" "$a"; done; echo\n' > "$fake/startx"
chmod +x "$fake/startx"
got="$(PATH="$fake:$PATH" startxis xterm -- :1)"
want="[xterm][--][$PREFIX/bin/Xorg][:1][-nolisten][tcp]"
[ "$got" = "$want" ] || fail "startxis passed '$got', expected '$want'"
ok "startxis puts the XiS server after --"

root="$(mktemp -d)"
mkdir -p "$root/etc/X11"
echo /usr/sbin/lightdm > "$root/etc/X11/default-display-manager"
XIS_DM_ROOT="$root" xis-dm enable >/dev/null
grep -q "xserver-command=$PREFIX/bin/Xorg" "$root/etc/lightdm/lightdm.conf.d/50-xis.conf" \
    || fail "xis-dm enable did not write the LightDM drop-in"
XIS_DM_ROOT="$root" xis-dm status | grep -q 'lightdm:  XiS enabled' || fail "xis-dm status does not see the drop-in"
XIS_DM_ROOT="$root" xis-dm disable >/dev/null
[ ! -e "$root/etc/lightdm/lightdm.conf.d/50-xis.conf" ] || fail "xis-dm disable left the drop-in"
ok "xis-dm enable / status / disable"
rm -rf "$fake" "$root"

step "smoke test of the installed package"
"$here/smoke-test.sh"

step "install xis-dev"
apt-get install -y --no-install-recommends "${dev[0]}"
ver="$(PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig" pkg-config --modversion xorg-server)"
[ -n "$ver" ] || fail "pkg-config cannot find xorg-server in $PREFIX"
ok "pkg-config finds xorg-server $ver"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig" pkg-config --exists libdrm xproto presentproto \
    || fail "libdrm / xorgproto not visible through $PREFIX"
ok "libdrm and xorgproto visible through pkg-config"

step "coexistence with the distribution's X server"
apt-get install -y --no-install-recommends xserver-xorg-core
distro_xorg=/usr/lib/xorg/Xorg
[ -x "$distro_xorg" ] || fail "distribution Xorg not at $distro_xorg"
"$distro_xorg" -version 2>&1 | grep -E 'X.Org X Server|XLibre' | head -1 | sed 's/^/     /'
dpkg -L xserver-xorg-core | grep -q "^$PREFIX" && fail "xserver-xorg-core owns files under $PREFIX"
[ "$("$PREFIX/bin/Xorg" -version 2>&1 | grep -c 'XiS X Server')" -ge 1 ] || fail "$PREFIX/bin/Xorg is not the XiS server"
ok "both servers installed, each one itself"
apt-get check >/dev/null || fail "apt-get check reports a broken system"
dpkg --audit | grep . && fail "dpkg --audit reports problems" || true
ok "apt/dpkg consistent"
"$here/smoke-test.sh" >/dev/null
ok "XiS still passes the smoke test next to the distribution's Xorg"

step "purge"
apt-get purge -y xis-dev xis-server >/dev/null
[ ! -e "$PREFIX" ] || fail "$PREFIX still exists after purge: $(ls -A "$PREFIX" | head)"
[ ! -e "$LOCALSTATEDIR" ] || fail "$LOCALSTATEDIR still exists after purge"
"$distro_xorg" -version >/dev/null 2>&1 || fail "the distribution's Xorg broke after removing XiS"
ok "removed cleanly, distribution's Xorg untouched"

echo
echo "install test passed"
