"""Measure average tile weights for the offline basemap size estimator.

The estimator in `app/lib/offline/tile_math.dart` multiplies a tile count by a
per-source average. Those averages have to come from the real endpoints rather
than from a guess, so this script samples tiles across settled and bush areas of
Ontario and Quebec and prints the medians to paste back into the Dart constants.

Run it again if a source changes; it is not part of the build.
"""

from __future__ import annotations

import math
import statistics
import sys

import requests

# Spread across the kind of country this app is actually used in: a city, a
# town, farmland, near-north bush and far-north bush. Averaging over only
# Toronto would overstate every pack a hunter downloads.
# Each carries the province it is actually in. A longitude test cannot tell them
# apart: Ottawa, Bancroft and Algonquin all sit east of Quebec's western edge
# and north of its southern one, so a bounding-box guess files them under
# Quebec and samples the wrong provincial server for them.
SAMPLES = [
    ("Toronto", -79.38, 43.65, "on"),
    ("Ottawa", -75.70, 45.42, "on"),
    ("Peterborough", -78.32, 44.31, "on"),
    ("Bancroft bush", -77.85, 45.06, "on"),
    ("Algonquin", -78.38, 45.58, "on"),
    ("Sudbury", -80.99, 46.49, "on"),
    ("Hearst bush", -83.67, 49.69, "on"),
    ("Red Lake bush", -93.79, 51.03, "on"),
    ("Gatineau", -75.77, 45.55, "qc"),
    ("Saguenay", -71.07, 48.43, "qc"),
    ("Mauricie bush", -73.20, 46.95, "qc"),
    ("Abitibi bush", -78.50, 48.50, "qc"),
    ("Cote-Nord bush", -68.50, 50.10, "qc"),
]

SOURCES = {
    "openfreemap_vector": {
        "template": None,  # resolved from the TileJSON below
        "tilejson": "https://tiles.openfreemap.org/planet",
        "zooms": [8, 10, 12, 14],
    },
    "sentinel2": {
        "template": "https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2024_3857"
        "/default/g/{z}/{y}/{x}.jpg",
        "zooms": [8, 10, 12, 14],
    },
    "on_ortho": {
        "template": "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services"
        "/LIO_Imagery/Ontario_Imagery_Web_Map_Service/MapServer/tile/{z}/{y}/{x}",
        "zooms": [10, 12, 14, 16],
    },
    "qc_ortho": {
        "template": "https://servicesmatriciels.mern.gouv.qc.ca/erdas-iws/ogc"
        "/wmts/Inventaire_Ecoforestier/Inventaire_Ecoforestier/default"
        "/GoogleMapsCompatibleExt2:epsg:3857/{z}/{y}/{x}.jpg",
        "zooms": [10, 12, 14, 16],
    },
}

# Sampling a provincial service outside its province would not fail loudly for
# Quebec, which is the trap: it answers everywhere with HTTP 200, serving a flat
# 2 KB placeholder outside its footprint. Those pass every check below and drag
# the median to a fraction of the truth, so the estimator would promise a
# download it cannot deliver. Ontario's own service 404s there and self-corrects.


def tile_xy(lon: float, lat: float, zoom: int) -> tuple[int, int]:
    n = 2**zoom
    x = int((lon + 180.0) / 360.0 * n)
    lat_rad = math.radians(lat)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y


PROVINCE_ONLY = {"on_ortho": "on", "qc_ortho": "qc"}


def sample(name: str, spec: dict) -> None:
    template = spec["template"]
    if template is None:
        meta = requests.get(spec["tilejson"], timeout=30).json()
        template = meta["tiles"][0]
        print(f"  (resolved {name} -> {template})", file=sys.stderr)

    sizes: list[int] = []
    for place, lon, lat, province in SAMPLES:
        if PROVINCE_ONLY.get(name) not in (None, province):
            continue
        for zoom in spec["zooms"]:
            x, y = tile_xy(lon, lat, zoom)
            url = template.format(z=zoom, x=x, y=y)
            try:
                response = requests.get(url, timeout=60)
            except requests.RequestException as error:
                print(f"    {place} z{zoom}: {error}", file=sys.stderr)
                continue
            if response.status_code != 200:
                print(
                    f"    {place} z{zoom}: HTTP {response.status_code}",
                    file=sys.stderr,
                )
                continue
            sizes.append(len(response.content))

    if not sizes:
        print(f"{name}: no samples")
        return
    print(
        f"{name}: n={len(sizes)} "
        f"median={statistics.median(sizes) / 1024:.1f} KiB "
        f"mean={statistics.fmean(sizes) / 1024:.1f} KiB "
        f"min={min(sizes) / 1024:.1f} max={max(sizes) / 1024:.1f}"
    )


def main() -> None:
    for name, spec in SOURCES.items():
        print(f"sampling {name}...", file=sys.stderr)
        sample(name, spec)


if __name__ == "__main__":
    main()
