#!/bin/bash
# build-source.sh NAME UPSTREAM-REPO UPSTREAM-REF
# Build one source package: the vendored debian/ directory of NAME
# (xlibre/packaging/NAME) around the official tree (github.com/X11Libre/UPSTREAM-REPO at UPSTREAM-REF),
# versioned with the target, with its build-dependencies installed from the
# distro and from what was built before. Output: $OUT/<component>/NAME/*.deb.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
name="$1"; repo="$2"; uref="$3"
src="$WORK/src/$name"
comp="$(component_of "$name")"
dest="$OUT/$comp/$name"

step "$name  (vendored debian/; code from $repo @ $uref)"
mkdir -p "$WORK/src"; rm -rf "$dest"; mkdir -p "$dest"
use_packaging "$name" "$src"
info="$name packaging=vendored"

if [ "$repo" != - ]; then
    tree="$WORK/src/tree-$name"
    tag="$(git_fetch "$tree" "$UPSTREAM_BASE/$repo.git" "$uref")"
    info="$info code=$repo@$tag($(git -C "$tree" rev-parse HEAD))"
    swap_tree "$src" "$tree"
    swap_version "$src" "${tag##*-}" "$repo $tag"
else
    ( cd "$src" && dch -b -v "$(dpkg-parsechangelog -l debian/changelog -S Version)~${TARGET}" \
        -D unstable --force-distribution "Rebuild for ${TARGET}" )
fi
echo "$info" >> "$WORK/BUILD-INFO"

adapt_control "$src"
install_build_deps "$src"
( cd "$src" && DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -b -uc -us -d )

# dpkg-buildpackage leaves the .deb files next to the source directory
# (debug-symbol packages are not published)
find "$WORK/src" -maxdepth 1 -name '*-dbgsym_*' -delete
find "$WORK/src" -maxdepth 1 -name '*.deb' -exec mv {} "$dest/" \;
find "$WORK/src" -maxdepth 1 \( -name '*.buildinfo' -o -name '*.changes' -o -name '*.udeb' -o -name '*.ddeb' \) -delete
refresh_localrepo
