#!/usr/bin/env python3
"""Fetch Quebec municipalities from the provincial Découpages administratifs.

Downloads the MRNF 1:20 000 SDA shapefile archive, reads the municipal
territories (munic_s), and writes them as WGS84 GeoJSON.
Requires: pip install pyshp shapely
"""

from __future__ import annotations

import argparse
import json
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from shapely.geometry import mapping, shape
from shapely.validation import make_valid

try:
    import shapefile  # pyshp
except ImportError as exc:  # pragma: no cover
    raise SystemExit("pip install pyshp") from exc

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data/qc/overlays/municipalities.geojson"
# Statistics Canada's census subdivisions were the source until www12.statcan
# began refusing every scripted request. This is the province's own layer,
# which the census subdivisions are themselves drawn from.
ZIP_URL = (
    "https://diffusion.mern.gouv.qc.ca/diffusion/RGQ/Vectoriel/Theme/Local/"
    "SDA_20k/SHP/SDA.shp.zip"
)
DATASET_URL = "https://www.donneesquebec.ca/recherche/dataset/decoupages-administratifs"
LAYER = "munic_s"
# Geographic NAD83. Left untransformed: it sits within about a metre of WGS84
# here, well under the simplification applied below.
SRC_CRS = "EPSG:4269"
# A complete archive holds about 1,340 territories. Far fewer means a cut-off
# download or a changed archive, and either would leave towns without bylaws.
MIN_FEATURES = 1200


def download_zip(dest: Path) -> Path:
    if dest.exists() and dest.stat().st_size > 50_000_000:
        print(f"Using cached {dest}", flush=True)
        return dest
    print(f"Downloading {ZIP_URL} …", flush=True)
    req = urllib.request.Request(ZIP_URL, headers={"User-Agent": "OpenWoodsMap/0.1"})
    with urllib.request.urlopen(req, timeout=600) as response:
        dest.write_bytes(response.read())
    print(f"Saved {dest} ({dest.stat().st_size/1e6:.1f} MB)", flush=True)
    return dest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument(
        "--zip",
        type=Path,
        default=Path(__file__).resolve().parent / "_tmp_sda" / "SDA.shp.zip",
    )
    parser.add_argument("--simplify", type=float, default=0.002)
    args = parser.parse_args()

    args.zip.parent.mkdir(parents=True, exist_ok=True)
    download_zip(args.zip)

    out = []
    version = ""
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(args.zip) as archive:
            members = [n for n in archive.namelist() if Path(n).stem == LAYER]
            if not any(n.endswith(".shp") for n in members):
                raise SystemExit(f"{args.zip.name} has no {LAYER}.shp")
            archive.extractall(tmp, members)
        print(f"Reading {LAYER}.shp ...", flush=True)
        reader = shapefile.Reader(str(Path(tmp) / LAYER), encoding="utf-8")
        try:
            for sr in reader.iterShapeRecords():
                attrs = sr.record.as_dict()
                name = str(attrs.get("MUS_NM_MUN") or "").strip()
                code = str(attrs.get("MUS_CO_GEO") or "").strip()
                version = version or str(attrs.get("MUS_CO_VER") or "").strip()
                if not name or not code:
                    raise SystemExit(f"Territory without a name or code: {attrs}")
                g = shape(sr.shape.__geo_interface__)
                if not g.is_valid:
                    g = make_valid(g)
                if args.simplify > 0:
                    g = g.simplify(args.simplify, preserve_topology=True)
                if g.is_empty or g.geom_type == "GeometryCollection":
                    print(f"skip {name}: no usable geometry", flush=True)
                    continue
                out.append(
                    {
                        "type": "Feature",
                        "properties": {
                            "id": f"qc-mun-{code}",
                            "name": name,
                            "type": str(attrs.get("MUS_CO_DES") or "").strip(),
                            "designation": str(attrs.get("MUS_DE_IND") or "").strip(),
                            "province": "QC",
                        },
                        "geometry": mapping(g),
                    }
                )
        finally:
            reader.close()

    if len(out) < MIN_FEATURES:
        raise SystemExit(f"Only {len(out)} territories, expected at least {MIN_FEATURES}")

    payload = {
        "type": "FeatureCollection",
        "metadata": {
            "crs": "EPSG:4326",
            "layer": "municipalities",
            "feature_count": len(out),
            "coverage": (
                "Quebec municipalities, unorganized territories and reserves "
                f"(Découpages administratifs 1:20 000, {version or 'version unknown'})"
            ),
            "source": DATASET_URL,
            "source_file": ZIP_URL,
            "attribution": "Ministère des Ressources naturelles et des Forêts du Québec",
            "license": "CC-BY 4.0",
            "license_url": "https://creativecommons.org/licenses/by/4.0/",
            "source_crs": SRC_CRS,
            "simplify_degrees": args.simplify,
        },
        "features": out,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(payload, separators=(",", ":"), ensure_ascii=False), encoding="utf-8"
    )
    print(f"Wrote {len(out)} -> {args.out} ({args.out.stat().st_size/1e6:.2f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
