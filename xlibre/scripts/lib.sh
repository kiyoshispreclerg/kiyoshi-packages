# shellcheck shell=bash
# Shared helpers; source it.
set -euo pipefail

XLIBRE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$PWD/xlibre-work}"
OUT="${OUT:-$WORK/debs}"           # finished .deb files: $OUT/<component>/<source>/
CHANNEL="${CHANNEL:?CHANNEL (stable|beta) not set}"
[ "$CHANNEL" = stable ] || [ "$CHANNEL" = beta ] || { echo "CHANNEL must be stable or beta" >&2; exit 1; }
. "$XLIBRE_DIR/versions.sh"
REPO="${REPO:-$WORK/localrepo}"    # flat apt repo of everything built so far
export DEBIAN_FRONTEND=noninteractive
# Who the packages we publish are maintained by (the Debian packaging we start
# from is credited as XSBC-Original-Maintainer; its copyright files stay as they are).
MAINTAINER="${MAINTAINER:-Kiyoshi Spreclerg <kiyoshi_pip@protonmail.com>}"
VCS_URL="${VCS_URL:-https://github.com/kiyoshispreclerg/kiyoshi-packages}"
export DEBEMAIL="${DEBEMAIL:-kiyoshi_pip@protonmail.com}" DEBFULLNAME="${DEBFULLNAME:-Kiyoshi Spreclerg}"

# TARGET: ubuntu22.04 | ubuntu24.04 | debian12 | debian13 (the tag put in versions)
. /etc/os-release
TARGET="${TARGET:-${ID}${VERSION_ID}}"

step() { printf '\n==== %s\n' "$*"; }
die()  { echo "error: $*" >&2; exit 1; }

# apt component a source is published in: what both channels share (xorgproto)
# goes in `main`, the rest in the channel's own component.
component_of() { case "$1" in xorgproto) echo main ;; *) echo "$CHANNEL" ;; esac; }

# Make the packages built so far visible to apt as a flat repository.
refresh_localrepo() {
    mkdir -p "$REPO"
    find "$OUT" -name '*.deb' -exec cp -u {} "$REPO"/ \;
    (cd "$REPO" && dpkg-scanpackages --multiversion . > Packages 2>/dev/null)
    echo "deb [trusted=yes] file:$REPO ./" > /etc/apt/sources.list.d/kiyoshi-local.list
    apt-get update -qq
}

# Debian version of the current source tree with the target tag appended, so the
# four builds of one release have different names (README, "Versões").
tag_changelog() { # DIR  [extra text]
    local cur
    cur="$(dpkg-parsechangelog -l "$1/debian/changelog" -S Version)"
    ( cd "$1" && dch -b -v "${cur}~${TARGET}" -D unstable --force-distribution \
        "Rebuild for ${TARGET}${2:+: $2}" )
}

# Drop build-dependencies that a target does not have. Only the ones known to
# be missing on old releases are touched; anything else must fail loudly.
adapt_control() { # DIR
    local c="$1/debian/control" orig
    # Maintainer: us; the original one is kept as XSBC-Original-Maintainer
    orig="$(sed -n 's/^Maintainer: //p' "$c" | head -1)"
    if [ -n "$orig" ] && [ "$orig" != "$MAINTAINER" ]; then
        sed -i "0,/^Maintainer: .*/s||Maintainer: $MAINTAINER\nXSBC-Original-Maintainer: $orig|" "$c"
    fi
    sed -i -e "s|^Vcs-Git: .*|Vcs-Git: $VCS_URL.git|" -e "s|^Vcs-Browser: .*|Vcs-Browser: $VCS_URL|" "$c"
    if ! apt-cache policy systemd-dev 2>/dev/null | grep -q 'Candidate: [^(]'; then
        sed -i '/^ *systemd-dev\b/d' "$c"
    fi
}

install_build_deps() { # DIR
    ( cd "$1" && apt-get build-dep -y --no-install-recommends ./ )
}

# resolve_ref URL REF -> REF, or for latest:<regex> the newest matching tag
resolve_ref() {
    case "$2" in
    latest:*)
        local re="${2#latest:}" t
        t="$(git ls-remote --tags --refs "$1" | sed -n 's#.*refs/tags/##p' | grep -E "^($re)\$" | sort -V | tail -1)"
        [ -n "$t" ] || die "$1: no tag matches $re"
        echo "$t" ;;
    *) echo "$2" ;;
    esac
}

# git_fetch DIR URL REF: shallow checkout of REF (branch, tag, sha, latest:<regex>)
# into DIR. Prints the resolved ref on stdout.
git_fetch() {
    local dir="$1" url="$2" ref
    ref="$(resolve_ref "$url" "$3")"
    rm -rf "$dir"
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
    git -C "$dir" fetch -q --depth 1 origin "$ref" >&2
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD >&2
    echo "$ref"
}

# swap_version DIR UPSTREAM_VERSION: add a changelog entry for a tree whose
# upstream version may differ from the one the packaging was written for. The
# packaging's own revision (-1+xlibre1, ...) is kept when the version is the same.
swap_version() {
    local dir="$1" up="$2" cur ep="" rest new
    cur="$(dpkg-parsechangelog -l "$dir/debian/changelog" -S Version)"
    case "$cur" in *:*) ep="${cur%%:*}:"; rest="${cur#*:}" ;; *) rest="$cur" ;; esac
    if [ "${rest%-*}" = "$up" ]; then new="${cur}~${TARGET}"; else new="${ep}${up}-1~${TARGET}"; fi
    ( cd "$dir" && dch -b -v "$new" -D unstable --force-distribution "${3:-Upstream $up} for ${TARGET}" )
}

# use_packaging NAME DIR: a fresh DIR holding the vendored Debian packaging of
# NAME (xlibre/packaging/NAME, see vendor-packaging.sh).
use_packaging() {
    [ -d "$XLIBRE_DIR/packaging/$1" ] || die "no vendored packaging for $1 (run vendor-packaging.sh)"
    rm -rf "$2"; mkdir -p "$2"
    cp -a "$XLIBRE_DIR/packaging/$1/." "$2/"
}

# swap_tree PACKAGING_DIR TREE_DIR: keep debian/ of the first, put the second's
# files around it (a different upstream under the same Debian packaging).
swap_tree() {
    find "$1" -mindepth 1 -maxdepth 1 ! -name debian -exec rm -rf {} +
    tar -C "$2" --exclude=.git --exclude=debian -cf - . | tar -C "$1" -xf -
    rm -rf "$1/.git"
    # keep only the packaging patches that still apply to the new tree
    [ -f "$1/debian/patches/series" ] || return 0
    local keep p
    keep="$(mktemp)"
    while read -r p; do
        case "$p" in ''|'#'*) continue ;; esac
        if patch -d "$1" -p1 --dry-run -s < "$1/debian/patches/$p" >/dev/null 2>&1; then
            echo "$p" >> "$keep"
        else
            echo "swap_tree: dropping patch $p (does not apply)"
        fi
    done < "$1/debian/patches/series"
    mv "$keep" "$1/debian/patches/series"
}

# apply_patches DIR NAME: apply xlibre/patches/NAME/*.diff to a source tree. These
# are backports of upstream fixes to an older release; a patch that does not apply
# stops the build (a newer upstream tag may already contain it: delete the patch).
apply_patches() {
    local f
    for f in "$XLIBRE_DIR/patches/$2"/*.diff; do
        [ -e "$f" ] || continue
        echo "applying $(basename "$f")"
        patch -d "$1" -p1 < "$f"
    done
}

# meson.build version of a tree
tree_version() { perl -0ne "print \$1 if /version:\s*'([0-9][^']*)'/" "$1/meson.build"; }
