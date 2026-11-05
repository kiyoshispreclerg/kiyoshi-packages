#!/bin/bash
# Exploration run for the gtk2-ng line: on ONE target (the container it runs in)
# it finds out how the distro's own GTK2 is packaged and how far gtk2-ng gets
# with that packaging. Nothing here is meant to be published; it writes a
# report (REPORT_DIR) and keeps going after a failed step, so one run shows
# everything that has to be handled for the target.
#
#   GTK2NG_URL  git URL of gtk2-ng        (default: Kiyoshi's fork, whose master mirrors Devuan's)
#   GTK2NG_REF  branch, tag or commit      (default: master)
#   REPORT_DIR  where the report goes      (default: ./gtk2ng-report)
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

GTK2NG_URL="${GTK2NG_URL:-https://github.com/kiyoshispreclerg/gtk2-ng.git}"
GTK2NG_REF="${GTK2NG_REF:-master}"
REPORT_DIR="$(realpath -m "${REPORT_DIR:-$PWD/gtk2ng-report}")"
WORK="${WORK:-$PWD/gtk2ng-work}"
. /etc/os-release
TARGET="${ID}${VERSION_ID}"
mkdir -p "$REPORT_DIR" "$WORK"
R="$REPORT_DIR/summary.md"
: > "$R"

say()  { printf '%s\n' "$*" | tee -a "$R"; }
step() { printf '\n==== %s\n' "$*"; say ""; say "## $*"; }
code() { say '```'; cat >> "$R"; say '```'; }   # stdin into a code block of the report

step "Target: $TARGET ($PRETTY_NAME)"
say "gtk2-ng: $GTK2NG_URL @ $GTK2NG_REF"

step "Tools and deb-src"
for f in /etc/apt/sources.list.d/*.sources; do
    [ -e "$f" ] && sed -i 's/^Types: deb$/Types: deb deb-src/' "$f"
done
if [ -f /etc/apt/sources.list ]; then
    sed -n 's/^deb /deb-src /p' /etc/apt/sources.list > "$WORK/deb-src.list"
    cat "$WORK/deb-src.list" >> /etc/apt/sources.list
fi
apt-get update -qq
if apt-get install -y -qq --no-install-recommends \
    build-essential dpkg-dev devscripts fakeroot git ca-certificates patch \
    autoconf automake libtool pkg-config gettext debhelper dh-autoreconf >/dev/null
then say "ok"; else say "FAILED installing tools"; fi

step "Stock gtk+2.0 source package"
cd "$WORK" || exit 1
if apt-get source --download-only -qq gtk+2.0 >/dev/null 2>&1; then
    dpkg-source -x ./gtk+2.0_*.dsc stock >/dev/null 2>&1
    STOCK_VER="$(dpkg-parsechangelog -l stock/debian/changelog -S Version)"
    say "version: \`$STOCK_VER\`  (source format: $(cat stock/debian/source/format))"
    say ""; say "Binary packages (name, and what each Provides/Replaces/Conflicts/Breaks):"
    ( cd stock/debian && grep -E '^(Package|Provides|Replaces|Conflicts|Breaks|Architecture):' control ) | code
    say "Upstream patches (series):"
    code < stock/debian/patches/series
    say "debian/rules (configure flags):"
    grep -nE 'configure|--(enable|disable|with|without)-|dh_' stock/debian/rules | code
else
    say "FAILED: no gtk+2.0 source in this suite (apt-get source)"
    STOCK_VER=""
fi

step "Stock binaries (to compare against)"
mkdir -p stock-bin && cd stock-bin || exit 1
while read -r p; do
    if apt-get download -qq "$p" 2>/dev/null; then echo "downloaded $p" >> "$R"; fi
done < <(grep -E '^Package:' ../stock/debian/control 2>/dev/null | awk '{print $2}')
cd "$WORK" || exit 1
find stock-bin -name '*.deb' -printf '%f\n' | sort | code

step "gtk2-ng source"
if git clone -q "$GTK2NG_URL" ng && git -C ng checkout -q "$GTK2NG_REF"; then
    say "commit: \`$(git -C ng rev-parse --short HEAD)\`, tracked configure: $(git -C ng ls-files configure | wc -l)"
else
    say "FAILED to clone/checkout gtk2-ng"; exit 1
fi

step "Do the distro's patches apply to gtk2-ng?"
mkdir -p good
: > good/series
if [ -n "$STOCK_VER" ]; then
    while read -r p _; do
        case "$p" in ''|'#'*) continue ;; esac
        # applied for real, in series order, so each one is tried on top of the previous ones
        if patch -d ng -p1 -N -s --dry-run < "stock/debian/patches/$p" >/dev/null 2>&1; then
            patch -d ng -p1 -N -s < "stock/debian/patches/$p" >/dev/null
            say "- applies: $p"; echo "$p" >> good/series
        elif patch -d ng -p1 -R -s --dry-run < "stock/debian/patches/$p" >/dev/null 2>&1; then
            say "- already in gtk2-ng: $p"
        else
            say "- FAILS: $p"
        fi
    done < stock/debian/patches/series
fi

step "Build dependencies"
if apt-get build-dep -y -qq gtk+2.0 >/dev/null 2>&1; then say "stock build-deps: ok"
else say "FAILED: apt-get build-dep gtk+2.0"; fi
# gtk2-ng needs fribidi; list what its configure asks for beyond the stock list
say "gtk2-ng configure.ac requirements:"
grep -nE 'PKG_CHECK_MODULES|_required_version=|AM_PATH|--with-|--enable-' ng/configure.ac | grep -ciE 'fribidi' | sed 's/^/fribidi mentions: /' | code
if apt-get install -y -qq libfribidi-dev >/dev/null 2>&1; then say "libfribidi-dev: ok"; else say "FAILED: libfribidi-dev"; fi

step "Build gtk2-ng with the distro's debian/ directory"
if [ -n "$STOCK_VER" ]; then
    # gtk2-ng carries an old debian/ of its own (gtk+-cvs, 1998): replace it
    rm -rf ng/debian
    cp -a stock/debian ng/debian
    ( cd ng || exit 1
      # The distro's rules ship README, which `make dist` generates from README.in
      [ -e README ] || cp README.md README
      # The patches that fit are already applied (previous step): empty series
      : > debian/patches/series
      dch -b -v "${STOCK_VER}~${TARGET}~ngtest" -D unstable --force-distribution "gtk2ng exploration build" 2>/dev/null
      # The -doc packages ship HTML that the upstream tarball has pre-generated and a git
      # tree does not (first run: only dh_install of libgtk2.0-doc/libgail-doc failed): skip them
      DH_OPTIONS="-Nlibgtk2.0-doc -Nlibgail-doc" dpkg-buildpackage -b -uc -us -d >"$REPORT_DIR/build.log" 2>&1 )
    BUILD_RC=$?
    say "dpkg-buildpackage exit code: $BUILD_RC (full log: build.log)"
    tail -n 40 "$REPORT_DIR/build.log" | code
else
    BUILD_RC=1
fi

step "ABI and contents compared with the distro's binaries"
if [ "$BUILD_RC" = 0 ]; then
    mkdir -p cmp/stock cmp/ng
    for d in stock-bin/*.deb; do dpkg -x "$d" cmp/stock; done
    for d in ./*.deb; do dpkg -x "$d" cmp/ng; done
    for lib in gtk gdk; do
        for side in stock ng; do
            f="$(find "cmp/$side" -name "lib$lib-x11-2.0.so.0.*" | head -1)"
            [ -n "$f" ] && nm -D --defined-only "$f" | awk '{print $3}' | sort -u > "cmp/$lib.$side"
        done
        say "lib$lib symbols the distro exports and gtk2-ng does not:"
        comm -23 "cmp/$lib.stock" "cmp/$lib.ng" | code
        say "lib$lib symbols only gtk2-ng exports: $(comm -13 "cmp/$lib.stock" "cmp/$lib.ng" | wc -l)"
    done
    say "Files the distro ships and the gtk2-ng build does not (per path):"
    ( cd cmp/stock && find . -type f -o -type l | sort ) > cmp/files.stock
    ( cd cmp/ng && find . -type f -o -type l | sort ) > cmp/files.ng
    comm -23 cmp/files.stock cmp/files.ng | grep -vE '/share/(doc|man|locale|gtk-doc)/' | code
    say "Binary packages produced by gtk2-ng:"
    find . -maxdepth 1 -name '*.deb' -printf '%f\n' | sort | code
    cp ./*.deb "$REPORT_DIR/" 2>/dev/null
    say "Reverse dependencies on the stock names that must keep resolving: see Provides above."
else
    say "skipped: the build failed"
fi

step "Done"
