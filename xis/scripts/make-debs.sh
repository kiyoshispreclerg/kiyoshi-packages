#!/bin/bash
# Turn the staging tree from build-xis.sh into .deb files:
#
#   xis-server   everything under PREFIX that is needed at run time, plus the
#                (empty) LOCALSTATEDIR/log and LOCALSTATEDIR/xkb directories
#   xis-dev      headers, pkg-config files and the unversioned libdrm symlinks,
#                for building drivers against the XiS server
#
# xis-server also ships /usr/bin/startxis and /usr/bin/xis-dm (xis/files).
# Nothing else is installed outside PREFIX and LOCALSTATEDIR, and neither package
# conflicts with, replaces or provides anything of the distribution's X server.
#
# Environment:
#   PREFIX         install prefix used by build-xis.sh       (default /opt/xis)
#   LOCALSTATEDIR  variable data dir used by build-xis.sh    (default /var/opt/xis)
#   WORK           scratch dir                               (default ./packaging-work)
#   STAGE          staging tree                              (default $WORK/stage)
#   OUT            where the .deb files go                   (default $WORK/debs)
#   XIS_REVISION   set for a release build (1, 2, ...); unset gives a snapshot
#                  version carrying the git hash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../versions.sh"

PREFIX="${PREFIX:-$XIS_PREFIX_DEFAULT}"
LOCALSTATEDIR="${LOCALSTATEDIR:-/var/opt/xis}"
WORK="${WORK:-$PWD/packaging-work}"
STAGE="${STAGE:-$WORK/stage}"
OUT="${OUT:-$WORK/debs}"
repo="$WORK/src/xis"   # clone made by build-xis.sh

die() { echo "make-debs: $*" >&2; exit 1; }

root="$STAGE$PREFIX"
[ -d "$root" ] || die "$root not found; run build-xis.sh first"

# ---- version ---------------------------------------------------------------
# Debian version: <upstream>-0xis<rev>~<distro>. The distro tag keeps the four
# builds of one release distinct and sorts them below any later revision.
. /etc/os-release
distro="${ID}${VERSION_ID}"
arch="$(dpkg --print-architecture)"
upstream="$(awk '/^Version:/ {print $2; exit}' "$root/lib/pkgconfig/xorg-server.pc")"
[ -n "$upstream" ] || die "cannot read the server version from xorg-server.pc"
sha="$(git -C "$repo" rev-parse --short=7 HEAD 2>/dev/null || echo 0000000)"
if [ -n "${XIS_REVISION:-}" ]; then
    debver="$upstream-0xis$XIS_REVISION~$distro"
else
    debver="$upstream-0xis0~git$sha~$distro"
fi
echo "make-debs: version $debver ($arch)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
srv="$tmp/xis-server"
dev="$tmp/xis-dev"
mkdir -p "$srv$(dirname "$PREFIX")" "$dev$PREFIX" "$OUT"
cp -a "$root" "$srv$PREFIX"

# ---- split off the development files ----------------------------------------
to_dev() {   # to_dev RELATIVE-PATH-UNDER-PREFIX
    local p="$srv$PREFIX/$1"
    [ -e "$p" ] || [ -L "$p" ] || return 0
    mkdir -p "$dev$PREFIX/$(dirname "$1")"
    mv "$p" "$dev$PREFIX/$1"
}
to_dev include
to_dev lib/pkgconfig
for d in "$srv$PREFIX"/lib/*/pkgconfig; do      # multiarch leftovers, if any
    [ -d "$d" ] && to_dev "lib/$(basename "$(dirname "$d")")/pkgconfig"
done
to_dev share/pkgconfig
to_dev share/aclocal
to_dev share/doc/xorgproto
for l in "$srv$PREFIX"/lib/*.so; do
    [ -L "$l" ] && to_dev "lib/$(basename "$l")"
done

# Debian-specific NVIDIA snippets the server installs under sysconfdir, named
# so that they are inert. Not shipped; keep the (empty) directory users can put
# XiS-only configuration in.
rm -f "$srv$PREFIX"/etc/X11/xorg.conf.d/*.debian
find "$srv$PREFIX" -depth -mindepth 1 -type d -empty -delete
install -d -m 0755 "$srv$PREFIX/etc/X11/xorg.conf.d"
chmod -R go-w "$srv" "$dev"

# Data the server writes at run time, owned by the package so purge can clean it.
install -d -m 0755 "$srv$LOCALSTATEDIR" "$srv$LOCALSTATEDIR/log"
install -d -m 1777 "$srv$LOCALSTATEDIR/xkb"

# Command line helpers, with the prefix filled in.
install -d -m 0755 "$srv/usr/bin"
for f in startxis xis-dm; do
    sed "s|@PREFIX@|$PREFIX|g" "$here/../files/$f" > "$srv/usr/bin/$f"
    chmod 0755 "$srv/usr/bin/$f"
done

# ---- strip, and find the ELF files ------------------------------------------
elfs=()
while IFS= read -r -d '' f; do
    if [ "$(head -c4 "$f" | tail -c3)" = "ELF" ]; then
        strip --strip-unneeded "$f"
        elfs+=("$f")
    fi
done < <(find "$srv$PREFIX" -type f -print0)
echo "make-debs: ${#elfs[@]} ELF files"

# ---- run-time dependencies --------------------------------------------------
# dpkg-shlibdeps wants a debian/control to run against. The libraries under
# PREFIX (libdrm) are ours and have no package, hence --ignore-missing-info.
mkdir -p "$tmp/shl/debian"
printf 'Source: xis\n\nPackage: xis-server\nArchitecture: any\n' > "$tmp/shl/debian/control"
shl="$(cd "$tmp/shl" && LC_ALL=C dpkg-shlibdeps -O --ignore-missing-info -l"$PREFIX/lib" "${elfs[@]}" \
        2> "$tmp/shlibdeps.err" | sed -n 's/^shlibs:Depends=//p')" || true
if [ -z "$shl" ]; then
    cat "$tmp/shlibdeps.err" >&2
    die "dpkg-shlibdeps produced no dependencies"
fi
# Expected: we analyse files outside debian/<package>/, and our own libdrm has
# no package. Anything else is worth seeing.
grep -vE 'should already be installed|no dependency information found' "$tmp/shlibdeps.err" >&2 || true

# ---- control files ----------------------------------------------------------
maint="Kiyoshi Spreclerg <kiyoshi_pip@protonmail.com>"
home="https://github.com/kiyoshispreclerg/xserver"

mkdir -p "$srv/DEBIAN" "$dev/DEBIAN"
cat > "$srv/DEBIAN/control" <<EOF
Package: xis-server
Version: $debver
Architecture: $arch
Maintainer: $maint
Section: x11
Priority: optional
Homepage: $home
Depends: $shl, xkb-data, x11-xkb-utils
Recommends: xinit, libgl1-mesa-dri, libegl1, default-logind | logind
Description: XiS X server, installed under $PREFIX
 A fork of the XLibre X server. Everything is installed under $PREFIX and
 $LOCALSTATEDIR, together with the libdrm it was built against and the
 libinput input driver, so it does not conflict with, replace or share modules
 with the X server of the distribution.
 .
 Start it from a console with startxis, or make the display manager use it
 with xis-dm.
EOF
cat > "$dev/DEBIAN/control" <<EOF
Package: xis-dev
Version: $debver
Architecture: $arch
Maintainer: $maint
Section: devel
Priority: optional
Homepage: $home
Depends: xis-server (= $debver)
Description: Development files for the XiS X server
 Headers, pkg-config files and X protocol headers installed under $PREFIX,
 for building X drivers against the XiS server.
EOF

cat > "$srv/DEBIAN/postrm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = purge ]; then
    rm -rf "$LOCALSTATEDIR"
fi
exit 0
EOF
chmod 0755 "$srv/DEBIAN/postrm"

for t in "$srv" "$dev"; do
    (cd "$t" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' | xargs -0 -r md5sum > DEBIAN/md5sums)
done

# ---- build ------------------------------------------------------------------
for name in xis-server xis-dev; do
    deb="$OUT/${name}_${debver}_${arch}.deb"
    dpkg-deb --root-owner-group -Zxz --build "$tmp/$name" "$deb" > /dev/null
    echo "make-debs: $deb"

    # Nothing may land outside PREFIX, LOCALSTATEDIR and the two helpers in
    # /usr/bin (their parent directories are fine).
    bad=""
    while IFS= read -r p; do
        p="/${p#./}"; p="${p%/}"
        [ "$p" = "/" ] || [ "$p" = "/." ] && continue
        case "$p/" in
            "$PREFIX"/*|"$LOCALSTATEDIR"/*) continue ;;      # inside
            /usr/bin/startxis/|/usr/bin/xis-dm/) continue ;; # the helpers
        esac
        case "$PREFIX/" in "$p"/*) continue ;; esac          # parent of PREFIX
        case "$LOCALSTATEDIR/" in "$p"/*) continue ;; esac   # parent of LOCALSTATEDIR
        [ "$p" = /usr ] || [ "$p" = /usr/bin ] && continue
        bad="$bad
$p"
    done < <(dpkg-deb -c "$deb" | awk '{print $6}')
    [ -z "$bad" ] || die "$name has files outside $PREFIX, $LOCALSTATEDIR and the helpers:$bad"
done

dpkg-deb -I "$OUT/xis-server_${debver}_${arch}.deb" | sed -n '/Package:/,/Description:/p' | cut -c1-200
ls -la "$OUT"
