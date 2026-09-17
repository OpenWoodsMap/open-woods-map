# Contributing

## Setup

1. Clone the repo.
2. Install [Flutter 3.29+](https://docs.flutter.dev/get-started/install).
3. Sync GIS assets: `powershell -File scripts\sync_assets.ps1` (from repo root).
4. `cd app && flutter pub get`
5. `flutter run` on an **Android** device/emulator.

Shipped target: **Android** only (Android emulators such as BlueStacks count). Web and native desktop are out of scope. iOS is a code target that must stay buildable in principle — new packages need iOS support and platform code stays behind conditional imports — but nothing is published; see [ios.md](ios.md).

## Province packs

Add or extend `data/{cc}/`:

- `manifest.json` — layer ids and paths under `overlays/`
- `overlays/` — GeoJSON (or PMTiles) per layer
- `policies/` — optional static policy text/PDFs
- `seasons/` — optional curated season JSON (Ontario)
- Register province in `data/provinces.json` (`enabled`, `bbox`, `name`, optional `packUrl`)

Follow attribute expectations in [datasets.md](datasets.md) for Land Info. Build release ZIPs with `tools/gis/build_pack.py`.

### Automated geometry packs

- Workflow: `.github/workflows/rebuild-geometry-packs.yml` (monthly + manual).
- Entry script: `tools/gis/rebuild_geometry.py --pack`
- Download URL tag: `packs-latest` (see `packUrl` in `data/provinces.json`).
- Policies **are** rebuilt by a geometry run, from the CLUPAPRO download.
- Seasons are **not** rebuilt here. They come from `data/{cc}/seasons/*.json` as
  committed, so a pack published by this workflow carries whatever is in the repo
  at the time. `.github/workflows/refresh-seasons.yml` re-scrapes them on its own
  schedule and opens a PR rather than pushing, because hunters act on these dates
  and a human checks the diff against the official tables first. Merge that, then
  re-pack. Or drive both by hand with `.agents/skills/refresh-seasons-policies`.
- Neither schedule had ever actually run until they were dispatched by hand, and
  both turned out to be broken. [datasets.md](datasets.md) records how, and why a
  schedule nobody has fired is an untested code path.

## Data in git

- Keep clones light: prefer sample/regional fixtures in git when possible.
- Full province packs → **GitHub Releases**; link via `packUrl`.

## PR hygiene

- One logical change per PR (layer, UI, or docs).
- UI changes: check them on a device. [devtest.md](devtest.md) has an emulator
  harness if you want one, but `flutter run` is enough.
- Note data sources and licenses in the PR description.
- Do not commit secrets, API keys, or proprietary datasets.
- `flutter analyze` (and tests) before opening a PR.

## Constraints

All contributions must satisfy [constraints.md](constraints.md).
