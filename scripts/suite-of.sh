#!/bin/bash
# suite-of.sh FILE.deb -> prints the suite (apt codename) from the target tag
# in the package version (README, seção 2, opção A). Exits 1 if there is none.
set -euo pipefail
ver="$(dpkg-deb -f "$1" Version)"
case "$ver" in
    *~ubuntu22.04*) echo jammy ;;
    *~ubuntu24.04*) echo noble ;;
    *~debian12*)    echo bookworm ;;
    *~debian13*)    echo trixie ;;
    *) echo "suite-of: $1: version '$ver' has no ~ubuntu22.04/~ubuntu24.04/~debian12/~debian13 tag" >&2; exit 1 ;;
esac
