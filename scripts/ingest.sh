#!/bin/bash
# Pull the .deb files of the latest Release of each project in packages.yml and
# attach them to this repository's `pool` Release (created if missing).
# Needs: gh (authenticated, GH_TOKEN), yq, jq, dpkg-deb. Run from the repo root.
#
# The target (suite) of a .deb comes from its version when it carries a tag
# (~ubuntu22.04, ~ubuntu24.04, ~debian12, ~debian13). If it doesn't, it is read
# from the file name the project gave it (ubuntu22.04, ubuntu-24.04, debian-12,
# debian13-devuan-..., etc.) and the tag is added to the version here, so the
# four builds of a release have different names. Anything else is skipped.
#
#   ONLY=kikarinhas scripts/ingest.sh      ingest a single project
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here/.."
self="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY (owner/name) not set}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

target_of_filename() {
    case "$1" in
        *ubuntu-22.04*|*ubuntu22.04*) echo ubuntu22.04 ;;
        *ubuntu-24.04*|*ubuntu24.04*) echo ubuntu24.04 ;;
        *debian-12*|*debian12*)       echo debian12 ;;
        *debian-13*|*debian13*)       echo debian13 ;;
    esac
}

# retag DEB -> prints the path of a .deb whose version carries the target tag
retag() {
    local deb="$1" ver t d pkg arch
    ver="$(dpkg-deb -f "$deb" Version)"
    if "$here/suite-of.sh" "$deb" >/dev/null 2>&1; then echo "$deb"; return 0; fi
    t="$(target_of_filename "$(basename "$deb")")"
    [ -n "$t" ] || return 1
    d="$(mktemp -d -p "$work")"
    dpkg-deb -R "$deb" "$d/x"
    sed -i "s/^Version: .*/Version: ${ver}~${t}/" "$d/x/DEBIAN/control"
    pkg="$(dpkg-deb -f "$deb" Package)"; arch="$(dpkg-deb -f "$deb" Architecture)"
    dpkg-deb --root-owner-group -Zxz -z3 -b "$d/x" "$d/${pkg}_${ver#*:}~${t}_${arch}.deb" >/dev/null
    echo "$d/${pkg}_${ver#*:}~${t}_${arch}.deb"
}

gh release view pool -R "$self" >/dev/null 2>&1 ||
    gh release create pool -R "$self" --title "pool" \
        --notes "Todos os .deb do repositório apt. Gerenciado por scripts/ingest.sh; não edite à mão."

existing="$(gh release view pool -R "$self" --json assets -q '.assets[].name')"

for name in $(yq -r '.projects[].name' packages.yml); do
    [ -z "${ONLY:-}" ] || [ "$ONLY" = "$name" ] || continue
    repo="$(yq -r ".projects[] | select(.name==\"$name\") | .repo" packages.yml)"
    echo "== $name ($repo)"
    dir="$work/$name"; mkdir -p "$dir"
    args=()
    for g in $(yq -r ".projects[] | select(.name==\"$name\") | .assets[]" packages.yml); do
        args+=(--pattern "$g")
    done
    # Newest stable release; only if the project has none yet, the newest
    # pre-release (`gh release download` without a tag would only ever take the
    # stable one, and fail for projects still at 0.x).
    rels="$(gh release list -R "$repo" -L 100 --json tagName,isPrerelease,isDraft 2>/dev/null || true)"
    tag="$(jq -r '[.[] | select(.isDraft | not)] | (map(select(.isPrerelease | not)) + map(select(.isPrerelease)))[0].tagName // empty' <<<"${rels:-[]}")"
    if [ -z "$tag" ]; then
        echo "::notice::$name: sem Release; pulando"; continue
    fi
    echo "   release $tag"
    if ! gh release download "$tag" -R "$repo" "${args[@]}" -D "$dir" 2>/dev/null; then
        echo "::notice::$name: sem Release ou sem assets que casem; pulando"; continue
    fi
    for ex in $(yq -r ".projects[] | select(.name==\"$name\") | .exclude[]?" packages.yml); do
        # shellcheck disable=SC2086
        rm -f "$dir"/$ex
    done
    for deb in "$dir"/*.deb; do
        [ -e "$deb" ] || continue
        if ! out="$(retag "$deb")"; then
            echo "::warning::$name: $(basename "$deb") não indica o alvo (nem na versão nem no nome); ignorado"; continue
        fi
        b="$(basename "$out")"
        if grep -qx "$b" <<<"$existing"; then echo "   $b já está no pool"; continue; fi
        echo "   + $b -> $("$here/suite-of.sh" "$out")"
        gh release upload pool -R "$self" "$out"
    done
done
