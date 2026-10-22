# XiS packaging

Builds the XiS X server into `/opt/xis` and packages it as `.deb` files for
Ubuntu 22.04 / 24.04 and Debian 12 / 13, without touching the distribution's
own X server.

| script | what it does |
|---|---|
| `scripts/install-build-deps.sh` | `apt` build dependencies (same list on all four targets) |
| `scripts/build-xis.sh` | xorgproto, libdrm 2.4.123, the server (this tree) and `xf86-input-libinput`, into `PREFIX` (default `/opt/xis`) and a staging tree |
| `scripts/smoke-test.sh` | checks the installed tree: libraries resolve, libdrm comes from the prefix, drivers are in place, Xvfb answers |
| `scripts/make-debs.sh` | `xis-server` and `xis-dev` from the staging tree |
| `scripts/test-install.sh` | on a clean image: install, smoke test, install next to the distro's Xorg, purge |
| `files/startxis` | `startx` with the XiS server (`/usr/bin/startxis`) |
| `files/xis-dm` | `xis-dm enable / disable / status`: point LightDM or SDDM at XiS through a drop-in file (`/usr/bin/xis-dm`) |

Pinned inputs are in `versions.sh`. The workflow `.github/workflows/xis-targets.yml`
runs all of this in a container per target.

Locally (as a normal user, into a scratch prefix):

    PREFIX=$PWD/out/opt-xis LOCALSTATEDIR=$PWD/out/var WORK=$PWD/out/work \
        xis/scripts/build-xis.sh
    PREFIX=$PWD/out/opt-xis xis/scripts/smoke-test.sh
    PREFIX=$PWD/out/opt-xis LOCALSTATEDIR=$PWD/out/var WORK=$PWD/out/work \
        xis/scripts/make-debs.sh

What the packages do and don't do:

* Everything lives under `/opt/xis` and `/var/opt/xis`, plus the two helpers in
  `/usr/bin`. No `Conflicts`, `Replaces` or `Provides` on any X server package.
* XiS loads modules only from `/opt/xis/lib/xorg/modules`, but it reads
  `/etc/X11/xorg.conf` and `xorg.conf.d` like any Xorg; a `Driver` or
  `ModulePath` there meant for another server can make it fail (`xis-dm`
  warns about it).
* `xis-dm` never restarts the display manager; the change applies the next time
  it starts.
