#!/bin/bash
# Smoke test of the gtk2-ng packages built by explore.sh, on ONE target (the
# container it runs in). With the distro's own GTK2 it compiles a test program
# and runs it as a baseline, then installs the gtk2-ng .deb files over it and
# runs the SAME binary again (and a rebuilt one, and a real GTK2 program), then
# goes back to the distro's packages and runs it a third time.
#
#   DEBS        directory with the .deb files   (default: ./debs)
#   REPORT_DIR  where the report goes           (default: ./gtk2ng-smoke)
# Exit code: 0 if every check passed.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEBS="$(realpath "${DEBS:-$PWD/debs}")"
REPORT_DIR="$(realpath -m "${REPORT_DIR:-$PWD/gtk2ng-smoke}")"
WORK="${WORK:-$PWD/gtk2ng-smoke-work}"
. /etc/os-release
mkdir -p "$REPORT_DIR" "$WORK"
R="$REPORT_DIR/summary.md"
: > "$R"
FAILS=0

say()  { printf '%s\n' "$*" | tee -a "$R"; }
step() { printf '\n==== %s\n' "$*"; say ""; say "## $*"; }
ok()   { say "- ok: $*"; }
bad()  { say "- **FAILED**: $*"; FAILS=$((FAILS + 1)); }
# check "description" command...   (the command's output goes to the log)
check() { local d="$1"; shift; if "$@" >>"$REPORT_DIR/smoke.log" 2>&1; then ok "$d"; else bad "$d"; fi; }
# run the test program under a virtual X server; fatal criticals turn GLib warnings into failures
run_smoke() { # BINARY LABEL
    local out rc
    out="$(G_DEBUG=fatal-criticals timeout 60 xvfb-run -a "$1" 2>&1)"; rc=$?
    printf '%s\n' "--- $2 (rc=$rc)" "$out" >> "$REPORT_DIR/smoke.log"
    if [ "$rc" = 0 ] && grep -q '^SMOKE OK' <<<"$out"; then ok "$2: $(grep '^SMOKE OK' <<<"$out")"
    else bad "$2 (exit $rc): $(tail -n 3 <<<"$out" | tr '\n' ' ')"; fi
}
# a real GTK2 program must stay up for a few seconds (timeout's 124 means it did not crash)
run_app() { # COMMAND LABEL
    local rc
    timeout 6 xvfb-run -a "$1" >>"$REPORT_DIR/smoke.log" 2>&1; rc=$?
    if [ "$rc" = 124 ]; then ok "$2 ran for 6 s"; else bad "$2 exited with $rc"; fi
}
ng_installed() { dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null | grep -c 'ngtest'; }

step "Target: $PRETTY_NAME"
ls "$DEBS" | grep -v dbgsym | sed 's/^/- /' | tee -a "$R" >/dev/null
# libgtk2.0-0 or libgtk2.0-0t64, whichever this suite has
LIB="$(dpkg-deb -f "$(ls "$DEBS"/libgtk2.0-0*.deb | grep -v dbgsym | head -1)" Package)"
say "library package: \`$LIB\`"

step "The distro's GTK2 (baseline)"
apt-get update -qq
apt-get install -y -qq --no-install-recommends build-essential pkg-config xvfb xauth \
    libgtk2.0-dev "$LIB" >/dev/null 2>&1 || bad "installing the distro's GTK2 and the tools"
STOCK_VER="$(dpkg-query -W -f='${Version}' "$LIB")"
say "stock \`$LIB\` $STOCK_VER"
# shellcheck disable=SC2046
gcc -o "$WORK/smoke-stock" "$HERE/smoke/smoke.c" $(pkg-config --cflags --libs gtk+-2.0 gtk+-unix-print-2.0) 2>>"$REPORT_DIR/smoke.log" \
    && ok "test program compiled against the distro's libgtk2.0-dev" || bad "compiling the test program"
run_smoke "$WORK/smoke-stock" "baseline (distro GTK2)"
# a real application, if the suite still has one
if apt-get install -y -qq --no-install-recommends leafpad >/dev/null 2>&1; then
    run_app leafpad "leafpad (distro GTK2)"
else say "- (no leafpad in this suite: skipped)"; fi

step "Install the gtk2-ng packages"
mapfile -t NG < <(find "$DEBS" -maxdepth 1 -name '*.deb' ! -name '*dbgsym*' | sort)
# their version ends in ~ngtest, below the distro's: this is a downgrade for apt
if apt-get install -y --allow-downgrades "${NG[@]}" >"$REPORT_DIR/install.log" 2>&1; then ok "apt install of ${#NG[@]} packages"
else bad "apt install of the gtk2-ng packages"; tail -n 15 "$REPORT_DIR/install.log" | tee -a "$R"; fi
say "gtk2-ng packages installed: $(ng_installed)"
dpkg -l | grep -E 'libgtk2|libgail|gtk2-engines|gir1.2-gtk-2' | awk '{print "- " $2 " " $3}' | tee -a "$R" >/dev/null

step "With gtk2-ng"
LIBFILE="$(readlink -f "$(ldd "$WORK/smoke-stock" | awk '/libgtk-x11-2.0/{print $3}')")"
say "the test program loads: \`$LIBFILE\` (package: $(dpkg -S "$LIBFILE" 2>/dev/null | cut -d: -f1))"
check "the loaded libgtk belongs to a gtk2-ng package" bash -c "dpkg -l '$LIB' | grep -q ngtest"
run_smoke "$WORK/smoke-stock" "same binary, now with gtk2-ng"
# shellcheck disable=SC2046
gcc -o "$WORK/smoke-ng" "$HERE/smoke/smoke.c" $(pkg-config --cflags --libs gtk+-2.0 gtk+-unix-print-2.0) 2>>"$REPORT_DIR/smoke.log" \
    && ok "test program compiled against gtk2-ng's libgtk2.0-dev" || bad "compiling against gtk2-ng"
run_smoke "$WORK/smoke-ng" "rebuilt against gtk2-ng"
check "immodules.cache was generated" bash -c 'test -s /usr/lib/*/gtk-2.0/2.10.0/immodules.cache'
check "gtk-update-icon-cache runs" bash -c 'gtk-update-icon-cache --help'
if command -v leafpad >/dev/null; then run_app leafpad "leafpad (gtk2-ng)"; fi
check "dpkg is consistent" dpkg --audit
check "apt has nothing broken" apt-get check

step "Back to the distro's packages"
mapfile -t NGPKG < <(dpkg-query -W -f='${Package} ${Version}\n' | awk '/ngtest/{print $1}')
if apt-get install -y --allow-downgrades "${NGPKG[@]}" >"$REPORT_DIR/revert.log" 2>&1; then ok "apt install ${NGPKG[*]}"
else bad "going back to the distro's packages"; tail -n 15 "$REPORT_DIR/revert.log" | tee -a "$R"; fi
[ "$(ng_installed)" = 0 ] && ok "no gtk2-ng package is left" || bad "gtk2-ng packages are still installed"
run_smoke "$WORK/smoke-stock" "after going back"

step "Result"
if [ "$FAILS" = 0 ]; then say "all checks passed"; else say "**$FAILS check(s) failed**"; fi
exit $(( FAILS > 0 ))
