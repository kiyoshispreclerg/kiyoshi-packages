#!/bin/bash
# Smoke test of the gtk2-ng packages built by explore.sh, on ONE target (the
# container it runs in). With the distro's own GTK2 it installs kidesktop-core (a
# real GTK2 program that asks for the distro's package names), compiles a test
# program and runs both as a baseline; then installs the gtk2-ng packages (the
# metapackage and the rest) and checks that apt swaps the libraries, keeps
# kidesktop-core, and that both programs, the SAME binaries, still run; then
# installs the distro's library again, which has to remove gtk2-ng with no
# other change, and runs them a third time.
#
#   DEBS        directory with the .deb files   (default: ./debs)
#   FLAVOR      ng or king                      (default: ng)
#   REPORT_DIR  where the report goes           (default: ./gtk2ng-smoke)
# Exit code: 0 if every check passed.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEBS="$(realpath "${DEBS:-$PWD/debs}")"
FLAVOR="${FLAVOR:-ng}"
REPORT_DIR="$(realpath -m "${REPORT_DIR:-$PWD/gtk2ng-smoke}")"
WORK="${WORK:-$PWD/gtk2ng-smoke-work}"
REPO_URL="https://kiyoshispreclerg.github.io/kiyoshi-packages"
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
run_app() { # LABEL COMMAND...
    local rc label="$1"; shift
    timeout 6 xvfb-run -a "$@" >>"$REPORT_DIR/smoke.log" 2>&1; rc=$?
    if [ "$rc" = 124 ]; then ok "$label ran for 6 s"; else bad "$label exited with $rc"; fi
}
# installed packages of the gtk2-ng line (gtk2-ng, libgtk2-ng-0, libgail-ng-18, gir1.2-gtk-2.0-ng, ...)
ng_installed() { dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -cE "(^|-)(ng|king)(-|$)"; }

step "Target: $PRETTY_NAME (gtk2-$FLAVOR)"
find "$DEBS" -maxdepth 1 -name '*.deb' ! -name '*dbgsym*' -printf '- %f\n' | sort | tee -a "$R" >/dev/null

step "The distro's GTK2 and kidesktop-core (baseline)"
apt-get update -qq
apt-get install -y -qq --no-install-recommends build-essential pkg-config xvfb xauth curl ca-certificates \
    libgtk2.0-dev >/dev/null 2>&1 || bad "installing the distro's GTK2 and the tools"
# the installed one (libgtk2.0-0 or libgtk2.0-0t64): the pattern also matches names that are only provided
STOCKLIB="$(dpkg-query -W -f='${Package} ${Status}\n' 'libgtk2.0-0*' 2>/dev/null | awk '/ install ok installed$/ && !/udeb/ {print $1; exit}')"
STOCK_VER="$(dpkg-query -W -f='${Version}' "$STOCKLIB")"
say "distro library: \`$STOCKLIB\` $STOCK_VER"
# shellcheck disable=SC2046
if gcc -o "$WORK/smoke-stock" "$HERE/smoke/smoke.c" $(pkg-config --cflags --libs gtk+-2.0 gtk+-unix-print-2.0) 2>>"$REPORT_DIR/smoke.log"; then
    ok "test program compiled against the distro's libgtk2.0-dev"
else bad "compiling the test program"; fi
run_smoke "$WORK/smoke-stock" "baseline test program (distro GTK2)"

# kidesktop-core from this repository's own apt archive: the newest one of this suite
SUITE="${VERSION_CODENAME:-}"
KD_FILE="$(curl -fsS "$REPO_URL/dists/$SUITE/main/binary-amd64/Packages" 2>>"$REPORT_DIR/smoke.log" \
    | awk -v RS= '/^Package: kidesktop-core\n/{for(i=1;i<=NF;i++) if($i=="Filename:") print $(i+1)}' | tail -1)"
if [ -n "$KD_FILE" ] && curl -fsSL -o "$WORK/kidesktop-core.deb" "$REPO_URL/$KD_FILE" 2>>"$REPORT_DIR/smoke.log" \
        && apt-get install -y -qq --no-install-recommends "$WORK/kidesktop-core.deb" >>"$REPORT_DIR/smoke.log" 2>&1; then
    ok "kidesktop-core installed ($(dpkg-query -W -f='${Version}' kidesktop-core)); it depends on: $(dpkg-query -W -f='${Depends}' kidesktop-core | tr ',' '\n' | grep -o 'libgtk2[^ ]* ([^)]*)')"
    run_app "kiconf --kitheme (distro GTK2)" kiconf --kitheme
else
    bad "could not get and install kidesktop-core for $SUITE from $REPO_URL"
fi

step "Install the gtk2-$FLAVOR packages"
mapfile -t NG < <(find "$DEBS" -maxdepth 1 -name '*.deb' ! -name '*dbgsym*' | sort)
# one apt call with every package, as a user would do `apt install gtk2-ng` (the metapackage
# is in the list): apt has to remove the distro's libraries by itself
if apt-get install -y "${NG[@]}" >"$REPORT_DIR/install.log" 2>&1; then ok "apt install of ${#NG[@]} packages"
else bad "apt install of the gtk2-$FLAVOR packages"; tail -n 20 "$REPORT_DIR/install.log" | tee -a "$R"; fi
say "gtk2-$FLAVOR packages installed: $(ng_installed)"
dpkg -l | grep -E 'libgtk2|libgail|gtk2-|gir1.2-gtk-2' | awk '{print "- " $2 " " $3}' | tee -a "$R" >/dev/null
check "the distro's $STOCKLIB is gone (replaced by gtk2-$FLAVOR)" bash -c "! dpkg-query -W -f='\${Status}' $STOCKLIB 2>/dev/null | grep -q 'install ok installed'"
check "kidesktop-core is still installed (its dependency on libgtk2.0 is met by Provides)" bash -c "dpkg-query -W -f='\${Status}' kidesktop-core | grep -q 'install ok installed'"
say "the library now provides: $(dpkg-query -W -f='${Provides}' "libgtk2-$FLAVOR-0")"

step "With gtk2-$FLAVOR"
LIBFILE="$(readlink -f "$(ldd "$WORK/smoke-stock" | awk '/libgtk-x11-2.0/{print $3}')")"
say "the test program loads: \`$LIBFILE\` (package: $(dpkg -S "$LIBFILE" 2>/dev/null | cut -d: -f1))"
check "the loaded libgtk belongs to libgtk2-$FLAVOR-0" bash -c "dpkg -S '$LIBFILE' | grep -q '^libgtk2-$FLAVOR-0'"
run_smoke "$WORK/smoke-stock" "same test binary, now with gtk2-$FLAVOR"
run_app "kiconf --kitheme (gtk2-$FLAVOR)" kiconf --kitheme
# shellcheck disable=SC2046
if gcc -o "$WORK/smoke-ng" "$HERE/smoke/smoke.c" $(pkg-config --cflags --libs gtk+-2.0 gtk+-unix-print-2.0) 2>>"$REPORT_DIR/smoke.log"; then
    ok "test program compiled against gtk2-$FLAVOR's libgtk2-$FLAVOR-dev"
else bad "compiling against gtk2-$FLAVOR"; fi
run_smoke "$WORK/smoke-ng" "rebuilt against gtk2-$FLAVOR"
check "immodules.cache was generated" bash -c 'test -s /usr/lib/*/gtk-2.0/2.10.0/immodules.cache'
check "gtk-update-icon-cache runs" bash -c 'gtk-update-icon-cache --help'
check "dpkg is consistent" dpkg --audit
check "apt has nothing broken" apt-get check

step "Back to the distro's GTK2: apt install $STOCKLIB"
if apt-get install -y "$STOCKLIB" libgtk2.0-common libgtk2.0-bin libgtk2.0-dev >"$REPORT_DIR/revert.log" 2>&1; then
    ok "apt install $STOCKLIB libgtk2.0-common libgtk2.0-bin libgtk2.0-dev"
else bad "going back to the distro's packages"; tail -n 20 "$REPORT_DIR/revert.log" | tee -a "$R"; fi
say "gtk2-$FLAVOR packages left: $(ng_installed)"
dpkg -l | grep -E 'libgtk2|libgail|gtk2-|gir1.2-gtk-2' | awk '{print "- " $2 " " $3}' | tee -a "$R" >/dev/null
if [ "$(ng_installed)" = 0 ]; then ok "the metapackage and all gtk2-$FLAVOR packages were removed"; else bad "gtk2-$FLAVOR packages are still installed"; fi
check "kidesktop-core is still installed" bash -c "dpkg-query -W -f='\${Status}' kidesktop-core | grep -q 'install ok installed'"
run_smoke "$WORK/smoke-stock" "test program after going back"
run_app "kiconf --kitheme (distro GTK2 again)" kiconf --kitheme
check "dpkg is consistent" dpkg --audit

step "Result"
if [ "$FAILS" = 0 ]; then say "all checks passed"; else say "**$FAILS check(s) failed**"; fi
exit $(( FAILS > 0 ))
