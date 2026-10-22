[English](README.md) · **Português**

# kiyoshi-packages

Repositório apt com os programas do Kiyoshi, mais as bibliotecas de que eles
precisam para rodar em sistemas mais antigos. Tudo é compilado no GitHub para
cada alvo, assinado e servido pelo GitHub Pages.

## Sistemas suportados

| Sistema | Suite |
|---|---|
| Ubuntu 22.04 | `jammy` |
| Ubuntu 24.04 | `noble` |
| Debian 12 | `bookworm` |
| Debian 13 | `trixie` |

Devuan 5 e 6 usam as suites do Debian 12 e 13 (`bookworm`, `trixie`).
Arquitetura: `amd64`.

## Como usar

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/kiyoshi-packages.gpg \
    https://kiyoshispreclerg.github.io/kiyoshi-packages/kiyoshi-packages.gpg

# troque SUITE por jammy, noble, bookworm ou trixie
echo "deb [signed-by=/etc/apt/keyrings/kiyoshi-packages.gpg] https://kiyoshispreclerg.github.io/kiyoshi-packages SUITE main" |
    sudo tee /etc/apt/sources.list.d/kiyoshi-packages.list

sudo apt update
```

## Pacotes

| Pacote | O que é |
|---|---|
| `xis-server`, `xis-dev` | O servidor X XiS (um fork do XLibre), instalado em `/opt/xis` ao lado do Xorg do sistema, com a libdrm e o driver libinput de que precisa. Inclui `startxis` e `xis-dm`. |
| `kikarinhas` | [kikarinhas](https://github.com/kiyoshispreclerg/kikarinhas) |
| `kisnitch` | [kisnitch](https://github.com/kiyoshispreclerg/kisnitch) |
| `kiplay` | [kiplay](https://github.com/kiyoshispreclerg/kiplay) |
| `kidesktop-core`, `kidesktop-base` | [kidesktop](https://github.com/kiyoshispreclerg/kidesktop) |

As versões dos pacotes levam o alvo (por exemplo `0.4.0~ubuntu22.04`), então
cada sistema recebe um pacote compilado nele.

## Como funciona

Os projetos compilam seus próprios `.deb` a cada release; os pacotes do XiS são
compilados neste repositório. Todo `.deb` fica guardado como asset do Release
`pool`, e o workflow `Publish` reconstrói o repositório inteiro a partir dele
com `reprepro`, assina e publica no GitHub Pages.

- `xis/`: scripts de build dos pacotes do XiS
- `packages.yml`: projetos cujos releases são importados
- `scripts/`, `repo/`: ingest e publish
- `.github/workflows/`: CI

Notas de desenho e planos: [PLANO.md](PLANO.md).
