#!/bin/bash
# Build, for this container's target and $CHANNEL (stable|beta): every source in
# sources.txt, then xserver-xis-core (XiS) for the same channel. A source marked `required = no`
# that fails is reported at the end and does not stop the others.
here="$(dirname "${BASH_SOURCE[0]}")"
. "$here/lib.sh"
mkdir -p "$OUT"; : > "$WORK/BUILD-INFO"
failed=()
# XiS alone still needs the x11proto-dev built from xorgproto
if [ -n "${ONLY:-}" ] && [[ " $ONLY " == *" xserver-xis-core "* ]]; then
    ONLY="$ONLY xorgproto"
fi
wanted() { [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]]; }

while read -r name repo uref required; do
    case "$name" in ''|'#'*) continue ;; esac
    wanted "$name" || continue
    if [ "$name" = xlibre-server ]; then
        cmd=("$here/build-server.sh" "$CHANNEL")
    else
        cmd=("$here/build-source.sh" "$name" "$repo" "$uref")
    fi
    if ! "${cmd[@]}"; then
        if [ "$required" = yes ]; then die "required source $name failed"; fi
        echo "::warning::$name failed on $TARGET ($CHANNEL)"
        failed+=("$name")
    fi
done < "$XLIBRE_DIR/sources.txt"

# XiS: the fork's tag that matches this channel's XLibre tag (skipped with a
# warning if the fork has none yet)
if wanted xserver-xis-core; then
    "$here/build-server.sh" xis
fi

printf '\n==== built for %s (%s)\n' "$TARGET" "$CHANNEL"
find "$OUT" -name '*.deb' | sort
[ ${#failed[@]} -eq 0 ] || { echo "not built: ${failed[*]}"; echo "${failed[*]}" > "$WORK/FAILED"; }
