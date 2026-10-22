#!/bin/bash
# Pull the .deb files of the latest Release of each project in packages.yml and
# attach them to this repository's `pool` Release (created if missing).
# Needs: gh (authenticated, GH_TOKEN), yq, dpkg-deb. Run from the repo root.
#
#   ONLY=kikarinhas scripts/ingest.sh      ingest a single project
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here/.."
self="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY (owner/name) not set}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

gh release view pool -R "$self" >/dev/null 2>&1 ||
    gh release create pool -R "$self" --title "pool" \
        --notes "Todos os .deb do repositório apt. Gerenciado por scripts/ingest.sh; não edite à mão."

existing="$(gh release view pool -R "$self" --json assets -q '.assets[].name')"
status=0

for name in $(yq -r '.projects[].name' packages.yml); do
    [ -z "${ONLY:-}" ] || [ "$ONLY" = "$name" ] || continue
    repo="$(yq -r ".projects[] | select(.name==\"$name\") | .repo" packages.yml)"
    echo "== $name ($repo)"
    dir="$work/$name"; mkdir -p "$dir"
    args=()
    for g in $(yq -r ".projects[] | select(.name==\"$name\") | .assets[]" packages.yml); do
        args+=(--pattern "$g")
    done
    if ! gh release download -R "$repo" "${args[@]}" -D "$dir" 2>/dev/null; then
        echo "   sem Release ou sem assets que casem; pulando" >&2; continue
    fi
    for ex in $(yq -r ".projects[] | select(.name==\"$name\") | .exclude[]?" packages.yml); do
        # shellcheck disable=SC2086
        rm -f "$dir"/$ex
    done
    for deb in "$dir"/*.deb; do
        [ -e "$deb" ] || continue
        b="$(basename "$deb")"
        if ! suite="$("$here/suite-of.sh" "$deb")"; then status=1; continue; fi
        if grep -qx "$b" <<<"$existing"; then echo "   $b já está no pool"; continue; fi
        echo "   + $b -> $suite"
        gh release upload pool -R "$self" "$deb"
    done
done
exit "$status"
