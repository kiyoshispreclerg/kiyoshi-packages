#!/bin/bash
# Build, for this container's target and $CHANNEL (stable|beta): every source in
# sources.txt, then (beta only) xlibre-xis-core. A source marked `required = no`
# that fails is reported at the end and does not stop the others.
here="$(dirname "${BASH_SOURCE[0]}")"
. "$here/lib.sh"
mkdir -p "$OUT"; : > "$WORK/BUILD-INFO"
failed=()
wanted() { [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]]; }

while read -r name url ref required; do
    case "$name" in ''|'#'*) continue ;; esac
    wanted "$name" || continue
    if [ "$CHANNEL" = stable ] && [ "$name" = xlibre-server ]; then
        cmd=("$here/build-server.sh" stable)
    else
        cmd=("$here/build-source.sh" "$name" "$url" "$ref")
    fi
    if ! "${cmd[@]}"; then
        if [ "$required" = yes ]; then die "required source $name failed"; fi
        echo "::warning::$name failed on $TARGET ($CHANNEL)"
        failed+=("$name")
    fi
done < "$XLIBRE_DIR/sources.txt"

if [ "$CHANNEL" = beta ] && wanted xlibre-xis-core; then
    "$here/build-server.sh" xis
fi

printf '\n==== built for %s (%s)\n' "$TARGET" "$CHANNEL"
find "$OUT" -name '*.deb' | sort
[ ${#failed[@]} -eq 0 ] || { echo "not built: ${failed[*]}"; echo "${failed[*]}" > "$WORK/FAILED"; }
