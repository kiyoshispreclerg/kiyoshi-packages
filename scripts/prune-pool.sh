#!/bin/bash
# Keep only the newest KEEP versions (default 2) of each package in the `pool`
# Release; delete the older assets. A GitHub Release holds at most 1000 assets,
# and publish.sh only uses the newest version anyway. Run it before uploading
# (a full pool refuses the upload) and after.
# Needs: gh (GH_TOKEN), GITHUB_REPOSITORY. DRY_RUN=1 only lists what would go.
#
# Asset names are [<component>--]<pkg>_<version>_<arch>.deb with the target tag
# at the end of the version (GitHub rewrites `~` to `.`: 1.2-3.ubuntu24.04).
# The group is component + target + package + arch. Names that do not fit
# that pattern are left alone.
set -euo pipefail

self="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY (owner/name) not set}"
keep="${KEEP:-2}"

gh release view pool -R "$self" >/dev/null 2>&1 || { echo "prune-pool: no pool Release yet"; exit 0; }
rid="$(gh api "repos/$self/releases/tags/pool" --jq .id)"
mapfile -t rows < <(gh api --paginate "repos/$self/releases/$rid/assets?per_page=100" --jq '.[] | "\(.id)\t\(.name)"')
echo "prune-pool: ${#rows[@]} assets in the pool (keeping $keep per package)"

lines=()
for row in "${rows[@]}"; do
    id="${row%%$'\t'*}"; name="${row#*$'\t'}"
    [[ "$name" == *.deb ]] || continue
    base="${name%.deb}"; comp=main
    case "$base" in stable--*) comp=stable; base="${base#stable--}" ;; beta--*) comp=beta; base="${base#beta--}" ;; esac
    IFS=_ read -r pkg ver arch extra <<<"$base"
    [ -n "$pkg" ] && [ -n "$ver" ] && [ -n "$arch" ] && [ -z "${extra:-}" ] || continue
    [[ "$ver" =~ ^(.+)\.(ubuntu[0-9.]+|debian[0-9]+)$ ]] || continue
    # group \t version-without-tag \t id \t name
    lines+=("$comp|${BASH_REMATCH[2]}|$pkg|$arch"$'\t'"${BASH_REMATCH[1]}"$'\t'"$id"$'\t'"$name")
done

[ "${#lines[@]}" -gt 0 ] || { echo "prune-pool: nothing to prune"; exit 0; }

# sort -V orders versions like dpkg does (including `~`); newest last in each group
deleted=0
prev=""; group=()
flush() {
    local n=${#group[@]} i f
    if [ "$n" -gt "$keep" ]; then
        for ((i = 0; i < n - keep; i++)); do
            IFS=$'\t' read -r _ _ id name <<<"${group[i]}"
            echo "prune-pool: - $name"
            [ -n "${DRY_RUN:-}" ] || gh api -X DELETE "repos/$self/releases/assets/$id" >/dev/null
            deleted=$((deleted + 1))
        done
    fi
    group=()
}
while IFS= read -r l; do
    g="${l%%$'\t'*}"
    if [ "$g" != "$prev" ]; then flush; prev="$g"; fi
    group+=("$l")
done < <(printf '%s\n' "${lines[@]}" | sort -t$'\t' -k1,1 -k2,2V)
flush

echo "prune-pool: $deleted old assets ${DRY_RUN:+would be }removed"
