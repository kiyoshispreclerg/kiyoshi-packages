**English** · [Português](README.pt-BR.md)

# kiyoshi-packages

An apt repository with Kiyoshi's programs, XLibre (stable and beta) and the
libraries they need to run on older systems. Everything is built on GitHub for
each target, signed, and served from GitHub Pages.

## Supported systems

| System | Suite |
|---|---|
| Ubuntu 22.04 (Linux Mint 21) | `jammy` |
| Ubuntu 24.04 (Linux Mint 22) | `noble` |
| Ubuntu 26.04 | `resolute` |
| Debian 12 | `bookworm` |
| Debian 13 (LMDE 7) | `trixie` |

Linux Mint 21 and 22 use the Ubuntu 22.04 and 24.04 suites (`jammy`, `noble`); Devuan 5 and 6 use the Debian 12 and 13 suites (`bookworm`, `trixie`).
Architecture: `amd64`.

## Use it

### Easy way: one package

Download [kiyoshi-packages-repo_all.deb](https://kiyoshispreclerg.github.io/kiyoshi-packages/kiyoshi-packages-repo_all.deb)
and install it (double-click, or `sudo apt install ./kiyoshi-packages-repo_all.deb`).
It installs the key and writes the apt source for your system (Ubuntu 22.04/24.04/26.04,
Linux Mint 21/22, Debian 12/13, Devuan 5/6, LMDE 7); then `sudo apt update`. It asks which XLibre channel to
enable (none, `stable` or `beta`); change it later with
`sudo dpkg-reconfigure kiyoshi-packages-repo`. Removing the package removes the
source and the key.

### Manually

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/kiyoshi-packages.gpg \
    https://kiyoshispreclerg.github.io/kiyoshi-packages/kiyoshi-packages.gpg

# SUITE: jammy, noble, resolute, bookworm or trixie
# COMPONENTS: "main" for the programs only; add "stable" or "beta" (one of them) for XLibre
echo "deb [signed-by=/etc/apt/keyrings/kiyoshi-packages.gpg] https://kiyoshispreclerg.github.io/kiyoshi-packages SUITE main beta" |
    sudo tee /etc/apt/sources.list.d/kiyoshi-packages.list

sudo apt update
```

## XLibre

The XLibre X server, built for all four systems from the official
[X11Libre](https://github.com/X11Libre) release tags, with the `debian/`
packaging of [NexusSfan](https://github.com/xlibre-debian) and the same package
names as theirs (`xserver-xlibre-core`, `xserver-xlibre-input-libinput`,
`xserver-xlibre-video-amdgpu`, `xlibre`, ...), plus a newer `x11proto-dev`.

| Component | Contents |
|---|---|
| `stable` | XLibre 25.1.x and its drivers |
| `beta` | XLibre 25.2.x and its drivers |
| `main` | what both share (`x11proto-dev`) and the programs below |

Enable **one** of `stable` and `beta`, not both.

### xserver-xis-core

`xserver-xis-core` is the XiS server (Kiyoshi's XLibre fork) as a
drop-in replacement for `xserver-xlibre-core`, in both `stable` (based on XLibre
25.1) and `beta` (25.2). It provides, conflicts
with and replaces it, so you install the one you prefer and everything else
(drivers, `xserver-xlibre`) keeps working with either:

```sh
sudo apt install xserver-xlibre-core    # XLibre
sudo apt install xserver-xis-core        # XiS: replaces xserver-xlibre-core
```

## GTK2-ng

[gtk2-ng](https://git.devuan.org/Daemonratte/gtk2-ng) is the GTK2 revival
project (GTK 2.24.33 kept alive), built here for every system in the table as a
drop-in replacement for the distribution's GTK2: same library, same ABI, the
distribution's own packaging with the patches that still apply. The `gtk2-ng`
metapackage swaps the distribution's GTK2 packages for ours. Programs that need
`libgtk2.0-0` keep working, because our packages provide those names.

```sh
sudo apt install gtk2-ng
# to go back to the distribution's GTK2 (libgtk2.0-0t64 on Ubuntu 24.04/26.04 and Debian 13):
sudo apt install libgtk2.0-0 libgtk2.0-common libgtk2.0-bin
```

The versions look like `2.24.33+git20260903-1ng1~ubuntu24.04`: the date is the
one of the gtk2-ng commit they were built from.

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

- `xlibre/`: build scripts for XLibre (stable, beta)
- `packages.yml`: projects whose releases are pulled in
- `scripts/`, `repo/`: ingest and publish
- `.github/workflows/`: CI

Design notes: [PLANO.md](PLANO.md) (Portuguese).
