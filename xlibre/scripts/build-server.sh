#!/bin/bash
# build-server.sh stable | xis
#
# stable: xlibre-server 25.1.x. The Debian packaging of 25.1.7 with the upstream
#         tag from versions.sh swapped in; all its binary packages are published.
# xis:    xlibre-xis-core, the XiS fork (25.2 based) as a drop-in for the beta
#         xserver-xlibre-core: the current packaging with the XiS tree swapped
#         in and the core package renamed. It Provides/Conflicts/Replaces
#         xserver-xlibre-core, so the user installs one or the other and the
#         rest of XLibre (drivers, xserver-xlibre, ...) is satisfied by either.
#         The other binary packages are built too (dh_missing requires it) but
#         discarded; only xlibre-xis-core_*.deb is kept.
#
# Environment (xis): XIS_URL, XIS_REF (versions.sh), XIS_REVISION (release
# number; empty = snapshot with the git hash in the version).
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mode="${1:?usage: build-server.sh stable|xis}"
src="$WORK/src/xlibre-server-$mode"
tree="$WORK/src/tree-$mode"
mkdir -p "$WORK/src"

case "$mode" in
stable)
    [ "$CHANNEL" = stable ] || die "stable server only in the stable channel"
    dest="$OUT/stable/xlibre-server"
    step "xlibre-server (stable) = packaging $STABLE_PACKAGING_REF + $STABLE_UPSTREAM_REF"
    git_fetch "$tree" "$STABLE_UPSTREAM_URL" "$STABLE_UPSTREAM_REF"
    git_fetch "$src" "$STABLE_PACKAGING_URL" "$STABLE_PACKAGING_REF"
    echo "xlibre-server(stable) $STABLE_UPSTREAM_URL $(git -C "$tree" rev-parse HEAD) (packaging $(git -C "$src" rev-parse HEAD))" >> "$WORK/BUILD-INFO"
    swap_tree "$src" "$tree"
    up="${STABLE_UPSTREAM_REF##*-}"
    ( cd "$src" && dch -b -v "2:${up}-1~${TARGET}" -D unstable --force-distribution \
        "XLibre ${STABLE_UPSTREAM_REF} for ${TARGET}" )
    profiles=""
    ;;
xis)
    [ "$CHANNEL" = beta ] || die "XiS only in the beta channel"
    dest="$OUT/beta/xlibre-xis-core"
    step "xlibre-xis-core = packaging $PACKAGING_REF + XiS $XIS_REF ($XIS_URL)"
    git_fetch "$tree" "$XIS_URL" "$XIS_REF"
    git_fetch "$src" "$PACKAGING_URL" "$PACKAGING_REF"
    sha="$(git -C "$tree" rev-parse --short=7 HEAD)"
    echo "xlibre-xis-core $XIS_URL $(git -C "$tree" rev-parse HEAD) (packaging $(git -C "$src" rev-parse HEAD))" >> "$WORK/BUILD-INFO"
    swap_tree "$src" "$tree"

    # Rename the core package (not the udeb) in file names and contents.
    ( cd "$src/debian"
      for f in xserver-xlibre-core.*; do
          [ -e "$f" ] && mv "$f" "xlibre-xis-core.${f#xserver-xlibre-core.}"
      done
      grep -rlZ 'xserver-xlibre-core' . | xargs -0 perl -pi -e 's/xserver-xlibre-core(?!-udeb)/xlibre-xis-core/g'
      perl -0pi -e '
          s/(Package: xlibre-xis-core\n.*?)\nDescription: XLibre X server - core server\n/$1\nDescription: XiS X server - core server (XLibre fork)\n/s;
          s/(Package: xlibre-xis-core\n.*?Provides:\n)/$1 xserver-xlibre-core (= \${binary:Version}),\n/s;
          s/(Package: xlibre-xis-core\n.*?Conflicts:\n)/$1 xserver-xlibre-core,\n/s;
          s/(Package: xlibre-xis-core\n.*?Replaces:\n)/$1 xserver-xlibre-core,\n/s;
          s/(Package: xlibre-xis-core\n.*?) xserver-xlibre-common \(>= \$\{source:Version\}\)/$1 xserver-xlibre-common/s;
      ' control )

    # Version: 2:<upstream>-0xis<rev>~<target>  (snapshot: 0xis0~git<sha>~<target>)
    up="$(tree_version "$src")"
    [ -n "$up" ] || die "cannot read the version from the XiS meson.build"
    if [ -n "${XIS_REVISION:-}" ]; then rev="0xis$XIS_REVISION"; else rev="0xis0~git$sha"; fi
    ( cd "$src" && dch -b -v "2:${up}-${rev}~${TARGET}" -D unstable --force-distribution \
        "XiS ${XIS_REF} (${sha}) as xlibre-xis-core" )
    profiles="noudeb"
    ;;
*) die "unknown mode $mode" ;;
esac

adapt_control "$src"
install_build_deps "$src"
( cd "$src" && DEB_BUILD_OPTIONS=nocheck DEB_BUILD_PROFILES="$profiles" dpkg-buildpackage -b -uc -us -d )

rm -rf "$dest"; mkdir -p "$dest"
if [ "$mode" = xis ]; then
    mv "$WORK"/src/xlibre-xis-core_*.deb "$dest/" 2>/dev/null || die "xlibre-xis-core .deb not produced"
else
    find "$WORK/src" -maxdepth 1 -name '*-dbgsym_*' -delete
    find "$WORK/src" -maxdepth 1 -name '*.deb' -exec mv {} "$dest/" \;
fi
find "$WORK/src" -maxdepth 1 \( -name '*.deb' -o -name '*.ddeb' -o -name '*.udeb' -o -name '*.buildinfo' -o -name '*.changes' \) -delete
refresh_localrepo
ls -l "$dest"
