#!/usr/bin/env python3
"""Build ON fishing_access from Ontario's Fishing Access Point inventory.

The first layer that is not about land at all: a point where the province has
recorded a way onto the water — a boat launch, a dock or pier, or a stretch of
shore you can fish from. It answers "where do I put in?", which no tenure layer
can, and it is the first thing in the app built for anglers rather than hunters.

Two rules decide what reaches the pack:

  * Only sites the province marks VISIBILITY_IND = Yes. The LIO data description
    defines the flag as whether the site "should be made visible through mapping
    applications or data distribution". 1,304 of 3,731 sites are marked No; the
    service still returns them, but that is the custodian's request and we keep
    to it rather than to what the endpoint happens to allow.

  * "Unknown" is dropped, never translated. Most sites leave parking, fees and
    surface as Unknown, and a card that printed "Parking: Unknown" forty times a
    lake would bury the few sites someone actually checked. Absent means the
    province did not say, and the card words it that way.

A site's ownership is reported as recorded. 222 sites are privately owned (a
marina, a lodge) and that is worth knowing before you drive there; it is not a
statement that you may or may not use them.
"""

from __future__ import annotations

import datetime as dt
import json
import re
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data/on/overlays/fishing_access.geojson"

SERVICE = (
    "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/"
    "LIO_OPEN_DATA/LIO_Open07/MapServer/15"
)
SOURCE = "Ontario Fishing Access Point (Land Information Ontario)"
SOURCE_URL = "https://geohub.lio.gov.on.ca/datasets/lio::fishing-access-point"
DATA_DESCRIPTION_URL = (
    "https://www.publicdocs.mnr.gov.on.ca/mirb/"
    "Fishing%20Access%20Point%20-%20Data%20Description.pdf"
)
LICENSE = "Open Government Licence – Ontario"
LICENSE_URL = "https://www.ontario.ca/page/open-government-licence-ontario"

PAGE = 2000

KINDS = {
    "Boat Launch": "boat_launch",
    "Enhanced Shoreline Access": "enhanced_shoreline",
    "Shoreline Access": "shoreline",
}

KIND_LABELS = {
    "boat_launch": "Boat launch",
    "enhanced_shoreline": "Dock or pier",
    "shoreline": "Shore access",
}

FLAGS = {"Yes": True, "No": False}

OWNERS = {
    "Federal": "federal",
    "Provincial": "provincial",
    "Municipal": "municipal",
    "Private": "private",
}

SURFACES = {
    "Concrete": "concrete",
    "Gravel": "gravel",
    "Natural": "natural",
    "Other": "other",
}

# 3,202 of the comments are the record's own cross-reference into another
# provincial table ("RECREATION_POINT.OGF_ID = 151345828"). Meaningless to anyone
# standing at the launch, so they are not carried.
_INTERNAL_COMMENT = re.compile(r"^\s*[A-Z_]+\.[A-Z_]+\s*=\s*\d+\s*$")


def fetch() -> list[dict]:
    features: list[dict] = []
    offset = 0
    while True:
        query = urllib.parse.urlencode(
            {
                "where": "VISIBILITY_IND = 'Yes'",
                "outFields": (
                    "OGF_ID,FISHING_ACCESS_POINT_TYPE,SITE_NAME,"
                    "PARKING_PRESENCE_FLG,USER_FEE_FLG,ACCESSIBILITY_FLG,"
                    "SITE_OWNERSHIP_TYPE,MATERIAL_TYPE,"
                    "SITE_LAST_VERIFICATION_DATE,GENERAL_COMMENTS,"
                    "ADDITIONAL_INFORMATION_URL,VISIBILITY_IND"
                ),
                "outSR": "4326",
                "orderByFields": "OGF_ID",
                "resultOffset": offset,
                "resultRecordCount": PAGE,
                "returnGeometry": "true",
                "f": "geojson",
            }
        )
        request = urllib.request.Request(
            f"{SERVICE}/query?{query}", headers={"User-Agent": "OpenWoodsMap/0.1"}
        )
        with urllib.request.urlopen(request, timeout=300) as response:
            page = json.load(response).get("features") or []
        features.extend(page)
        print(f"  fetched {len(features)} …", flush=True)
        if len(page) < PAGE:
            return features
        offset += PAGE


def _text(value) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _date(millis) -> str | None:
    if not isinstance(millis, (int, float)):
        return None
    day = dt.datetime.fromtimestamp(millis / 1000, tz=dt.timezone.utc).date()
    # One record is stamped 1970-01-01, which is a zero in a date column rather
    # than a visit anybody made.
    return None if day.year < 1980 else day.isoformat()


def _url(value) -> str | None:
    text = _text(value)
    if text is None or not re.match(r"^https?://", text, re.IGNORECASE):
        return None
    return text


def build(raw: list[dict]) -> list[dict]:
    features: list[dict] = []
    seen: set[str] = set()
    for feature in raw:
        attributes = feature.get("properties") or {}
        # Re-checked rather than trusted to the where clause: if the service ever
        # ignored the filter, the result would be every hidden site in the pack.
        if _text(attributes.get("VISIBILITY_IND")) != "Yes":
            continue
        geometry = feature.get("geometry") or {}
        if geometry.get("type") != "Point":
            continue
        kind = KINDS.get(_text(attributes.get("FISHING_ACCESS_POINT_TYPE")) or "")
        if kind is None:
            continue
        identifier = f"on-fap-{int(attributes['OGF_ID'])}"
        if identifier in seen:
            continue
        seen.add(identifier)

        longitude, latitude = geometry["coordinates"][:2]
        properties: dict[str, object] = {"id": identifier, "kind": kind}
        if name := _text(attributes.get("SITE_NAME")):
            properties["name"] = name
        for key, field in (
            ("parking", "PARKING_PRESENCE_FLG"),
            ("fee", "USER_FEE_FLG"),
            ("accessible", "ACCESSIBILITY_FLG"),
        ):
            value = FLAGS.get(_text(attributes.get(field)) or "")
            if value is not None:
                properties[key] = value
        if owner := OWNERS.get(_text(attributes.get("SITE_OWNERSHIP_TYPE")) or ""):
            properties["owner"] = owner
        if surface := SURFACES.get(_text(attributes.get("MATERIAL_TYPE")) or ""):
            properties["surface"] = surface
        if verified := _date(attributes.get("SITE_LAST_VERIFICATION_DATE")):
            properties["verified"] = verified
        comment = _text(attributes.get("GENERAL_COMMENTS"))
        if comment and not _INTERNAL_COMMENT.match(comment):
            properties["comment"] = comment
        if info := _url(attributes.get("ADDITIONAL_INFORMATION_URL")):
            properties["info_url"] = info

        features.append(
            {
                "type": "Feature",
                "properties": properties,
                "geometry": {
                    "type": "Point",
                    "coordinates": [round(longitude, 5), round(latitude, 5)],
                },
            }
        )
    return features


def main() -> int:
    print("fetching Fishing Access Points …", flush=True)
    features = build(fetch())
    if not features:
        print("ERROR: no visible fishing access points returned")
        return 1

    counts = {
        label: sum(1 for f in features if f["properties"]["kind"] == kind)
        for kind, label in KIND_LABELS.items()
    }
    out = {
        "type": "FeatureCollection",
        "metadata": {
            "crs": "EPSG:4326",
            "province": "on",
            "layer": "fishing_access",
            "layer_role": "access_point",
            "geometry": "point",
            "feature_count": len(features),
            "coverage": (
                "Boat launches, docks and piers, and shore access sites in the "
                "provincial Fishing Access Point inventory, limited to the ones "
                "the province marks for public display."
            ),
            # Not flagged coverage_incomplete, although it is: that flag makes
            # the card print its caveat on every tap the layer has nothing for,
            # which for a layer of points is nearly every tap. The caveat travels
            # with the points instead, in completeness_note.
            "completeness_note": (
                "Not every launch or shore access is in the province's "
                "inventory, and sites the province asks not to be mapped are "
                "left out. No point on the map is not evidence there is no "
                "access."
            ),
            "boundary_accuracy": "mapped",
            "default_name": "Fishing access point",
            "kind_labels": KIND_LABELS,
            "unknown_note": (
                "Parking, fees, surface and accessibility are shown only where "
                "the province recorded them. Most sites leave them unrecorded."
            ),
            "note": (
                "Where the water starts, not whether you may fish it: seasons, "
                "sanctuaries and limits come from the Ontario Fishing "
                "Regulations Summary. A privately owned site may charge or "
                "refuse use."
            ),
            "license": LICENSE,
            "license_url": LICENSE_URL,
            "source": SOURCE,
            "source_url": SOURCE_URL,
            "data_description_url": DATA_DESCRIPTION_URL,
        },
        "features": features,
    }
    OUT.write_text(
        json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    print(
        f"Wrote {len(features)} access points -> {OUT} "
        f"({OUT.stat().st_size / 1e6:.2f} MB): "
        + ", ".join(f"{label} {n}" for label, n in counts.items())
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
