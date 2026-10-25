#!/bin/bash
# build-server.sh stable | beta | xis
#
# stable, beta: xlibre-server from the official X11Libre/xserver tag (STABLE_REF,
#         BETA_REF in versions.sh: the newest 25.1.x / 25.2.x tag) inside the
#         vendored debian/ (xlibre/packaging/xlibre-server[-stable]). All its binary packages are published.
# xis:    xserver-xis-core, the XiS fork (25.2 based) as a drop-in for the beta
#         xserver-xlibre-core: the same packaging with the XiS tree and the core
#         package renamed. It Provides/Conflicts/Replaces xserver-xlibre-core, so
#         the user installs one or the other and the rest of XLibre (drivers,
#         xserver-xlibre, ...) is satisfied by either. The other binary packages
#         are built too (dh_missing requires it) but discarded; only
#         xserver-xis-core_*.deb is kept.
#
# Environment (xis): XIS_URL, XIS_REF (versions.sh), XIS_REVISION (release
# number; empty = snapshot with the git hash in the version).
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mode="${1:?usage: build-server.sh stable|beta|xis}"
src="$WORK/src/xlibre-server-$mode"
tree="$WORK/src/tree-$mode"
mkdir -p "$WORK/src"

case "$mode" in
stable|beta)
    [ "$CHANNEL" = "$mode" ] || die "$mode server only in the $mode channel"
    if [ "$mode" = stable ]; then uref="$STABLE_REF"; pkg=xlibre-server-stable; else uref="$BETA_REF"; pkg=xlibre-server; fi
    dest="$OUT/$mode/xlibre-server"
    use_packaging "$pkg" "$src"
    tag="$(git_fetch "$tree" "$SERVER_URL" "$uref")"
    step "xlibre-server ($mode) = vendored $pkg + $tag"
    echo "xlibre-server($mode) packaging=vendored:$pkg code=xserver@$tag($(git -C "$tree" rev-parse HEAD))" >> "$WORK/BUILD-INFO"
    swap_tree "$src" "$tree"
    apply_patches "$src" "$mode"
    swap_version "$src" "${tag##*-}" "XLibre $tag"
    profiles=""
    ;;
xis)
    [ "$CHANNEL" = beta ] || die "XiS only in the beta channel"
    dest="$OUT/beta/xserver-xis-core"
    use_packaging xlibre-server "$src"
    xref="$(git_fetch "$tree" "$XIS_URL" "$XIS_REF")"
    sha="$(git -C "$tree" rev-parse --short=7 HEAD)"
    step "xserver-xis-core = vendored xlibre-server + XiS $xref ($XIS_URL)"
    echo "xserver-xis-core packaging=vendored:xlibre-server code=$XIS_URL@$xref($(git -C "$tree" rev-parse HEAD))" >> "$WORK/BUILD-INFO"
    swap_tree "$src" "$tree"

    # Rename the core package (not the udeb) in file names and contents.
    ( cd "$src/debian" || exit
      for f in xserver-xlibre-core.*; do
          [ -e "$f" ] && mv "$f" "xserver-xis-core.${f#xserver-xlibre-core.}"
      done
      grep -rlZ 'xserver-xlibre-core' . | xargs -0 perl -pi -e 's/xserver-xlibre-core(?!-udeb)/xserver-xis-core/g'
      perl -0pi -e '
          s/(Package: xserver-xis-core\n.*?)\nDescription: XLibre X server - core server\n/$1\nDescription: XiS X server - core server (fork of XLibre)\n XiS is a fork of the XLibre X server. This package is a drop-in replacement\n for xserver-xlibre-core: it provides, conflicts with and replaces it.\n .\n/s;
          s/(Package: xserver-xis-core\n.*?Provides:\n)/$1 xserver-xlibre-core (= \${binary:Version}),\n/s;
          s/(Package: xserver-xis-core\n.*?Conflicts:\n)/$1 xserver-xlibre-core,\n/s;
          s/(Package: xserver-xis-core\n.*?Replaces:\n)/$1 xserver-xlibre-core,\n/s;
          s/(Package: xserver-xis-core\n.*?) xserver-xlibre-common \(>= \$\{source:Version\}\)/$1 xserver-xlibre-common/s;
      ' control )

    # Version: 2:<upstream>-<packaging rev>xis<N>~<target>, e.g. 2:25.2.2-1xis2~jammy.
    # Same upstream version and Debian revision as xserver-xlibre-core, plus the
    # XiS revision N: it sorts above the upstream package of that version, rises
    # with every N, and any later upstream version (25.2.3) is above all of them.
    # A snapshot (no XIS_REVISION) is N=0 with the git hash.
    up="$(tree_version "$src")"
    [ -n "$up" ] || die "cannot read the version from the XiS meson.build"
    cur="$(dpkg-parsechangelog -l "$src/debian/changelog" -S Version)"
    prel="${cur##*-}"; prel="${prel%%[!0-9]*}"; prel="${prel:-1}"
    if [ -n "${XIS_REVISION:-}" ]; then rev="${prel}xis${XIS_REVISION}"; else rev="${prel}xis0~git${sha}"; fi
    ( cd "$src" && dch -b -v "2:${up}-${rev}~${TARGET}" -D unstable --force-distribution \
        "XiS ${xref} (${sha}) as xserver-xis-core" )
    profiles="noudeb"
    ;;
*) die "unknown mode $mode" ;;
esac

adapt_control "$src"
install_build_deps "$src"
( cd "$src" && DEB_BUILD_OPTIONS=nocheck DEB_BUILD_PROFILES="$profiles" dpkg-buildpackage -b -uc -us -d )

rm -rf "$dest"; mkdir -p "$dest"
if [ "$mode" = xis ]; then
    mv "$WORK"/src/xserver-xis-core_*.deb "$dest/" 2>/dev/null || die "xserver-xis-core .deb not produced"
else
    find "$WORK/src" -maxdepth 1 -name '*-dbgsym_*' -delete
    find "$WORK/src" -maxdepth 1 -name '*.deb' -exec mv {} "$dest/" \;
fi
find "$WORK/src" -maxdepth 1 \( -name '*.deb' -o -name '*.ddeb' -o -name '*.udeb' -o -name '*.buildinfo' -o -name '*.changes' \) -delete
refresh_localrepo
ls -l "$dest"
