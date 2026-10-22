**English** · [Português](README.pt-BR.md)

# kiyoshi-packages

An apt repository with Kiyoshi's programs, plus the libraries they need to run
on older systems. Everything is built on GitHub for each target, signed, and
served from GitHub Pages.

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

# replace SUITE with jammy, noble, bookworm or trixie
echo "deb [signed-by=/etc/apt/keyrings/kiyoshi-packages.gpg] https://kiyoshispreclerg.github.io/kiyoshi-packages SUITE main" |
    sudo tee /etc/apt/sources.list.d/kiyoshi-packages.list

sudo apt update
```

## Packages

| Package | What it is |
|---|---|
| `xis-server`, `xis-dev` | The XiS X server (an XLibre fork), installed under `/opt/xis` next to the system's own Xorg, with the libdrm and libinput driver it needs. Includes `startxis` and `xis-dm`. |
| `kikarinhas` | [kikarinhas](https://github.com/kiyoshispreclerg/kikarinhas) |
| `kisnitch` | [kisnitch](https://github.com/kiyoshispreclerg/kisnitch) |
| `kiplay` | [kiplay](https://github.com/kiyoshispreclerg/kiplay) |
| `kidesktop-core`, `kidesktop-base` | [kidesktop](https://github.com/kiyoshispreclerg/kidesktop) |

Package versions carry the target (for example `0.4.0~ubuntu22.04`), so each
system gets a package built on that system.

## How it works

Projects build their own `.deb` files on release; the XiS packages are built in
this repository. Every `.deb` is stored as an asset of the `pool` Release, and
the `Publish` workflow rebuilds the whole repository from it with `reprepro`,
signs it, and deploys it to GitHub Pages.

- `xis/`: build scripts for the XiS packages
- `packages.yml`: projects whose releases are pulled in
- `scripts/`, `repo/`: ingest and publish
- `.github/workflows/`: CI

Design notes and plans: [PLANO.md](PLANO.md) (Portuguese).
