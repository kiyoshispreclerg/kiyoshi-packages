#!/bin/bash
# build-repo-deb.sh KEYFILE OUT.deb URL
# Builds kiyoshi-packages-repo (arch all): the repository key plus a postinst
# that writes the apt source for the running system. URL is the site root.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
key="$1"; out="$2"; url="$3"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
chmod 755 "$tmp"
cp -r "$here/../repo-package/DEBIAN" "$tmp/DEBIAN"
sed -i "s|@URL@|$url|" "$tmp/DEBIAN/postinst"
install -D -m 0644 "$key" "$tmp/usr/share/keyrings/kiyoshi-packages.gpg"
dpkg-deb --root-owner-group --build "$tmp" "$out" >/dev/null
