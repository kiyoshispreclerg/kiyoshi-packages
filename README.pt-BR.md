[English](README.md) · **Português**

# kiyoshi-packages

Repositório apt com os programas do Kiyoshi, o XLibre (stable e beta) e as
bibliotecas de que eles precisam para rodar em sistemas mais antigos. Tudo é
compilado no GitHub para cada alvo, assinado e servido pelo GitHub Pages.

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

### Jeito fácil: um pacote só

Baixe o [kiyoshi-packages-repo_all.deb](https://kiyoshispreclerg.github.io/kiyoshi-packages/kiyoshi-packages-repo_all.deb)
e instale (duplo clique, ou `sudo apt install ./kiyoshi-packages-repo_all.deb`).
Ele instala a chave e grava a fonte do apt do seu sistema (Ubuntu 22.04/24.04,
Debian 12/13, Devuan 5/6); depois, `sudo apt update`. Ele pergunta qual canal do
XLibre ativar (nenhum, `stable` ou `beta`); para mudar depois:
`sudo dpkg-reconfigure kiyoshi-packages-repo`. Remover o pacote remove a fonte e a chave.

### Manualmente

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/kiyoshi-packages.gpg \
    https://kiyoshispreclerg.github.io/kiyoshi-packages/kiyoshi-packages.gpg

# SUITE: jammy, noble, bookworm ou trixie
# COMPONENTES: "main" só para os programas; some "stable" ou "beta" (um dos dois) para o XLibre
echo "deb [signed-by=/etc/apt/keyrings/kiyoshi-packages.gpg] https://kiyoshispreclerg.github.io/kiyoshi-packages SUITE main beta" |
    sudo tee /etc/apt/sources.list.d/kiyoshi-packages.list

sudo apt update
```

## XLibre

O servidor X XLibre, compilado para os quatro sistemas a partir das tags de
release oficiais do [X11Libre](https://github.com/X11Libre), com o empacotamento
`debian/` do [NexusSfan](https://github.com/xlibre-debian) e os mesmos nomes de
pacote dele (`xserver-xlibre-core`,
`xserver-xlibre-input-libinput`, `xserver-xlibre-video-amdgpu`, `xlibre`, ...),
mais um `x11proto-dev` mais novo.

| Componente | Conteúdo |
|---|---|
| `stable` | XLibre 25.1.x e seus drivers |
| `beta` | XLibre 25.2.x e seus drivers |
| `main` | o que os dois dividem (`x11proto-dev`) e os programas abaixo |

Ative **um só** entre `stable` e `beta`, não os dois.

<!-- XiS desligado por enquanto (workflow XLibre: build_xis)
### xserver-xis-core

O `xserver-xis-core` é o servidor XiS (o fork do XLibre do Kiyoshi, baseado no
25.2) como substituto direto do `xserver-xlibre-core` da beta. Ele fornece,
conflita e substitui esse pacote: você instala o que preferir e o resto
(drivers, `xserver-xlibre`) continua funcionando com qualquer um:

```sh
sudo apt install xserver-xlibre-core    # XLibre beta
sudo apt install xserver-xis-core        # XiS: substitui o xserver-xlibre-core
```
-->

## Programas

| Pacote | |
|---|---|
| `kikarinhas` | [kikarinhas](https://github.com/kiyoshispreclerg/kikarinhas) |
| `kisnitch` | [kisnitch](https://github.com/kiyoshispreclerg/kisnitch) |
| `kiplay` | [kiplay](https://github.com/kiyoshispreclerg/kiplay) |
| `kisword` | [kisword](https://github.com/kiyoshispreclerg/kisword) |
| `kiremote`, `kiremote-gtk`, `kiremote-kidesktop` | [kiremote](https://github.com/kiyoshispreclerg/kiremote) |
| `kidisks` | [kidisks](https://github.com/kiyoshispreclerg/kidisks) |
| `kidesktop-core`, `kidesktop-base` | [kidesktop](https://github.com/kiyoshispreclerg/kidesktop) |
| `obs-studio` | [fork do Kiyoshi](https://github.com/kiyoshispreclerg/obs-studio) |

As versões dos pacotes levam o alvo (por exemplo `0.4.0~ubuntu22.04`), então
cada sistema recebe um pacote compilado nele.

## Como funciona

Os projetos compilam seus próprios `.deb` a cada release; o XLibre e o XiS são
compilados neste repositório. Todo `.deb` fica guardado como asset do Release
`pool`, e o workflow `Publish` reconstrói o repositório inteiro a partir dele
com `reprepro`, assina e publica no GitHub Pages.

- `xlibre/`: scripts de build do XLibre (stable, beta) e do `xserver-xis-core`
- `packages.yml`: projetos cujos releases são importados
- `scripts/`, `repo/`: ingest e publish
- `.github/workflows/`: CI

Notas de desenho: [PLANO.md](PLANO.md).
