**English** · [Português](README.pt-BR.md)

# kiyoshi-packages

An apt repository with Kiyoshi's programs, XLibre (stable and beta) and the
libraries they need to run on older systems. Everything is built on GitHub for
each target, signed, and served from GitHub Pages.

## Supported systems

| System | Suite |
|---|---|
| Ubuntu 22.04 | `jammy` |
| Ubuntu 24.04 | `noble` |
| Debian 12 | `bookworm` |
| Debian 13 | `trixie` |

Devuan 5 and 6 use the Debian 12 and 13 suites (`bookworm`, `trixie`).
Architecture: `amd64`.

## Use it

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/kiyoshi-packages.gpg \
    https://kiyoshispreclerg.github.io/kiyoshi-packages/kiyoshi-packages.gpg

# SUITE: jammy, noble, bookworm or trixie
# COMPONENTS: "main" for the programs only; add "stable" or "beta" (one of them) for XLibre
echo "deb [signed-by=/etc/apt/keyrings/kiyoshi-packages.gpg] https://kiyoshispreclerg.github.io/kiyoshi-packages SUITE main beta" |
    sudo tee /etc/apt/sources.list.d/kiyoshi-packages.list

sudo apt update
```

## XLibre

The XLibre X server, built for all four systems from the upstream source with
[NexusSfan's Debian packaging](https://github.com/xlibre-debian), with the same
package names as theirs (`xserver-xlibre-core`, `xserver-xlibre-input-libinput`,
`xserver-xlibre-video-amdgpu`, `xlibre`, ...), plus a newer `x11proto-dev`.

| Component | Contents |
|---|---|
| `stable` | XLibre 25.1.x and its drivers |
| `beta` | XLibre 25.2.x and its drivers, and `xlibre-xis-core` |
| `main` | what both share (`x11proto-dev`) and the programs below |

Enable **one** of `stable` and `beta`, not both.

### xlibre-xis-core

`xlibre-xis-core` is the XiS server (Kiyoshi's XLibre fork, based on 25.2) as a
drop-in replacement for the beta `xserver-xlibre-core`. It provides, conflicts
with and replaces it, so you install the one you prefer and everything else
(drivers, `xserver-xlibre`) keeps working with either:

```sh
sudo apt install xserver-xlibre-core    # XLibre beta
sudo apt install xlibre-xis-core        # XiS: replaces xserver-xlibre-core
```

## Programs

| Package | |
|---|---|
| `kikarinhas` | [kikarinhas](https://github.com/kiyoshispreclerg/kikarinhas) |
| `kisnitch` | [kisnitch](https://github.com/kiyoshispreclerg/kisnitch) |
| `kiplay` | [kiplay](https://github.com/kiyoshispreclerg/kiplay) |
| `kisword` | [kisword](https://github.com/kiyoshispreclerg/kisword) |
| `kiremote`, `kiremote-gtk`, `kiremote-kidesktop` | [kiremote](https://github.com/kiyoshispreclerg/kiremote) |
| `kidisks` | [kidisks](https://github.com/kiyoshispreclerg/kidisks) |
| `kidesktop-core`, `kidesktop-base` | [kidesktop](https://github.com/kiyoshispreclerg/kidesktop) |
| `obs-studio` | [Kiyoshi's fork](https://github.com/kiyoshispreclerg/obs-studio) |

Package versions carry the target (for example `0.4.0~ubuntu22.04`), so each
system gets a package built on that system.

## How it works

Projects build their own `.deb` files on release; XLibre and XiS are built in
this repository. Every `.deb` is stored as an asset of the `pool` Release, and
the `Publish` workflow rebuilds the whole repository from it with `reprepro`,
signs it, and deploys it to GitHub Pages.

- `xlibre/`: build scripts for XLibre (stable, beta) and `xlibre-xis-core`
- `packages.yml`: projects whose releases are pulled in
- `scripts/`, `repo/`: ingest and publish
- `.github/workflows/`: CI

Design notes: [PLANO.md](PLANO.md) (Portuguese).
