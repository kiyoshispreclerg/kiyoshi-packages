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

GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; chmod 700 "$GNUPGHOME"
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
# The pool keeps every version; the site gets only the newest of each package
# per suite and component (keeps Pages small; OBS alone is ~450 MB per version).
shopt -s nullglob
declare -A best_ver best_file
for deb in debs/*.deb; do
    base="$(basename "$deb")"; comp=main
    case "$base" in
        stable--*) comp=stable; mv "$deb" "debs/${base#stable--}"; deb="debs/${base#stable--}" ;;
        beta--*)   comp=beta;   mv "$deb" "debs/${base#beta--}";   deb="debs/${base#beta--}" ;;
    esac
    suite="$(scripts/suite-of.sh "$deb")"
    pkg="$(dpkg-deb -f "$deb" Package)"; ver="$(dpkg-deb -f "$deb" Version)"
    key="$comp|$suite|$pkg"
    if [ -z "${best_ver[$key]:-}" ] || dpkg --compare-versions "$ver" gt "${best_ver[$key]}"; then
        best_ver[$key]="$ver"; best_file[$key]="$deb"
    fi
done
for key in "${!best_file[@]}"; do
    IFS='|' read -r comp suite pkg <<<"$key"
    echo "publish: $comp/$suite $pkg ${best_ver[$key]}"
    reprepro -b repo-work -C "$comp" includedeb "$suite" "${best_file[$key]}"
done

# kiyoshi-packages-repo (key + apt source for the running system): in every
# suite's main, and as a fixed-name file at the site root for browser download.
owner="${self%%/*}"; url="https://${owner,,}.github.io/${self#*/}"
gpg --export "$keyid" > repo-work/key.gpg
scripts/build-repo-deb.sh repo-work/key.gpg repo-work/kiyoshi-packages-repo_all.deb "$url"
for suite in jammy noble bookworm trixie; do
    reprepro -b repo-work -C main includedeb "$suite" repo-work/kiyoshi-packages-repo_all.deb
done

mv repo-work/dists repo-work/pool site/ 2>/dev/null || true
cp repo-work/kiyoshi-packages-repo_all.deb site/
[ -d site/dists ] || { echo "publish: empty pool, creating empty suites"; reprepro -b repo-work export; mv repo-work/dists site/; mkdir -p site/pool; }
gpg --export "$keyid" > site/kiyoshi-packages.gpg
cp repo/index.html site/index.html
echo "publish: $(find site/pool -name '*.deb' | wc -l) packages in site/"
