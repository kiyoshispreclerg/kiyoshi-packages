#!/bin/bash
# Rebuild the apt repository from scratch out of every .deb in the `pool`
# Release and sign it. Output: ./site (dists/ + pool/ + key), ready for Pages.
# Needs: gh, reprepro, gnupg, dpkg-deb. Env: GITHUB_REPOSITORY, GH_TOKEN,
# GPG_PRIVATE_KEY (armored), GPG_PASSPHRASE (optional).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here/.."
self="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY not set}"
: "${GPG_PRIVATE_KEY:?GPG_PRIVATE_KEY secret not set}"

export GNUPGHOME="$(mktemp -d)"; chmod 700 "$GNUPGHOME"
trap 'gpgconf --kill gpg-agent 2>/dev/null || true; rm -rf "$GNUPGHOME" debs repo-work' EXIT
echo allow-loopback-pinentry > "$GNUPGHOME/gpg-agent.conf"
echo pinentry-mode loopback > "$GNUPGHOME/gpg.conf"
printf '%s' "$GPG_PRIVATE_KEY" | gpg --batch --import
keyid="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/ {print $5; exit}')"
[ -n "$keyid" ] || { echo "publish: no secret key imported" >&2; exit 1; }
if [ -n "${GPG_PASSPHRASE:-}" ]; then
    printf '%s' "$GPG_PASSPHRASE" > "$GNUPGHOME/pass"
    echo "passphrase-file $GNUPGHOME/pass" >> "$GNUPGHOME/gpg.conf"
fi

rm -rf debs repo-work site; mkdir -p debs repo-work/conf site
gh release download pool -R "$self" --pattern '*.deb' -D debs
sed "s/@KEYID@/$keyid/" repo/conf/distributions > repo-work/conf/distributions

# Pool assets are <file>.deb (component main) or stable--<file>.deb / beta--<file>.deb.
shopt -s nullglob
for deb in debs/*.deb; do
    base="$(basename "$deb")"; comp=main
    case "$base" in
        stable--*) comp=stable; mv "$deb" "debs/${base#stable--}"; deb="debs/${base#stable--}" ;;
        beta--*)   comp=beta;   mv "$deb" "debs/${base#beta--}";   deb="debs/${base#beta--}" ;;
    esac
    suite="$(scripts/suite-of.sh "$deb")"
    reprepro -b repo-work -C "$comp" includedeb "$suite" "$deb"
done

mv repo-work/dists repo-work/pool site/ 2>/dev/null || true
[ -d site/dists ] || { echo "publish: empty pool, creating empty suites"; reprepro -b repo-work export; mv repo-work/dists site/; mkdir -p site/pool; }
gpg --export "$keyid" > site/kiyoshi-packages.gpg
cp repo/index.html site/index.html
echo "publish: $(find site/pool -name '*.deb' | wc -l) packages in site/"
