# kiyoshi-packages: plano

> **Atualização (22/10/2026):** este é o plano inicial. Duas decisões mudaram:
> o XiS **não** vai mais em `/opt/xis`: virou o pacote `xlibre-xis-core`, no
> caminho padrão do sistema, substituto direto do `xserver-xlibre-core` da beta
> (25.2); e o XLibre upstream entrou, em dois canais (`stable` 25.1, `beta`
> 25.2), como componentes do apt. As seções 6 e 8 estão superadas por
> `xlibre/`; o `startxis`/`xis-dm` do desenho antigo foram abandonados.


Repositório apt (`.deb`) dos projetos do Kiyoshi, para **Ubuntu 22.04, Ubuntu
24.04, Debian 12 e Debian 13** (e Devuan 5 e 6, que usam os mesmos pacotes de
Debian 12 e 13), tudo construído, guardado, assinado e servido pelo GitHub.

Este arquivo é o ponto de partida do repositório: explica o desenho, o que vem
de onde, o que já existe pronto e o que falta decidir. O que **não** está
escrito aqui como decidido está na seção [Decisões em aberto](#decisões-em-aberto).

> Estado em 22/10/2026: nada deste repositório existe ainda além deste
> documento. O empacotamento do XiS (`xserver`, branch `experiments`) foi escrito
> e testado só até onde dá localmente (Ubuntu 22.04); **os workflows dele ainda
> não rodaram no GitHub** (houve um incidente de Actions na hora do push).

---

## 0. Operação: criar e atualizar o pool

O **pool** é o Release `pool` deste repositório: uma pasta de arquivos `.deb`
(assets), que guarda **todas as versões**. O repositório apt que os usuários
veem é reconstruído do zero a partir dele pelo workflow **Publish**, que
mantém no site só a versão mais nova de cada pacote por suite e componente
(o OBS sozinho tem ~450 MB por versão; o Pages não aguenta o histórico).

Nomes dos assets no pool: `<arquivo>.deb` para o componente `main`,
`stable--<arquivo>.deb` e `beta--<arquivo>.deb` para os componentes `stable` e
`beta`. A suite vem do `~ubuntu22.04`, `~ubuntu24.04`, `~debian12` ou
`~debian13` na versão.

Tudo se faz em **Actions → (workflow) → Run workflow**.

### 0.1 Primeira vez

1. Pages: *Settings → Pages → Source: GitHub Actions*.
2. Segredos `GPG_PRIVATE_KEY` (e `GPG_PASSPHRASE`) em *Settings → Secrets and
   variables → Actions*; *Workflow permissions* em "Read and write".
3. Rode **Ingest** (cria o Release `pool`, traz seus programas e já chama o
   Publish).
4. Rode **XLibre** com `release` marcado (seção 0.3). Ao final ele chama o Publish.
5. Confira `https://<usuario>.github.io/kiyoshi-packages/dists/<suite>/Release`
   e um `apt update` num container de cada alvo.

### 0.2 Seus programas (kikarinhas, kisnitch, kiplay, kisword, kiremote, kidisks, kidesktop e o fork do OBS)

Criar ou atualizar é a mesma coisa:

1. No repositório do projeto, publique um Release novo (tag `v*`; no OBS, a
   tag da versão). O `release.yml` dele compila os `.deb` dos 4 alvos e os
   anexa ao Release. **Pré-releases valem**: o ingest pega o Release mais
   novo, marcado ou não como pré-release.
2. Traga para o pool, de um destes jeitos:
   * **Ingest** manual (campo `only` = nome em `packages.yml`, ou vazio para todos);
   * o **cron diário** do Ingest (05:17 UTC), sem fazer nada;
   * o projeto avisa na hora, com `repository_dispatch` (precisa de um token com
     permissão neste repositório):
     ```sh
     gh api repos/<usuario>/kiyoshi-packages/dispatches \
         -f event_type=project-released -f client_payload[project]=kikarinhas
     ```
3. O Ingest anexa ao `pool` o que ainda não está lá (pelo nome do arquivo) e
   chama o Publish. Só assets que casem com `assets:` de `packages.yml` entram
   (o OBS usa `obs-studio-*-Linux-*.deb`, que deixa de fora os `*-dbgsym-*.ddeb`).

O alvo vem do `~alvo` na versão do `.deb` ou, se não houver, do **nome do
arquivo** (`ubuntu22.04`, `ubuntu-24.04`, `debian-12`, `debian13-devuan-...`):
nesse caso o ingest regrava a `Version:` acrescentando `~alvo`, para os quatro
`.deb` de um release terem nomes diferentes. Arquivo sem alvo reconhecível é
ignorado com um aviso (o alvo `ubuntu26.04` do kisword cai aqui).

**Projeto novo:** acrescente-o em `packages.yml` (`repo`, `assets`, e `exclude`
se o Release tiver `.deb` que não deve entrar).

### 0.3 XLibre `stable` e `beta`

Ficam no workflow **XLibre**: compila os 4 alvos nos 2 canais, instala cada
conjunto num container limpo (e testa a troca para o `xlibre-xis-core`) e, só
com `release` marcado, anexa os `.deb` ao pool e chama o Publish. Um push em
`xlibre/` compila e testa, mas **não publica**.

* **beta (25.2.x):** é a ponta do ramo `xlibre/latest` de cada repositório de
  `github.com/xlibre-debian/*` (lista e ordem em `xlibre/sources.txt`). Para
  atualizar, basta rodar o workflow de novo com `release`: a versão sai do
  `debian/changelog` deles. Para travar uma versão, troque `xlibre/latest` por
  um sha na terceira coluna de `sources.txt`.
* **stable (25.1.x):** o servidor é a tag de `X11Libre/xserver` em
  `STABLE_UPSTREAM_REF` (`xlibre/versions.sh`, hoje `xlibre-xserver-25.1.9`)
  dentro do empacotamento fixado em `STABLE_PACKAGING_REF`. Para um 25.1.x
  novo, mude só `STABLE_UPSTREAM_REF`. Os drivers e o metapacote vêm do último
  commit antes de `STABLE_CUTOFF`; se um driver parar de compilar, ajuste a data.
* Drivers marcados `no` em `sources.txt` que falham não travam o resto: o log
  mostra `not built: ...` e um aviso.

### 0.4 XiS (`xlibre-xis-core`)

Sai do mesmo workflow **XLibre**, no canal `beta`: o empacotamento da beta com
a árvore do `kiyoshispreclerg/xserver`, trocado o nome do pacote. Entradas:

* `xis_ref`: ramo, tag ou sha do `xserver` (vazio = `experiments`);
* `revision`: `1`, `2`, ... para uma versão de release (`2:25.2.0-0xis1~ubuntu22.04`);
  vazio gera um **snapshot** (`-0xis0~git<sha>~alvo`), que sempre perde para um
  release;
* `only`: `xlibre-xis-core` compila só o XiS (e o `xorgproto` de que ele precisa),
  sem o teste de instalação; ideal para atualizar o XiS sem refazer o XLibre
  inteiro. Com `release` marcado, só o XiS é anexado ao pool.

Receita para publicar uma versão do XiS: dê push no `xserver`, rode **XLibre**
com `xis_ref` = o commit ou tag, `revision` = próximo número, `only` =
`xlibre-xis-core` e `release` marcado.

### 0.5 Retirar uma versão

Apague o asset do Release `pool` (*Releases → pool → editar → remover o
arquivo*) e rode **Publish**. Como o site mostra só a versão mais nova, apagar
a mais nova faz a anterior voltar.

### 0.6 Quando algo não aparece no `apt`

* Veja o log do Publish: ele lista `publish: <componente>/<suite> <pacote> <versão>` para tudo o que entrou.
* `apt update` reclamando de assinatura: a chave pública do site vem do segredo
  `GPG_PRIVATE_KEY`; se a chave mudou, o usuário reinstala o `kiyoshi-packages.gpg`.
* Pacote sem alvo na versão ou no nome do arquivo: aparece como aviso no Ingest.

---

## 1. O que entra e o que não entra

| Pacote | Origem | Estado do empacotamento |
|---|---|---|
| **xis-server**, **xis-dev** (servidor XiS em `/opt/xis`, com libdrm 2.4.123 e o driver libinput, mais `startxis` e `xis-dm`) | `github.com/kiyoshispreclerg/xserver`, pasta `packaging/` na branch `experiments` | escrito; compila e passa o teste de fumaça local (Ubuntu 22.04). CI dos 4 alvos ainda não rodou |
| **XLibre "normal"** (`xserver-xlibre-core` e drivers, integrados ao sistema, sem `/opt`) | `github.com/xlibre-debian/xlibre-server`, branch `xlibre/latest`, pasta `debian/` | **não começado**. Ver seção 6 |
| **Dependências que as distros não têm** (xorgproto novo, etc.) | upstream | levantadas (seção 5); só o necessário para o XiS está no script |
| **kikarinhas** | `github.com/kiyoshispreclerg/kikarinhas` | já gera `.deb` para os 4 alvos em cada tag `v*`, com teste de instalação |
| **kisnitch** | `github.com/kiyoshispreclerg/kisnitch` | idem |
| **kiplay** | `github.com/kiyoshispreclerg/kiplay` | idem |
| **kidesktop** (`kidesktop-core`, `kidesktop-base`) | `github.com/kiyoshispreclerg/kidesktop` (na máquina: `~/Downloads/xnsguard`) | já gera `.deb` para os 4 alvos (`debian/` + `scripts/build-deb.sh`) |
| **obs-studio** (fork) | `github.com/kiyoshispreclerg/obs-studio`, branch `upstream-30.1.2` | **não começado**. Ver seção 7 |

Ficam de fora (por decisão): qualquer outro projeto da pasta `kiyoshi-forks`.

---

## 2. Um repositório para os 4 alvos, ou um por alvo?

**Um só.** O apt foi feito para isso: um mesmo repositório tem várias *suites*,
cada uma com seus próprios índices, e um `pool/` de arquivos compartilhado.

```
https://<usuario>.github.io/kiyoshi-packages/
├── kiyoshi-packages.gpg           chave pública (a que assina)
├── dists/
│   ├── jammy/      (Ubuntu 22.04)   main/binary-amd64/Packages, Release, InRelease
│   ├── noble/      (Ubuntu 24.04)
│   ├── bookworm/   (Debian 12, e Devuan 5 daedalus)
│   └── trixie/     (Debian 13, e Devuan 6 excalibur)
└── pool/main/<letra>/<pacote>/<pacote>_<versão>_amd64.deb
```

Quem usa:

```
# Ubuntu 22.04
deb [signed-by=/etc/apt/keyrings/kiyoshi-packages.gpg] https://<usuario>.github.io/kiyoshi-packages jammy main
```

Troca-se só o nome da suite: `noble`, `bookworm` ou `trixie`. **Devuan usa as
suites de Debian** (daedalus → `bookworm`, excalibur → `trixie`); é o que os
seus projetos já assumem nos `release.yml` (`debian:bookworm` e `debian:trixie`
como base "do Devuan").

### A armadilha: mesmo nome e versão, conteúdo diferente

Cada `.deb` é compilado em uma distro diferente, então o mesmo
`kikarinhas_0.4.0_amd64.deb` sai com `Depends` e binário diferentes em cada alvo.
Num `pool/` único isso **colide**: o `reprepro` recusa adicionar um arquivo de
mesmo nome com checksum diferente. Duas saídas:

* **A (recomendada): a versão carrega o alvo**, como já fiz no XiS:
  `0.4.0~ubuntu22.04`, `0.4.0~ubuntu24.04`, `0.4.0~debian12`, `0.4.0~debian13`.
  Cada arquivo tem nome próprio, o pool continua único, e o `~` garante que uma
  versão posterior (`0.4.1~...`) sempre ganha. Exige mudar a linha de versão dos
  `build-deb.sh` de cada projeto (hoje eles só renomeiam o arquivo, a versão
  dentro do pacote é a mesma nos 4). É pequeno.
* **B: um repositório apt por alvo**, cada um com seu `pool/` e sua suite:
  `.../ubuntu-22.04/`, `.../ubuntu-24.04/`, `.../debian-12/`, `.../debian-13/`.
  Não precisa mexer nas versões, mas são 4 linhas de `sources.list` diferentes
  em estrutura, 4 árvores para manter e 4× mais arquivos publicados (o que
  pesa nos limites do Pages). É o que o NexusSfan faz (um site por sistema).

Fica a **A**, salvo se você preferir não mexer nos projetos.

---

## 3. Arquitetura: tudo no GitHub

```
 projetos (kikarinhas, kisnitch, kiplay, kidesktop, ...)      xserver (XiS)
   cada um continua gerando seus .deb nas tags v*                  │
                    │                                              │
                    ▼                                              ▼
            GitHub Releases dos projetos          kiyoshi-packages/xis (build aqui)
                    │      baixa os .deb                           │
                    └─────────────────┬────────────────────────────┘
                                      ▼
                       kiyoshi-packages: workflow "ingest"
                       guarda cada .deb como asset de um Release
                                      ▼
                       workflow "publish": reconstrói o repositório
                       (reprepro + assinatura GPG) a partir de TODOS os Releases
                                      ▼
                       GitHub Pages (actions/deploy-pages): dists/ + pool/
```

| Função | Onde | Por quê |
|---|---|---|
| Compilar | Actions, container de cada distro | já funciona assim nos seus projetos e no XiS |
| Guardar os `.deb` | **Releases** do `kiyoshi-packages` | sem limite de total (cada arquivo até 2 GB), não incha o histórico do git |
| Montar o repositório | Actions, `reprepro` | simples, gera `Release`/`InRelease` assinado |
| Servir | **GitHub Pages**, publicado por `deploy-pages` | o site é regerado inteiro a cada publicação, sem histórico de binários |

O `publish` não guarda estado entre execuções: ele lista os Releases, baixa os
`.deb` de cada versão que deve existir, e monta o repositório do zero. Para
retirar uma versão basta apagar o asset.

Alternativa mais simples (é o que o NexusSfan faz): guardar o repositório numa
branch `gh-pages` e dar push dos `.deb` nela. Funciona, mas o histórico do git
cresce a cada versão; só segura se a branch for recriada do zero a cada
publicação (push forçado de um commit único).

**Limites do GitHub a conferir antes de crescer** (valores publicados por eles,
de memória): o site do Pages tem limite flexível de 1 GB e 100 GB de banda por
mês, e não é uma CDN de pacotes. Com 4 alvos × alguns pacotes pequenos, a conta
fecha folgada; o **obs-studio** é o que pesa (dezenas de MB por alvo). Se
passar, o caminho é um host de repositório próprio (o repositório apt é só
arquivos estáticos, migra sem mudar nada para o usuário além da URL).

### Assinatura (obrigatória)

* O apt só aceita um repositório sem assinatura com `[trusted=yes]`, o que não
  se deve recomendar. Gere **uma chave GPG só para este repositório**:
  ```
  gpg --quick-generate-key "kiyoshi-packages <kiyoshi_pip@protonmail.com>" ed25519 sign 3y
  gpg --armor --export-secret-keys <ID>   # vai para o segredo GPG_PRIVATE_KEY
  gpg --export <ID> > kiyoshi-packages.gpg   # a pública, publicada no site
  ```
* **A chave privada nunca entra no git**: só como *secret* do repositório
  (`GPG_PRIVATE_KEY`, e `GPG_PASSPHRASE` se tiver senha).
* O usuário instala a pública em `/etc/apt/keyrings/`. Guarde um backup da
  privada fora do GitHub; perdê-la obriga todos a reconfigurar.

---

## 4. Como cada projeto entra

### 4.1 kikarinhas, kisnitch, kiplay, kidesktop: **ingerir**, não recompilar

Cada um já tem um `release.yml` completo: em cada tag `v*` compila nos 4 alvos
(`ubuntu-22.04`, `ubuntu-24.04`, `debian:bookworm`, `debian:trixie`), calcula o
`Depends` com `dpkg-shlibdeps`, **instala o `.deb` numa imagem limpa de cada
alvo e roda o programa** antes de publicar no Release do projeto. Não há razão
para refazer isso aqui.

Fase 1 do `kiyoshi-packages`: um workflow que, dada uma lista
(`packages.yml`: repositório, padrão do nome do asset), baixa os `.deb` do último
Release de cada projeto, confere (`dpkg-deb -I`, suite pelo sufixo `~alvo`),
e anexa ao Release do `kiyoshi-packages`. A fonte da verdade continua em cada
projeto; este repositório só distribui.

O que muda nos projetos, uma vez: **colocar o alvo na versão** (seção 2, opção A).
Hoje eles fazem `mv "$f" "${f%_*.deb}_<alvo>_${f##*_}"`, ou seja, só o *nome do
arquivo*; o `Version:` dentro do pacote é igual nos quatro.

Particularidades:

* **kidesktop** produz dois pacotes (`kidesktop-core` e `kidesktop-base`), com
  `debian/` próprio. O `kidesktop-core` declara `Provides/Conflicts/Replaces:
  kidesktop` (substitui um pacote antigo com esse nome). A pasta `dist/` do
  projeto tem `.deb` antigos, inclusive um `kidesktop_0.0.0...` que não deve ser
  importado.
* **kisnitch** conversa com a interface do OpenSnitch; confira se nenhum
  pacote deste repositório conflita com o `opensnitch` das distros.
* Os que conferi (kikarinhas) instalam em `PREFIX=/usr`, então ocupam o mesmo
  espaço de nomes de arquivos que os pacotes das distros. Não achei sobreposição,
  mas vale um teste de `dpkg -L` contra os pacotes das distros.

### 4.2 XiS: **construir aqui**

O empacotamento já está escrito, na branch `experiments` do `xserver`
(pasta `packaging/`). Ele é movido para este repositório (seção 8) e o código
do servidor passa a ser baixado por referência fixa (`XIS_REF`), em vez de
estar na mesma árvore. Detalhes do que faz e como foi verificado: seção 8.

---

## 5. Pacotes que as distros não têm (o que o XiS exige)

Levantamento feito comparando os mínimos do `meson.build` do servidor com o que
cada distro publica (arquivos oficiais de Debian e Ubuntu, 22/10/2026):

| Dependência | Mínimo exigido | Ubuntu 22.04 | Ubuntu 24.04 | Debian 12 | Debian 13 |
|---|---|---|---|---|---|
| **xorgproto** | **2024.1** (presentproto ≥ 1.4, fixesproto ≥ 6.1) | 2021.5 ✗ | 2023.2 ✗ | 2022.1 ✗ | 2024.1 ✓ |
| libdrm | 2.4.89; **2.4.122+** liga `LIBDRM_HAS_PLANE_SIZE_HINTS` | 2.4.113 | 2.4.125 | 2.4.114 | 2.4.124 |
| meson | 0.61.0 | 0.61.2 (no limite) | 1.3.2 | 1.0.1 | 1.7.0 |
| libxfont (xfont2), libxcvt, pixman, nettle, libunwind, libpciaccess, libxshmfence, libepoxy, libxkbfile, dbus, libinput (driver pede ≥ 1.11) | mínimos baixos | ✓ | ✓ | ✓ | ✓ |
| libseat | 0.9.1, só se `seatd_libseat=true` (não usamos; é logind) | n/a | n/a | n/a | n/a |

Como resolvemos hoje, no pacote do XiS:

* **xorgproto**: compilado no commit `cc9ce4a0cc3c99488d26b77a4f27192b0663cafa`
  (a versão que você usa), só em tempo de build. Os headers vão para o pacote
  `xis-dev`, não para o de execução.
* **libdrm 2.4.123**: compilado e instalado **dentro de `/opt/xis/lib`**, com
  `RUNPATH` no binário, em todos os 4 alvos (uniforme). O processo também
  carrega o `libdrm` do sistema (via mesa); a ABI é compatível para frente, e o
  teste de fumaça confere que o `Xorg` usa a de `/opt/xis`.
* **driver libinput**: o `xf86-input-libinput` do XLibre, tag
  `xlibre-xf86-input-libinput-25.0.1` (mesma versão do pacote do XLibre no
  Devuan), compilado contra o XiS. A **biblioteca** libinput é a do sistema.

Para o **XLibre "normal"** a lista é outra, maior (seção 6).

---

## 6. XLibre "normal" (integrado ao sistema) — a parte grande

O que existe: o `xserver-xlibre-core` oficial tem `Provides: xserver-xorg-core
(= 2:21.98)` e as ABIs `xorg-video-abi-25/28`, `xorg-input-abi-26`;
`Conflicts: xserver-xorg-core`; instala em `/usr/bin/Xorg` e
`/usr/lib/xorg/modules/xlibre-25/`. Os drivers (`xserver-xlibre-input-libinput`
etc.) dependem dele. Fonte do empacotamento: `github.com/xlibre-debian/xlibre-server`,
branch `xlibre/latest`, pasta `debian/` (repositório de NexusSfan). Os binários
vêm de `https://xlibre-debian.github.io/<ubuntu|debian|devuan>/`.

Por que isto não serve nos alvos antigos como está:

* O pacote exige `libc6 >= 2.38`: só instala em **Debian 13** e **Ubuntu 24.04**
  (glibc 2.41 e 2.39). No Ubuntu 22.04 (2.35) e no Debian 12 (2.36), não.
* O `Build-Depends` pede `x11proto-dev (>= 2025.1)`. **Nem o Debian 13**
  (xorgproto 2024.1) tem. Pode ser exigência conservadora (o nosso meson pede
  menos), mas precisa ser verificado; o provável é ter de empacotar um
  `x11proto-dev` novo para os 4 alvos.

O que seria preciso, em ordem:

1. Partir do `debian/` deles (licença: confira o `debian/copyright`) e fazer o
   build em containers dos 4 alvos.
2. Empacotar, no nosso repositório, o que faltar para compilar lá (`x11proto-dev`
   novo; talvez outros).
   **Aviso:** um `x11proto-dev` nosso, com versão maior que o da distro, *substitui* o
   da distro em todo o sistema: é o que um backport faz, mas é invasivo. O pacote
   do XLibre integrado também substitui o Xorg da distro (`Conflicts`).
3. Os drivers: `xf86-input-libinput`, `xf86-video-*` que você usa (você tem
   `xf86-video-amdgpu`, `nouveau`, `vmware` em fork), compilados contra o core
   escolhido.
4. Uma escolha de nome para ter **as duas opções** (core do XLibre ou core do XiS
   integrado): o pacote do XiS integrado poderia se chamar `xserver-xis-core`,
   com `Provides: xserver-xlibre-core (= <versão>)`, `Conflicts` e `Replaces:
   xserver-xlibre-core` — o desenho que discutimos (nome próprio, assim o `apt` nunca
   volta sozinho ao oficial). Isto **não está escrito**.

Estimativa honesta: é o item de maior esforço e risco do repositório. Recomendo
só começar depois de o repositório estar publicando os itens 4.1 e 4.2.

---

## 7. obs-studio (fork)

Estado do fork (`kiyoshispreclerg/obs-studio`): só existe a branch
`upstream-30.1.2` (um instantâneo do upstream 30.1.2 com os commits "Add
libdshowcapture to tree" e "CI: Remove GitHub files"); não vi alterações suas
de funcionalidade no log, o que **deve ser confirmado por você**.

O que as distros têm:

| | Ubuntu 22.04 | Ubuntu 24.04 | Debian 12 | Debian 13 |
|---|---|---|---|---|
| `obs-studio` | 27.2.3 | 30.0.2 (backports: 30.2.3) | 29.0.2 | 30.2.3 |

Pontos a decidir/verificar (nada disto foi testado):

* **Nome e coexistência.** Se o pacote se chamar `obs-studio`, substitui o da
  distro e herda a relação com `obs-plugins`, `libobs0` e plugins de terceiros
  (ABI do `libobs`). Se ficar em `/opt` ou com outro nome, não conflita mas os
  plugins da distro não o enxergam. Sua escolha define o resto.
* **Dependências de build no 22.04 e no 12.** O OBS 30.1 pede versões novas de
  Qt, FFmpeg, CMake etc.; é bem provável que o 22.04 e o 12 não tenham todas, e
  cada uma faltante vira outro pacote nosso (ou `/opt`). Só se descobre fazendo
  um build de teste num container de cada alvo.
* **Tamanho.** É o pacote que mais pesa nos limites do Pages (seção 3).
* **Relação com o kikarinhas**, que captura a janela via OBS: confirmar quais
  versões do OBS ele precisa.

---

## 8. O que passar do repositório `xserver` para cá

Tudo está commitado na branch `experiments` do `xserver`
(`/home/kiyoshi/Downloads/kiyoshi-forks/xserver`). A origem é a pasta
`packaging/` e o workflow `.github/workflows/xis-targets.yml`.

### Copiar

```sh
cd ~/Downloads/kiyoshi-forks/kiyoshi-packages
git init
mkdir -p xis .github/workflows
cp -r ../xserver/packaging/{README.md,versions.sh,scripts,files} xis/
cp ../xserver/.github/workflows/xis-targets.yml .github/workflows/xis-build.yml
```

O que cada arquivo faz (resumo; a explicação completa está em `xis/README.md`):

| Arquivo | Função |
|---|---|
| `versions.sh` | versões fixadas: xorgproto (commit), libdrm 2.4.123, driver libinput 25.0.1 |
| `scripts/install-build-deps.sh` | os 32 pacotes `apt` de build, iguais nos 4 alvos (todos os nomes foram conferidos nos índices oficiais) |
| `scripts/build-xis.sh` | compila xorgproto, libdrm, o servidor e o driver; instala em `PREFIX` e num diretório de *staging* |
| `scripts/smoke-test.sh` | confere o instalado: bibliotecas resolvem, libdrm vem do prefixo, drivers no lugar, Xvfb responde |
| `scripts/make-debs.sh` | gera `xis-server` e `xis-dev` a partir do staging (Depends por `dpkg-shlibdeps`) |
| `scripts/test-install.sh` | numa imagem limpa: instala, roda o teste, instala ao lado do Xorg da distro, faz purge |
| `files/startxis`, `files/xis-dm` | os dois utilitários que vão em `/usr/bin` |
| `xis-build.yml` | matriz dos 4 alvos: build → smoke → `.deb` → teste de instalação |

### Ajustes necessários ao mover

1. **De onde vem o código do servidor.** `build-xis.sh` assume que roda dentro da
   árvore do `xserver` (`repo="$(cd "$here/../.." && pwd)"`). Aqui, acrescentar a
   `versions.sh` algo como `XIS_URL=https://github.com/kiyoshispreclerg/xserver.git`
   e `XIS_REF=<tag ou commit>`, e clonar para `$WORK/src/xis` com o `fetch_git`
   que já existe, no lugar de usar `$repo`.
2. `make-debs.sh` usa `git -C "$repo" rev-parse` para o hash que entra na versão:
   passar a usar o clone do servidor.
3. Caminhos no workflow: `packaging/scripts/...` vira `xis/scripts/...`.
4. **Versão com o alvo**: já está (`<versão>-0xis<rev>~<alvo>`). Uma nota: em
   build de commit (sem `XIS_REVISION`) a versão é `...-0xis0~git<sha>~<alvo>`;
   em release, `XIS_REVISION=1` dá `...-0xis1~<alvo>`.
5. No `xserver`, **fica** o `xis-ci.yml` (lint, ASan/UBSan, XTS: qualidade do
   código). O `xis-targets.yml` pode virar um arquivo curto que chama o
   workflow deste repositório (compilar nas 4 distros a cada push do servidor)
   ou ser removido; quem decide é você.

### Decisões já tomadas que o código incorpora (e por quê)

* **Prefixo `/opt/xis`, dados em `/var/opt/xis`** (log, e `xkb` com 1777 para os
  mapas de teclado compilados): não compartilhamos o cache `xkb` da distro.
* **`--sysconfdir /opt/xis/etc`**, não `/opt/xis/etc/X11`: o servidor já
  acrescenta `X11`.
* **Módulos só em `/opt/xis/lib/xorg/modules`** (caminho gravado no binário, conferido
  com `strings`): o XiS não carrega drivers de `/usr`. **Mas** ele lê
  `/etc/X11/xorg.conf(.d)` como qualquer Xorg; um `Driver`/`ModulePath` ali, feito
  para o Xorg da distro, pode fazê-lo falhar. O `xis-dm` avisa.
* **Config da NVIDIA incluída**: o build já instala `10-nvidia.conf` e
  `10-nvidia-modules.conf` com `ModulePath` apontando também para
  `/usr/lib/x86_64-linux-gnu/nvidia/xorg`. Os dois `.debian` duplicados não
  entram no pacote.
* **Sem `-Dwerror` nos builds de alvo** (o GCC varia entre 11 e 14; um erro de
  build por aviso novo não deve bloquear o pacote). O CI de qualidade, no
  `xserver`, é que usa `-Werror`.
* **`xis-dm` nunca reinicia o gerenciador** (isso encerra a sessão), só escreve
  ou apaga um arquivo próprio. LightDM e SDDM; para GDM/SLiM/LXDM/XDM, imprime a
  linha a editar à mão. **Não foi testado contra um LightDM/SDDM real**, só a
  geração do arquivo.
* Sem pacotes `-dbgsym` por enquanto (binários strippados).

### Lições de CI que valem aqui

* Nas imagens `ubuntu:*` dos containers, o apt aponta para `archive.ubuntu.com`,
  lento e às vezes travando. Os runners ficam na Azure: trocar para
  `azure.archive.ubuntu.com` no primeiro passo (já está no workflow), mais
  `Acquire::Retries` e timeout. Debian (`deb.debian.org`) não precisou.
* Sempre `timeout-minutes` nos jobs: uma instalação travada ficou 71 minutos.
* Xvfb recusa `-screen 0` menor que 1280x1024 (CRTC padrão do upstream).
* `workflow_dispatch` só mostra o botão "Run workflow" se o arquivo estiver na
  **branch padrão** do repositório. Neste repositório novo isso é automático.
* Se um push não dispara nenhum job (zero *check suites*), confira
  `githubstatus.com` antes de procurar erro no YAML.

---

## 9. Estrutura proposta do repositório

```
kiyoshi-packages/
├── README.md                    este documento
├── packages.yml                 lista dos projetos ingeridos (repositório, padrão dos assets)
├── xis/                         empacotamento do XiS (seção 8)
├── xlibre/                      (futuro) empacotamento do XLibre integrado, drivers
├── backports/                   (futuro) dependências que as distros não têm
├── obs-studio/                  (futuro) receita do fork do OBS
├── repo/
│   └── conf/distributions       suites jammy, noble, bookworm, trixie
├── scripts/
│   ├── ingest.sh                baixa .deb dos Releases dos projetos
│   └── publish.sh               monta e assina o repositório (reprepro)
└── .github/workflows/
    ├── xis-build.yml            compila o XiS nos 4 alvos
    ├── ingest.yml               traz os .deb dos outros projetos
    └── publish.yml              reconstrói o repositório e publica no Pages
```

`repo/conf/distributions` (uma entrada por suite; exemplo da primeira):

```
Origin: kiyoshi-packages
Label: kiyoshi-packages
Codename: jammy
Suite: jammy
Architectures: amd64
Components: main
Description: Pacotes do Kiyoshi para Ubuntu 22.04
SignWith: <ID DA CHAVE>
```

Montagem: `reprepro -b repo includedeb jammy pacote.deb`. Publicar **só**
`dists/` e `pool/` (não `conf/`, `db/`).

---

## 10. Plano em fases

| Fase | Entrega | Verificação |
|---|---|---|
| 0 | Repositório criado, chave GPG gerada, `repo/conf`, `publish.yml` publicando um repositório **vazio** no Pages | `apt update` numa máquina vê o repositório e aceita a assinatura |
| 1 | `ingest` + as 4 suites com kikarinhas, kisnitch, kiplay e kidesktop (com o alvo na versão) | `apt install kikarinhas` em um container de cada alvo |
| 2 | `xis-build.yml` movido e verde nos 4 alvos; `xis-server` e `xis-dev` no repositório | `test-install.sh` verde; instalação real de `xis-server` numa máquina |
| 3 | `xis-dm` testado em LightDM e SDDM reais | sessão iniciando com XiS |
| 4 | obs-studio: build de teste nos 4 alvos (descobrir o que falta); decidir nome e coexistência | `.deb` instala e abre |
| 5 | XLibre integrado (seção 6) e drivers | só depois de 1 a 4 |

---

## Decisões em aberto

1. **Opção A (versão com o alvo) ou B (um repositório por alvo)?** (seção 2). Eu
   recomendo A.
2. **Nome e usuário do repositório no GitHub**, para fixar a URL pública (a URL
   entra nas instruções dos usuários e é difícil trocar depois).
3. **A chave GPG**: gerar, guardar a privada como segredo, e fazer o backup. Eu não gero
   nem guardo isto por você.
4. **obs-studio**: o fork tem alterações suas? Substitui o `obs-studio` da distro
   ou convive (nome diferente ou `/opt`)?
5. **XLibre integrado**: vale a pena depois das fases 1–4? (seção 6)
6. **O xserver mantém um `xis-targets.yml` curto**, ou o CI das 4 distros fica só aqui?
7. **arm64**: hoje tudo é `amd64`. Se algum dia entrar `arm64`, a matriz dobra
   (runners `ubuntu-24.04-arm`), e as suites ganham `Architectures: amd64 arm64`.
8. **Licenças e marcas**: o `debian/` do `xlibre-debian` e o OBS têm licenças
   próprias (GPL); o nome "XLibre" aparece nos pacotes de coexistência, e a
   marca "XiS" é nome do seu fork. Confira antes de publicar.
