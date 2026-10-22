#!/bin/bash
# Checks the tree installed in PREFIX by build-xis.sh. Exits non-zero on the
# first problem.
set -euo pipefail

PREFIX="${PREFIX:-/opt/xis}"
fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok:   $*"; }

xorg="$PREFIX/bin/Xorg"
xvfb="$PREFIX/bin/Xvfb"
[ -x "$xorg" ] || fail "$xorg missing"
[ -x "$xvfb" ] || fail "$xvfb missing"

# 1. Xorg starts far enough to identify itself.
"$xorg" -version 2>&1 | sed 's/^/     /'
ok "Xorg -version"

# 2. No unresolved libraries, and libdrm comes from the prefix.
mods="$(find "$PREFIX/lib/xorg/modules" -name '*.so')"
for f in "$xorg" "$xvfb" $mods; do
    if ldd "$f" 2>&1 | grep -q 'not found'; then
        ldd "$f" | grep 'not found' >&2
        fail "unresolved libraries in $f"
    fi
done
ok "all libraries resolve ($(echo "$mods" | wc -l) modules checked)"

drm="$(ldd "$xorg" | awk '/libdrm\.so/ {print $3; exit}')"
case "$drm" in
    "$PREFIX"/lib/*) ok "libdrm from the prefix: $drm" ;;
    *) fail "Xorg uses libdrm from '$drm', not $PREFIX/lib" ;;
esac

# 3. The drivers we ship are where the server looks for them.
for m in drivers/modesetting_drv.so input/libinput_drv.so; do
    found="$(find "$PREFIX/lib/xorg/modules" -path "*/$m")"
    [ -n "$found" ] || fail "$m not installed under $PREFIX/lib/xorg/modules"
    ok "$found"
done
[ -f "$PREFIX/share/X11/xorg.conf.d/40-libinput.conf" ] || fail "40-libinput.conf missing"
ok "40-libinput.conf"

# 4. A server actually runs and answers.
display=:97
"$xvfb" "$display" -screen 0 1280x1024x24 -nolisten tcp >/tmp/xis-xvfb.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 100); do
    [ -S /tmp/.X11-unix/X97 ] && break
    kill -0 "$pid" 2>/dev/null || { cat /tmp/xis-xvfb.log >&2; fail "Xvfb exited"; }
    sleep 0.1
done
xdpyinfo -display "$display" | grep -E 'vendor string|version number' | sed 's/^/     /'
ok "Xvfb answers on $display"

echo "smoke test passed"
