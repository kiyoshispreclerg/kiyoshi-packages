#!/bin/bash
# build-server.sh stable | beta | xis
#
# stable, beta: xlibre-server from the official X11Libre/xserver tag (STABLE_REF,
#         BETA_REF in versions.sh: the newest 25.1.x / 25.2.x tag) inside
#         NexusSfan's debian/. All its binary packages are published.
# xis:    xlibre-xis-core, the XiS fork (25.2 based) as a drop-in for the beta
#         xserver-xlibre-core: the same packaging with the XiS tree and the core
#         package renamed. It Provides/Conflicts/Replaces xserver-xlibre-core, so
#         the user installs one or the other and the rest of XLibre (drivers,
#         xserver-xlibre, ...) is satisfied by either. The other binary packages
#         are built too (dh_missing requires it) but discarded; only
#         xlibre-xis-core_*.deb is kept.
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
    if [ "$mode" = stable ]; then uref="$STABLE_REF"; pref="$STABLE_PACKAGING_REF"; else uref="$BETA_REF"; pref="$BETA_PACKAGING_REF"; fi
    dest="$OUT/$mode/xlibre-server"
    git_fetch "$src" "$PACKAGING_BASE/xlibre-server.git" "$pref" >/dev/null
    tag="$(git_fetch "$tree" "$SERVER_URL" "$uref")"
    step "xlibre-server ($mode) = debian/ @ $pref + $tag"
    echo "xlibre-server($mode) packaging=$(git -C "$src" rev-parse HEAD) code=xserver@$tag($(git -C "$tree" rev-parse HEAD))" >> "$WORK/BUILD-INFO"
    swap_tree "$src" "$tree"
    apply_patches "$src" "$mode"
    swap_version "$src" "${tag##*-}" "XLibre $tag"
    profiles=""
    ;;
xis)
    [ "$CHANNEL" = beta ] || die "XiS only in the beta channel"
    dest="$OUT/beta/xlibre-xis-core"
    git_fetch "$src" "$PACKAGING_BASE/xlibre-server.git" "$BETA_PACKAGING_REF" >/dev/null
    xref="$(git_fetch "$tree" "$XIS_URL" "$XIS_REF")"
    sha="$(git -C "$tree" rev-parse --short=7 HEAD)"
    step "xlibre-xis-core = debian/ @ $BETA_PACKAGING_REF + XiS $xref ($XIS_URL)"
    echo "xlibre-xis-core packaging=$(git -C "$src" rev-parse HEAD) code=$XIS_URL@$xref($(git -C "$tree" rev-parse HEAD))" >> "$WORK/BUILD-INFO"
    swap_tree "$src" "$tree"

    # Rename the core package (not the udeb) in file names and contents.
    ( cd "$src/debian" || exit
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
        "XiS ${xref} (${sha}) as xlibre-xis-core" )
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
