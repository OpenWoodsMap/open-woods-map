<h1 align="center">🌲 OpenWoodsMap</h1>

<p align="center">
  <b>Whose land am I standing on, and what are the rules here?</b><br>
  A free, offline map for Canadians heading outdoors. No signal, no account, no catch.
</p>

<p align="center">
  <a href="https://github.com/OpenWoodsMap/open-woods-map/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/OpenWoodsMap/open-woods-map?label=download&color=2e7d32"></a>
  <img alt="Platform: Android" src="https://img.shields.io/badge/platform-Android-3ddc84">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

---

OpenWoodsMap shows Crown land, parks, closures, wildlife management units and
municipalities on a map that keeps working with no signal. Tap anywhere and it
tells you whose land it is, what designation and policy apply, and which hunting
seasons are open.

Anyone heading out needs the same two things: a map that works with no signal,
and a straight answer about whose land they are standing on. That part serves
hikers, anglers and hunters alike. On top of it, the deepest work so far is
hunting legality, because that is where a wrong answer costs the most.
For anglers there is one so far: Ontario's published boat launches and shore
access sites. Fishing regulations and anything hiking-specific are not built
yet, and this README will say so until they are.

> ⚠️ **A planning aid, not the law.** Boundaries come from provincial records and
> are not a legal survey. Check the regulations, posted signs and local bylaws
> before you hunt or camp.

## 📥 Get it

1. Download the APK from the [latest release](https://github.com/OpenWoodsMap/open-woods-map/releases/latest)
   and install it on your Android phone.
2. On first launch, pick a province and the app downloads its data pack.
3. For updates, point [Obtainium](https://github.com/ImranR98/Obtainium) at
   this repository.

Android only. There is no iPhone build, and that is deliberate: every free way
to install an app on an iPhone expires after seven days and needs a connection
to renew, which is no good for a map meant to work in the bush.
[docs/ios.md](docs/ios.md) explains, and what would change it. On a Windows PC
or an Apple Silicon Mac, the Android build runs in an emulator such as
[BlueStacks](https://www.bluestacks.com/) for planning at the kitchen table.

## 🤝 Other free tools worth using

OpenWoodsMap is not the only project trying to make this information free and
easy to find, and it should not be the only map you check. These share the same
goal and do some things better. Use them side by side: where two maps disagree,
the province's own data and the signs on the ground win.

### 🏮 [Lantern](https://www.lanternsearch.ca/)

A free, donation-supported web map of Ontario Crown land, drawn from the
province's Crown Land Use Policy Atlas. Excellent on a computer for browsing
designations such as general use areas, conservation reserves and parks.

- 📦 Offers its Ontario Crown land layer as a **free GeoJSON or Shapefile
  download** for QGIS, ArcGIS or any other mapping app
- 📌 Save locations without an account
- 🗺️ Ontario only

### 🌲 [Jackpine Outdoors](https://jackpineoutdoors.ca/)

A hunting and camping map for the web and Android, covering every province and
territory, with Ontario, Saskatchewan, New Brunswick and Nova Scotia fully
checked and the rest in beta.

- 🦌 Crown land and WMU seasons, "can I hunt or camp here?" with leases and
  mining claims
- 🪓 Cutovers by age, planned cuts, fire history and forest type: great for
  finding regrowth and browse
- 🎯 Habitat "hotzones", trip planning, wind plans and campsite suggestions
- 📴 Works offline, and the Android app records tracks with the screen off
- 💳 The Crown land and season map is free to use. A free account adds one
  offline area and 100 saved spots and routes; the paid Pro tier lifts those
  limits and adds sync

*Know of another free tool that belongs here? Open an issue and it will be
added.*

## 🧭 What OpenWoodsMap stands for

- 📴 **Offline first.** Identify, layers, Land Info and seasons all work with no
  signal. Weather is the one exception, and it says so.
- 🔒 **Your data is yours.** Waypoints, tracks and saved maps live on your
  phone and nowhere else. No account, no cloud, no database somewhere holding
  your spots. Export everything at any time in open formats: GPX, KML, GeoJSON.
  Like any online map, the basemap fetches tiles for the ground you look at.
  Beyond that, the only coordinate the app sends anywhere is to
  [Open-Meteo](https://open-meteo.com/) when you ask for weather or wind.
- 💸 **Free forever.** No ads, no subscription, no paywalled limits on waypoints,
  tracks or offline areas. The only limit is your phone's storage.
- 🧾 **Honest answers.** The app never invents data, and never sounds more
  certain than its sources. "The rule says no" and "we have no record" are
  different answers, and it says which one you are getting.
- 🛠️ **Open source.** MIT licensed. Copy it, fork it, take the ideas into
  your own app. That is the point.
- 🏗️ **Nothing to keep running.** No servers and no paid APIs. Map data comes
  from open government sources and ships as downloadable packs on GitHub
  Releases, which is why it can stay free.

## ✨ Features

**🗺️ Land and rules**
- Tap anywhere for **Land Info**: local government for bylaws, Crown land
  tenure, designation, land use policy and the WMU
- **Closures first:** Crown game preserves, national wildlife areas, bird
  sanctuaries and defence property are flagged above the tenure underneath
- **Permission needed:** First Nations reserves and conservation authority land
  are reported as "ask first", not as open or closed
- **Provincial parks:** hunting permissions read from the regulation, with the
  parks that open only part of their ground saying so
- **Sunday gun hunting:** whether it is permitted at the point you tapped
- **Seasons:** every species with a published WMU table, open now, upcoming or
  closed, filtered by residency
- 🎣 **Fishing access (Ontario):** about 2,400 boat launches, docks and shore
  access sites, with parking, fees and ramp surface where the province recorded
  them

**📴 Maps and offline**
- Offline, streets, satellite and hybrid basemaps, with Ontario and Quebec
  aerial photography
- **Save offline areas** at the detail you choose, with the size shown first
- 🖼️ **My maps:** bring your own imagery, a Garmin Custom Map KMZ or an XYZ
  tile URL, drawn over the basemap and under the land layers
- Province data packs that refresh without an app update

**📍 Waypoints and tracks**
- Mark where you stand, record GPS tracks, follow a track back
- Import and export GPX, KML and GeoJSON
- Search, tag, hide, bulk edit, and match icons to names after an import
- Optional names on the map
- **Backup and restore**, with rolling on-phone snapshots

**🧰 Tools**
- 📏 Measure a distance
- 🌅 Legal light for any date, worked out offline
- 💨 Wind where you are, and a 7-day weather outlook
- 📤 Share your location or a spot as text with a map link
- 🧭 Coordinates in decimal, degrees and minutes, DMS or UTM

The long version, with what each feature does and where it stops, is in
[docs/features.md](docs/features.md).

## 📍 Coverage

| Province | Status |
|----------|--------|
| 🟢 Ontario | Real and reasonably complete: tenure, closures, parks, seasons and policies |
| 🟡 Quebec | Preview: real zones and boundaries, no seasons or policies yet |
| ⚪ Everywhere else | Not yet |

## 🛠️ Build from source

```powershell
$env:PATH = "C:\_stuff\dev\tools\flutter\bin;$env:PATH"
cd C:\_stuff\dev\open-woods-map
powershell -File scripts\sync_assets.ps1
cd app
flutter pub get
flutter run   # Android device or emulator
```

Build a sideload APK: [docs/android_apk.md](docs/android_apk.md). Built with
Flutter and MapLibre.

## 📚 Docs

- [Features in detail](docs/features.md)
- [Architecture](docs/architecture.md)
- [Datasets](docs/datasets.md)
- [Constraints](docs/constraints.md)
- [AI guidelines](docs/ai_guidelines.md)
- [Contributing](docs/contributing.md)
- [Android APK](docs/android_apk.md)
- [iOS](docs/ios.md)
- [Offline packs](docs/packs.md)
- [Backup](docs/backup.md)
- [GIS pipeline](tools/gis/README.md)

## 📄 License

MIT — see [LICENSE](LICENSE).
