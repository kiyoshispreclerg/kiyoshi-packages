#!/bin/bash
# First step in a build container: tune apt, install the packaging tools.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] && sed -i -E 's#https?://(archive|security)\.ubuntu\.com/ubuntu/?#http://azure.archive.ubuntu.com/ubuntu/#g' "$f"
done
printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' > /etc/apt/apt.conf.d/80-ci-retries
# apt-get build-dep needs deb-src entries
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue
    case "$f" in
        *.sources) sed -i 's/^Types: deb$/Types: deb deb-src/' "$f" ;;
        *) sed -i -E 's/^deb (.*)$/deb \1\ndeb-src \1/' "$f" ;;
    esac
done
apt-get update
apt-get install -y --no-install-recommends \
    build-essential fakeroot devscripts dpkg-dev debhelper git ca-certificates \
    perl quilt xauth x11-utils
