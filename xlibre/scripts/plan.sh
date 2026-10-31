#!/bin/bash
# First job of the XLibre workflow (no container): checks the commit/revision
# inputs before the hours of building, and decides what the build matrix is.
# Outputs (GITHUB_OUTPUT): commit=true|false (some core is built from a commit),
# matrix=<json>. Environment: the inputs as XLIBRE_STABLE_COMMIT, XLIBRE_STABLE_REV,
# XLIBRE_BETA_*, XIS_STABLE_*, XIS_BETA_* (see core_input in lib.sh), ONLY.
here="$(dirname "${BASH_SOURCE[0]}")"
CHANNEL=stable . "$here/lib.sh"

channels=()
for CHANNEL in stable beta; do
    used=0
    for kind in xlibre xis; do
        if [ -n "$(core_input "$kind" COMMIT)$(core_input "$kind" REV)" ]; then
            check_commit "$kind"; used=1
        fi
    done
    [ "$used" = 0 ] || channels+=("$CHANNEL")
done

if [ ${#channels[@]} -gt 0 ]; then
    [ -z "${ONLY:-}" ] || die "'only' cannot be combined with commits"
    commit=true
    chs="$(printf '%s\n' "${channels[@]}" | jq -R . | jq -sc .)"
else
    commit=false
    chs='["stable","beta"]'
fi
targets='[["ubuntu-22.04","ubuntu:22.04"],["ubuntu-24.04","ubuntu:24.04"],["ubuntu-26.04","ubuntu:26.04"],["debian-12","debian:12"],["debian-13","debian:13"]]'
matrix="$(jq -nc --argjson t "$targets" --argjson c "$chs" \
    '{include: [$c[] as $ch | $t[] | {name: .[0], image: .[1], channel: $ch}]}')"
echo "commit=$commit"; echo "matrix=$matrix"
{ echo "commit=$commit"; echo "matrix=$matrix"; } >> "${GITHUB_OUTPUT:-/dev/null}"
