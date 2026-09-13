# Constraints (hard rules)

Violating these is out of scope for OpenWoodsMap.

1. **No servers** — no API backend, no self-hosted sync, no Firebase/Supabase/etc. The loopback socket in `style_server_io.dart` is not an exception: it is bound to `127.0.0.1`, exists only while a basemap area is downloading, and serves a style the app already ships. Nothing is hosted and nothing leaves the device.
2. **No paid map APIs** — no Mapbox, Google Maps Platform, or other metered tile/geocode services.
3. **No cloud sync or login** — no accounts, OAuth, or cross-device waypoint sync.
4. **Offline-first** — map, layers, and Land Info must work without network after assets are present. Live conditions are the one sanctioned exception: the Weather tab calls Open-Meteo, is additive rather than load-bearing, and must fail with a plain message instead of degrading the rest of the card.
5. **GIS bundled or static** — GeoJSON/PMTiles in the app or GitHub Releases; no paid tile CDN.
6. **MapLibre only** — no alternate map SDKs for the primary map.
7. **No AI frameworks in the app** — no on-device LLM, no agent orchestration, no cloud inference for core features.
8. **Shipped target = Android only** — including Android emulators on a desktop (e.g. BlueStacks). No shipped web app; no native Windows/macOS/Linux desktop app. iOS is a supported *code* target and must stay buildable in principle, but nothing is published: every free way to install an app on an iPhone expires after seven days and needs network to renew, which fails the offline-first rule at the worst possible moment. See [ios.md](ios.md) for the full reasoning and what would change it.

Large data = GitHub Releases. Waypoints = local storage only.
