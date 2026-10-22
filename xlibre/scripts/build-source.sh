#!/bin/bash
# build-source.sh NAME URL REF
# Clone one Debian source package, tag its version with the target, install its
# build-dependencies (from the distro and from what was built before) and
# build the binary packages into $OUT/<component>/NAME.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
name="$1"; url="$2"; ref="$3"
src="$WORK/src/$name"
comp="$(component_of "$name")"
dest="$OUT/$comp/$name"
# stable channel: drivers and metapackage as they were before the 25.2 work
cutoff=""
if [ "$CHANNEL" = stable ] && [ "$comp" != main ]; then cutoff="$STABLE_CUTOFF"; fi

step "$name @ $ref"
mkdir -p "$WORK/src" "$dest"
git_fetch "$src" "$url" "$ref" "$cutoff"
echo "$name $url $(git -C "$src" rev-parse HEAD)" >> "$WORK/BUILD-INFO"

adapt_control "$src"
tag_changelog "$src"
install_build_deps "$src"
( cd "$src" && DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -b -uc -us -d )

# dpkg-buildpackage leaves the .deb files next to the source directory
# (debug-symbol packages are not published)
find "$WORK/src" -maxdepth 1 -name '*-dbgsym_*' -delete
find "$WORK/src" -maxdepth 1 -name '*.deb' -exec mv {} "$dest/" \;
find "$WORK/src" -maxdepth 1 \( -name '*.buildinfo' -o -name '*.changes' -o -name '*.udeb' -o -name '*.ddeb' \) -delete
refresh_localrepo
