# xlibre/packaging

The Debian packaging (`debian/`) of the XLibre packages, copied from
`github.com/xlibre-debian/*` (NexusSfan; MIT, see the `debian/copyright` in each
folder). The builds read only this copy. `SOURCES` records the commit each one
was taken from.

- `xlibre-server`: for the beta channel and for `xserver-xis-core`
- `xlibre-server-stable`: the packaging of 25.1.7, for the stable channel
- `xlibre`: the metapackage, copied whole (it has no upstream tree)
- the others: one per driver, plus `xorgproto`

Update with `xlibre/scripts/vendor-packaging.sh [name...]`, then review
`git diff` and commit.
