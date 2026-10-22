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
export DEBEMAIL="${DEBEMAIL:-kiyoshi_pip@protonmail.com}" DEBFULLNAME="${DEBFULLNAME:-kiyoshi-packages}"

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
    local c="$1/debian/control"
    if ! apt-cache policy systemd-dev 2>/dev/null | grep -q 'Candidate: [^(]'; then
        sed -i '/^ *systemd-dev\b/d' "$c"
    fi
}

install_build_deps() { # DIR
    ( cd "$1" && apt-get build-dep -y --no-install-recommends ./ )
}

# git_fetch DIR URL REF [CUTOFF]: shallow checkout of REF; with CUTOFF (a date)
# the last commit of REF before that date.
git_fetch() {
    local dir="$1" url="$2" ref="$3" cutoff="${4:-}"
    rm -rf "$dir"
    if [ -n "$cutoff" ]; then
        git clone -q --filter=blob:none --no-checkout -b "$ref" "$url" "$dir"
        local rev
        rev="$(git -C "$dir" rev-list -1 --before="$cutoff" "origin/$ref")"
        [ -n "$rev" ] || die "$url: no commit of $ref before $cutoff"
        git -C "$dir" -c advice.detachedHead=false checkout -q "$rev"
    else
        git init -q "$dir"
        git -C "$dir" remote add origin "$url"
        git -C "$dir" fetch -q --depth 1 origin "$ref"
        git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
    fi
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

# meson.build version of a tree
tree_version() { perl -0ne "print \$1 if /version:\s*'([0-9][^']*)'/" "$1/meson.build"; }
