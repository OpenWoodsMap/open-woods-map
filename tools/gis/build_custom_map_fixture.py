"""Build a Garmin Custom Map KMZ from NRCan's Toporama, for testing the importer.

The custom maps people actually want to load are commercial: Jeff's Algonquin
paddling map is the one that prompted this, sold as a georeferenced bundle that
includes a Garmin Custom Map. Those cannot be committed or handed to CI, so this
renders a stand-in from an openly licensed source in the same format, over the
same ground.

Toporama is the right source for a stand-in because it is a *rendered* topo map
rather than data: contours, lakes, portage-scale detail and place labels already
drawn, which is what a scanned paper map looks like to the importer. It also
serves EPSG:4326 directly, so a GetMap response is already in the plate carree
projection a KML <LatLonBox> assumes. Nothing has to be reprojected here, and
nothing silently approximates a warp.

Licence: Open Government Licence - Canada. Attribution goes in the KML so it
travels with the file rather than living only in this docstring.

Output lands in tools/gis/_tmp_custom_map/, which is gitignored.
"""

import argparse
import math
import shutil
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

import requests

WMS = "https://maps.geogratis.gc.ca/wms/toporama_en"

# Drawing order matters: fills first, then contours, then the line networks, then
# labels on top. Asking for them in one GetMap keeps it to one request per tile.
LAYERS = ",".join(
    [
        "vegetation",
        "water_saturated_soils",
        "hydrography",
        "hypsography",
        "landforms",
        "designated_areas",
        "builtup_areas",
        "constructions",
        "structures",
        "road_network",
        "railway",
        "power_network",
        "feature_names",
    ]
)

ATTRIBUTION = (
    "Toporama, Natural Resources Canada. "
    "Contains information licensed under the Open Government Licence - Canada."
)

# Canoe Lake and Tea Lake, in the west end of Algonquin Park. Chosen because it
# is the stretch of water the real map is bought for, so a misplaced overlay is
# obvious against the app's own hydrography rather than needing a coordinate
# readout to spot.
DEFAULT_AREA = (-78.80, 45.48, -78.543, 45.615)

# Garmin caps a Custom Map tile at one megapixel and warns above 100 tiles per
# device. Staying inside both keeps this a fair test of a real file: a stand-in
# that is easier to draw than the thing it stands in for proves less.
MAX_TILE_PIXELS = 1_000_000


def tile_grid(area, columns, rows):
    """Split [area] into [columns] x [rows] boxes, north row first.

    North first because that is the order Garmin's own exporter writes and the
    order a reader with a tile cap would truncate in, so an importer that quietly
    depends on it gets caught here rather than on a hillside.
    """
    west, south, east, north = area
    tile_lon = (east - west) / columns
    tile_lat = (north - south) / rows
    for row in range(rows):
        for column in range(columns):
            yield (
                row,
                column,
                west + column * tile_lon,
                north - (row + 1) * tile_lat,
                west + (column + 1) * tile_lon,
                north - row * tile_lat,
            )


def pixel_size(west, south, east, north, budget=MAX_TILE_PIXELS):
    """Pick a width and height whose shape matches the ground the tile covers.

    Any size renders correctly, because GetMap and <LatLonBox> agree on the same
    box either way. Matching the ground aspect is about the labels: ask for a
    square image of a box that is taller than it is wide and every place name in
    it comes out stretched, which reads as a bad scan rather than as a bug.
    """
    mid_lat = math.radians((south + north) / 2)
    ground_width = (east - west) * math.cos(mid_lat)
    ground_height = north - south
    aspect = ground_height / ground_width
    width = int(math.sqrt(budget / aspect))
    return width, int(width * aspect)


def fetch_tile(session, west, south, east, north):
    width, height = pixel_size(west, south, east, north)
    # WMS 1.1.1 rather than 1.3.0: 1.3.0 flips EPSG:4326 to latitude-first, and a
    # transposed bbox here would fetch the wrong ground and still return a
    # plausible-looking map.
    response = session.get(
        WMS,
        params={
            "service": "WMS",
            "version": "1.1.1",
            "request": "GetMap",
            "srs": "EPSG:4326",
            "bbox": f"{west},{south},{east},{north}",
            "width": width,
            "height": height,
            "format": "image/jpeg",
            "layers": LAYERS,
            "styles": "",
        },
        timeout=120,
    )
    response.raise_for_status()
    kind = response.headers.get("content-type", "")
    if "image" not in kind:
        raise SystemExit(f"Toporama returned {kind}, not an image:\n{response.text}")
    return response.content


def ground_overlay(name, href, west, south, east, north, draw_order):
    return f"""  <GroundOverlay>
    <name>{escape(name)}</name>
    <drawOrder>{draw_order}</drawOrder>
    <Icon>
      <href>{escape(href)}</href>
    </Icon>
    <LatLonBox>
      <north>{north:.8f}</north>
      <south>{south:.8f}</south>
      <east>{east:.8f}</east>
      <west>{west:.8f}</west>
    </LatLonBox>
  </GroundOverlay>
"""


def build(area, columns, rows, out_dir, name):
    out_dir.mkdir(parents=True, exist_ok=True)
    tiles_dir = out_dir / "tiles"
    if tiles_dir.exists():
        shutil.rmtree(tiles_dir)
    tiles_dir.mkdir()

    session = requests.Session()
    overlays = []
    total_bytes = 0
    for row, column, west, south, east, north in tile_grid(area, columns, rows):
        href = f"tiles/r{row}c{column}.jpg"
        jpeg = fetch_tile(session, west, south, east, north)
        total_bytes += len(jpeg)
        (out_dir / href).write_bytes(jpeg)
        overlays.append(
            ground_overlay(
                f"r{row}c{column}", href, west, south, east, north, 50 + len(overlays)
            )
        )
        print(f"  r{row}c{column}  {len(jpeg) / 1024:>6.0f} KB")

    kml = f"""<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
  <name>{escape(name)}</name>
  <description>{escape(ATTRIBUTION)}</description>
{"".join(overlays)}</Document>
</kml>
"""
    (out_dir / "doc.kml").write_text(kml, encoding="utf-8")

    kmz = out_dir / f"{name.lower().replace(' ', '-')}.kmz"
    with zipfile.ZipFile(kmz, "w", zipfile.ZIP_DEFLATED) as archive:
        # doc.kml first, because a reader is allowed to take the first .kml it
        # finds rather than searching for that name.
        archive.write(out_dir / "doc.kml", "doc.kml")
        for overlay in sorted(tiles_dir.iterdir()):
            archive.write(overlay, f"tiles/{overlay.name}")

    print(
        f"\n{kmz}\n  {len(overlays)} overlays, "
        f"{total_bytes / 1024 / 1024:.1f} MB of JPEG, "
        f"{kmz.stat().st_size / 1024 / 1024:.1f} MB zipped"
    )
    return kmz


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=3)
    parser.add_argument("--name", default="Algonquin Canoe Lake")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).parent / "_tmp_custom_map",
    )
    parser.add_argument(
        "--area",
        type=float,
        nargs=4,
        metavar=("WEST", "SOUTH", "EAST", "NORTH"),
        default=DEFAULT_AREA,
    )
    args = parser.parse_args()

    west, south, east, north = args.area
    print(f"Toporama {west},{south} to {east},{north}")
    build((west, south, east, north), args.columns, args.rows, args.out, args.name)


if __name__ == "__main__":
    main()
