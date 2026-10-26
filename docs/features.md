# Features in detail

The [README](../README.md) has the short tour. This page is the long one: what
each feature does, and where it stops.

## Land answers

- Province switcher (Ontario, plus Quebec flagged **preview** — real zones and
  boundaries, but no seasons or policies yet)
- Overlay toggles (crown land, municipal & county forests, conservation
  authority land, reserves, parks, Crown game preserves, federal wildlife areas
  and bird sanctuaries, defence property, WMU, Sunday gun hunting,
  municipalities). A toggle only changes what the map draws: Land Info answers
  from every installed layer whether it is switched on or not
- **Closures outrank tenure:** Crown game preserves, National Wildlife Areas,
  Migratory Bird Sanctuaries and National Defence property are drawn over Crown
  land and reported first, since hunting there is prohibited whatever the tenure
  underneath says. In a bird sanctuary possessing *any* firearm is itself an
  offence, which is the part a deer hunter walking through would not expect
- **Permission-required land is neither open nor closed:** 409 conservation
  authority properties name the authority to ask, and 203 reserves are reported
  as needing the First Nation's permission — an Ontario licence conveys no right
  of access to reserve land, which is a different answer from "prohibited" and
  is worded like one. Where the conservation authority source draws nothing the
  card says that its silence is not permission
- **Defence property, with the caveat:** 140 National Defence properties
  totalling 51,309 ha, including Petawawa, Borden and Meaford. Closed to public
  hunting, but some bases run their own controlled hunts, so the card links the
  property's federal record rather than naming programmes a pack cannot keep
  current
- **The Far North says why it is empty:** above the Far North line the policy
  atlas thins out to nothing, so a parcel with no policy report is reported as
  ground the atlas never reached rather than ground no policy applies to. Where
  one of the four community based land use plans covers the point, the card
  names it and links the document while making clear it is not a hunting
  regulation
- **Park permissions from the regulation, not guesswork:** hunting in an Ontario
  provincial park is prohibited unless O. Reg. 663/98 Part 3 opens it. Parks the
  regulation opens in whole read as permitted; the 35 it opens only a surveyed
  part of say so plainly, because the province describes that part in words and
  never mapped it. Carve-outs are quoted verbatim
- **Sunday gun hunting:** permitted north of the French and Mattawa rivers, and
  south of them only in the 193 jurisdictions the regulation schedules. The card
  says which case applies at the tapped point
- **Land Info:** tap anywhere for a small card naming the ground and flagging any
  closure or condition on it, then *Land info* for the full three-tab report —
  *Land* (local government for bylaws, land tenure, designation, policy),
  *Seasons* and *Weather*. Land-use policies read offline from the pack, with a
  link to the official live report. The small card never says hunting is
  permitted: a yes is only honest beside the regulation it comes from
- **Seasons:** every species with a published WMU season table, split into
  open now / upcoming / closed, filterable by game group and residency
- **Fishing access (Ontario):** the 2,427 boat launches, docks and shore access
  sites the province publishes for the public, drawn as dots. Tapping one adds
  it to the card, with parking, fees, ramp surface, accessibility and who owns
  it wherever the province recorded them, and when someone last confirmed it on
  a visit. Most sites leave most of that unrecorded, and the card says so
  rather than implying no. A site says where the water starts, not whether you
  may fish it: seasons, sanctuaries and limits are in the Ontario Fishing
  Regulations Summary, which the app does not yet carry

## Map tools

- On-screen zoom buttons alongside pinch-zoom
- **Measure a distance:** tap along the map for a running total, the straight
  line end to end, and the heading of the last leg. Map distance, so it ignores
  the ground going up and down — a phone's elevation readings are not good
  enough to claim otherwise
- **Wind where you are:** one line in the corner saying which way the wind is
  coming from, how hard, and which way it is therefore blowing, with an arrow
  that turns with the map. It says it is a forecast ten metres up rather than a
  measurement in the trees, and how old the reading is. Needs a connection
- **Share my location:** sends a fresh GPS fix, its accuracy and its age as
  plain text with a map link, through whatever app you pick. It never falls
  back to the map centre, and a spot you tapped is shared worded as a spot on
  the map rather than where you are
- **Names on the map:** an optional switch in the map's ⋮ menu that writes
  waypoint and track names beside them, from town scale in. Uses the basemap's
  own font, so it keeps working offline
- **Weather:** current conditions and wind direction for the tapped point, legal
  light times, best sits for the day, and a 7-day outlook. Includes an optional
  deer activity graph — an openly documented heuristic, not a prediction, with
  the reasons behind every hour shown and moon phase deliberately left out. The
  only feature that needs a connection
- Opens on your own position, once per launch. If location is off or refused it
  falls back to the province without complaining, and switching basemaps keeps
  the view exactly where you left it

## Waypoints and tracks

- Waypoints + GPS track recording; GPX / KML / GeoJSON import-export. One button
  marks where you are standing, from a fresh fix rather than wherever the map
  happens to be pointing, and says so in the note when the fix was a rough one
- **Overlapping marks:** a tap on several waypoints or tracks at once opens the
  nearest and lists the rest under *Also here*
- **Hide from the map** without deleting: per item, per tag, or everything the
  list is showing, with a *Hidden from map* filter to find them again
- **Bulk edit:** set an icon, a colour or an added tag on everything the search
  and tag filter are showing, with undo
- **Match icons to names:** proposes icons for plain pins from words in their
  names ("North stand", "Trail cam 3", "Truck"), in English and Quebec French.
  Place names such as "Bear Creek" and names that match two icons start
  unticked with the reason beside them, and nothing changes until you apply
- **Backup & restore:** the app keeps rolling copies of your list on the phone
  so a bulk delete or a bad import is recoverable long after the undo has gone,
  and makes a complete backup file you can put wherever you like. The file is
  plain GeoJSON any other tool reads, with tag styling in a member they ignore.
  It will tell you when you last made one; it will not pretend to know you kept
  it. See [backup.md](backup.md)

## Basemaps and offline

- Basemaps: offline / streets / satellite / hybrid. Satellite is Ontario aerial
  photography to z19 and Quebec's ecoforest-inventory aerial mosaic to z18 west
  of the Gaspé, with global Sentinel-2 elsewhere; hybrid stacks OpenFreeMap's
  roads, watercourses, boundaries and place names on top of it
- **Basemap areas:** save the ground you actually use for offline use, at a
  detail level you choose, with the size estimated before you commit and the
  overlap with anything already saved deducted from it
- **Province packs:** download from GitHub Releases or import a ZIP on device
- **My maps:** bring your own imagery, either a Garmin Custom Map KMZ from the
  phone or an XYZ tile URL, drawn over the basemap and under the land layers

### Province packs

Nothing province-specific is baked into the binary. Overlays, policies and
seasons all live in a downloadable pack, so data can be refreshed without a
store release and the app installs small.

### Basemap areas

Province packs make the *data* work offline. The basemap underneath it still
streams, so Streets, Satellite and Hybrid go blank without a signal. Saving an
area fixes that for the ground that matters to you.

Pick the area by framing it on the map, choose Overview, Standard or Detailed,
and the estimate updates as you pan. Tiles are shared between areas and between
basemaps, so re-saving somewhere you already have costs only the difference, and
the estimate says so. Storage is listed per basemap, alongside the true total on
disk — which is smaller than the sum of the parts wherever areas overlap.

Roughly what to expect for a phone-sized viewport of about 27 × 28 km:

| Detail | Good for | Satellite | Hybrid | Streets |
|--------|----------|-----------|--------|---------|
| Overview (z12) | Lakes, highways, towns | ~2 MB | ~4 MB | ~2 MB |
| Standard (z14) | Side roads and bush roads | ~20 MB | ~42 MB | ~22 MB |
| Detailed (z16) | Individual trees and trails | ~200 MB | ~220 MB | n/a |

Streets stops at Standard because OpenFreeMap's vector tiles stop at zoom 14;
the map still zooms in past that, it just stops gaining detail.

| Ontario layer | Approx. features |
|---------------|------------------|
| Crown land parcels (MNR unpatented + CLUPA) | ~42,700 |
| Municipalities | ~685 |
| Geographic townships | ~2,500 |
| Provincial parks | ~340 |
| WMUs | ~150 |
| Hunting seasons | 21 species across 150 WMUs |

### My maps

Paper and PDF maps of a park or a management unit are often better than any
basemap for the ground they cover, and the people who draw them usually publish
a Garmin Custom Map KMZ — a zip of JPEG tiles with corner coordinates, which is
close enough to what MapLibre draws that the phone needs no conversion step.
Import one and it works with no signal. An XYZ tile URL works too, and does not.

Both draw above the basemap and below every land layer, because imagery is
something to read the ground by and tenure is the answer this app exists to
give. Where two of your own maps cover the same ground, the one higher in the
list wins.

What is deliberately not supported: WMS addresses, GeoTIFF and MBTiles files.
The first asks for a picture of a bounding box rather than numbered tiles, and
the other two would mean reprojecting and re-tiling gigabytes on a phone. All
three are refused by name rather than failing quietly.
