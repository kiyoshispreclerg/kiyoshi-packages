#!/bin/bash
# test-install.sh DEBDIR CHANNEL   (CHANNEL = stable | beta)
# In a clean container of the target (no build tools): install the XLibre
# packages from DEBDIR as a flat repository, check they work, switch to
# xlibre-xis-core and back, and purge.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
debs="$(cd "${1:?usage: test-install.sh DEBDIR CHANNEL}" && pwd)"
channel="${2:?channel}"
fail() { echo "FAIL: $*" >&2; exit 1; }
# installed PKG: really installed (a removed package with config files left is not)
installed() { [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" = installed ]; }
step() { printf '\n==== %s\n' "$*"; }

apt-get update -qq
apt-get install -y --no-install-recommends dpkg-dev ca-certificates >/dev/null
(cd "$debs" && dpkg-scanpackages --multiversion . > Packages 2>/dev/null)
echo "deb [trusted=yes] file:$debs ./" > /etc/apt/sources.list.d/kiyoshi-local.list
apt-get update -qq

step "install XLibre (xserver-xlibre-core + libinput + dummy + xvfb)"
apt-get install -y --no-install-recommends \
    xserver-xlibre-core xserver-xlibre-input-libinput xserver-xlibre-video-dummy \
    xserver-xlibre-xvfb x11-utils xauth
apt-get check >/dev/null || fail "apt-get check after install"
if dpkg --audit | grep .; then fail "dpkg --audit"; fi
Xorg -version 2>&1 | sed -n '1,3p'
test -x /usr/bin/Xorg || fail "no /usr/bin/Xorg"
if ldd /usr/bin/Xorg | grep 'not found'; then fail "Xorg has unresolved libraries"; fi
xvfb-run -a -s "-screen 0 1280x1024x24" xdpyinfo >/dev/null || fail "Xvfb/xdpyinfo"

# A real Xorg with the dummy driver; it needs no GPU. A failure here is a
# warning until it has proven stable in CI.
dummy_check() {
    cat > /tmp/dummy.conf <<'CONF'
Section "ServerFlags"
    Option "AutoAddDevices" "false"
    Option "AutoEnableDevices" "false"
EndSection
Section "Device"
    Identifier "d"
    Driver "dummy"
EndSection
Section "Screen"
    Identifier "s"
    Device "d"
EndSection
CONF
    Xorg :97 -config /tmp/dummy.conf -logfile /tmp/xorg.log -noreset -novtswitch -sharevts &
    local pid=$! ok=1
    for _ in $(seq 20); do
        DISPLAY=:97 xdpyinfo >/dev/null 2>&1 && { ok=0; break; }; sleep 0.5
    done
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    [ $ok -eq 0 ] || { tail -30 /tmp/xorg.log; echo "::warning::Xorg + dummy driver did not come up ($1)"; }
}
dummy_check xserver-xlibre-core

if [ "$channel" = beta ] && [ -n "$(find "$debs" -name 'xlibre-xis-core_*.deb' -print -quit)" ]; then
step "switch to xlibre-xis-core"
apt-get install -y --no-install-recommends xlibre-xis-core
if installed xserver-xlibre-core; then fail "xserver-xlibre-core still installed next to xlibre-xis-core"; fi
installed xserver-xlibre-input-libinput || fail "driver removed by the switch"
apt-get check >/dev/null || fail "apt-get check after switch"
Xorg -version 2>&1 | sed -n '1,3p'
dummy_check xlibre-xis-core

step "switch back to xserver-xlibre-core"
apt-get install -y --no-install-recommends xserver-xlibre-core
if installed xlibre-xis-core; then fail "xlibre-xis-core still installed"; fi
apt-get check >/dev/null || fail "apt-get check after switching back"

fi

step "purge"
apt-get purge -y 'xserver-xlibre*' 'xlibre*' >/dev/null
apt-get autoremove -y >/dev/null
if dpkg --audit | grep .; then fail "dpkg --audit after purge"; fi
echo "OK"
