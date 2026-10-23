#!/bin/bash
# vendor-packaging.sh [NAME...]
# Copy the Debian packaging that the builds use into xlibre/packaging/<name>/,
# from github.com/xlibre-debian/<name> (NexusSfan's, MIT; see each
# debian/copyright). The builds read only that copy, so they do not depend on
# the origin staying online or unchanged. To update: run this, review the
# `git diff`, commit.
#
#   xlibre/scripts/vendor-packaging.sh                 every source in sources.txt
#   xlibre/scripts/vendor-packaging.sh xlibre-server   just that one
#
# What is copied: debian/ only, except for sources whose upstream column is `-`
# (the `xlibre` metapackage), which have no upstream tree and are copied whole.
# xlibre-server is kept twice: xlibre-server (PACKAGING_REF, for beta and XiS)
# and xlibre-server-stable (STABLE_PACKAGING_REF).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$here/versions.sh"
out="$here/packaging"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out"

fetch() { # DIR URL REF
    git init -q "$1"
    git -C "$1" remote add origin "$2"
    git -C "$1" fetch -q --depth 1 origin "$3"
    git -C "$1" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

vendor() { # NAME SOURCE-REPO REF WHOLE(yes|no)
    local name="$1" repo="$2" ref="$3" whole="$4" d="$tmp/$1"
    echo "== $name  ($repo @ $ref)"
    fetch "$d" "$PACKAGING_BASE/$repo.git" "$ref"
    rm -rf "${out:?}/$name"; mkdir -p "$out/$name"
    if [ "$whole" = yes ]; then
        tar -C "$d" --exclude=.git -cf - . | tar -C "$out/$name" -xf -
    else
        [ -d "$d/debian" ] || { echo "no debian/ in $repo" >&2; exit 1; }
        cp -a "$d/debian" "$out/$name/debian"
    fi
    # record where it came from (replace this source's line)
    touch "$out/SOURCES"
    grep -v "^$name " "$out/SOURCES" > "$tmp/SOURCES" || true
    echo "$name $PACKAGING_BASE/$repo.git $(git -C "$d" rev-parse HEAD)" >> "$tmp/SOURCES"
    sort "$tmp/SOURCES" > "$out/SOURCES"
}

sel=("$@")
while read -r name repo _ _; do
    case "$name" in ''|'#'*) continue ;; esac
    if [ ${#sel[@]} -gt 0 ] && [[ " ${sel[*]} " != *" $name "* ]]; then
        [ "$name" = xlibre-server ] && [[ " ${sel[*]} " == *" xlibre-server-stable "* ]] && vendor xlibre-server-stable xlibre-server "$STABLE_PACKAGING_REF" no
        continue
    fi
    if [ "$name" = xlibre-server ]; then
        vendor xlibre-server xlibre-server "$PACKAGING_REF" no
        vendor xlibre-server-stable xlibre-server "$STABLE_PACKAGING_REF" no
    elif [ "$repo" = - ]; then
        vendor "$name" "$name" "$PACKAGING_REF" yes
    else
        vendor "$name" "$name" "$PACKAGING_REF" no
    fi
done < "$here/sources.txt"
