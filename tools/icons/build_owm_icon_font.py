#!/usr/bin/env python3
"""Build the OwmIcons font from the vendored game-icons artwork.

Material Icons has no game species, no animal sign, and no mushroom or berry, so
the glyphs for those come from `svg/`. They still have to arrive as a *font*
rather than as images, because `WaypointIcon.icon` is a Flutter `IconData` and
the app draws it in list rows, cards and filter chips. An image would need a
second rendering path and would drift from the map's sprite.

So this writes three things from one table:

  app/assets/fonts/OwmIcons.ttf        what Flutter draws in the app's own lists
  app/lib/waypoints/owm_icons.dart     the IconData constants the enum names
  tools/icons/owm_icon_font.json       codepoints and authors, read by
                                       build_waypoint_icons.py and by the
                                       attribution test

`build_waypoint_icons.py` then rasterises the map's SDF sprites from this very
font, which is what guarantees the list and the map draw the same shape.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.misc.transform import Transform
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SVG_DIR = Path(__file__).resolve().parent / "svg"
FONT_PATH = REPOSITORY_ROOT / "app" / "assets" / "fonts" / "OwmIcons.ttf"
DART_PATH = REPOSITORY_ROOT / "app" / "lib" / "waypoints" / "owm_icons.dart"
SIDECAR_PATH = Path(__file__).resolve().parent / "owm_icon_font.json"

FAMILY = "OwmIcons"
# game-icons draws everything in a 512 unit box, so keeping the em square the
# same size means the artwork needs no scaling and only the y flip below.
VIEWBOX = 512
UPM = 512

# The 512x512 black rectangle every upstream file opens with. It is the sheet
# the white ink is drawn on, not part of the glyph, and keeping it would render
# every icon as a solid block.
BACKGROUND = re.compile(r"^\s*M0 0h512v512H0z\s*$")

# Codepoints are assigned here and never computed, because three separate things
# are keyed on them: the font's cmap, the `IconData` in Dart, and the codepoint
# recorded in the waypoint icon manifest that a test asserts against. Renumbering
# one would silently draw a different animal on waypoints already saved.
#
# Private use area. There is no clash with Material Icons even where the numbers
# overlap, because a glyph is looked up by family as well as codepoint.
#
# id -> (codepoint, author folder, file stem)
GLYPHS: dict[str, tuple[int, str, str]] = {
    # Wildlife and sign.
    "deer": (0xE000, "caro-asercion", "deer"),
    "bear": (0xE001, "delapouite", "bear-head"),
    "boar": (0xE002, "caro-asercion", "boar"),
    "rabbit": (0xE003, "delapouite", "rabbit"),
    "squirrel": (0xE004, "delapouite", "squirrel"),
    "beaver": (0xE005, "delapouite", "beaver"),
    "waterfowl": (0xE006, "caro-asercion", "canadian-goose"),
    # Stands in for grouse, turkey and partridge together. game-icons has no
    # upland bird at all, and the nearest shapes are a rooster and a sparrow,
    # so one honest feather beats a farmyard chicken labelled as a grouse.
    "feather": (0xE007, "lorc", "feather"),
    "wolf": (0xE008, "lorc", "wolf-head"),
    # Cloven prints, so it reads as a hoof rather than duplicating the paw the
    # existing `sign` glyph already draws.
    "tracks": (0xE009, "delapouite", "deer-track"),

    # Terrain and water.
    "forest": (0xE00A, "delapouite", "forest"),
    "swamp": (0xE00B, "delapouite", "swamp"),
    "waterfall": (0xE00C, "delapouite", "waterfall"),
    "cave": (0xE00D, "delapouite", "cave-entrance"),
    "spring": (0xE00E, "delapouite", "well"),

    # Foraging, which Material could only ever draw as a leaf.
    "mushroom": (0xE00F, "lorc", "mushroom"),
    "berries": (0xE010, "delapouite", "berry-bush"),
    "nuts": (0xE011, "lorc", "acorn"),

    # Hunting.
    "tower-stand": (0xE012, "delapouite", "watchtower"),
    "glassing": (0xE013, "delapouite", "binoculars"),
    "gate": (0xE014, "delapouite", "gate"),
    "farm": (0xE015, "delapouite", "farm-tractor"),

    # Getting there, and one more line glyph.
    "bridge": (0xE016, "lorc", "bridge"),
    "atv-trail": (0xE017, "delapouite", "tire-tracks"),

    # Fishing. A fish landed, which is a different mark from `fishing`, the spot
    # you go to. Not called `catch`, which is a reserved word in Dart.
    "fish": (0xE018, "cathelineau", "flying-trout"),

    # Replacements for Material glyphs that were the nearest thing rather than
    # the right thing. The ids are unchanged, so every waypoint already saved
    # under them keeps its data and its colour and only the picture improves.
    "firepit": (0xE019, "lorc", "campfire"),
    "stand": (0xE01A, "delapouite", "ladder"),
    "harvest": (0xE01B, "lorc", "animal-skull"),
}

AUTHOR_NAMES = {
    "caro-asercion": "Caro Asercion",
    "cathelineau": "Cathelineau",
    "delapouite": "Delapouite",
    "lorc": "Lorc",
}

# Dart will not compile a constant named after one of its keywords, and the
# failure would land in generated code that nobody edits. Checked here so it is
# an error about the id instead.
DART_RESERVED = frozenset(
    """assert break case catch class const continue default do else enum
    extends false final finally for if in is new null rethrow return super
    switch this throw true try var void while with""".split()
)

LICENCE = "CC BY 3.0"
LICENCE_URL = "https://creativecommons.org/licenses/by/3.0/"
SOURCE_URL = "https://game-icons.net"


def credit_line() -> str:
    """The credit, worded the way the upstream licence asks for it."""
    authors = sorted(AUTHOR_NAMES.values())
    return (
        f"Icons made by {', '.join(authors[:-1])} and {authors[-1]}, "
        f"available at {SOURCE_URL}"
    )


def ink_paths(svg: str, name: str) -> list[str]:
    """The `d` of every path that is ink, with the background sheet dropped."""
    paths = re.findall(r"<path\b[^>]*?\bd=\"([^\"]+)\"", svg)
    if not paths:
        raise ValueError(f"{name}: no <path d=...> found")
    kept = [d for d in paths if not BACKGROUND.match(d)]
    if not kept:
        raise ValueError(f"{name}: every path looked like the background sheet")
    if len(kept) == len(paths):
        raise ValueError(
            f"{name}: no background sheet found. Upstream files all carry one, "
            "so this file is shaped differently and needs checking by hand "
            "rather than being drawn with the sheet included."
        )
    # An even-odd path relies on crossings to punch its holes, and TrueType fills
    # by winding, so the holes would come out solid. None of the vendored files
    # use it; this is here so that adding one that does fails loudly.
    if re.search(r"fill-rule\s*=\s*[\"']evenodd[\"']", svg):
        raise ValueError(
            f"{name}: uses fill-rule=evenodd, whose holes would fill solid as a "
            "glyph. Convert the path to non-zero winding before vendoring it."
        )
    return kept


def build_glyph(path: Path, name: str):
    pen = TTGlyphPen(None)
    # SVG's y axis grows downward and a font's grows upward, so without the flip
    # every animal renders upside down. Reflecting about the middle of the
    # viewBox also reverses winding direction, which is why the contours are
    # reversed back: TrueType fills by non-zero winding and an inverted contour
    # turns a glyph's counters solid.
    quadratic = Cu2QuPen(pen, max_err=0.5, reverse_direction=True)
    flip = TransformPen(quadratic, Transform(1, 0, 0, -1, 0, VIEWBOX))
    for d in ink_paths(path.read_text(encoding="utf-8"), name):
        parse_path(d, flip)
    glyph = pen.glyph()
    if glyph.numberOfContours == 0:
        raise ValueError(f"{name}: drew no contours")
    return glyph


def glyph_name(icon_id: str) -> str:
    """A legal PostScript glyph name. Hyphens are not allowed in one."""
    return icon_id.replace("-", "_")


# game-icons composes each icon inside the 512 box, so the ink lands only a few
# units off the axis at worst. Further out than this is not the artwork, it is a
# metrics or viewBox mistake, and this script shipped one: it recorded every left
# side bearing as 0 while the outlines kept their true x. A rasteriser places the
# glyph origin at `xMin - lsb`, so each glyph drew its own xMin too far left.
# Art that filled the box hid it; the ladder, 121 units in, sat a quarter of the
# em off centre.
CENTRING_TOLERANCE = 40


def horizontal_metrics(builder, glyphs, order) -> dict[str, tuple[int, int]]:
    """`(advance, lsb)` per glyph, with the bearing read off the real outline."""
    glyf = builder.font["glyf"]
    metrics = {}
    for name in order:
        glyph = glyphs[name]
        if glyph.numberOfContours == 0:
            metrics[name] = (UPM, 0)
            continue
        glyph.recalcBounds(glyf)
        offset = (glyph.xMin + glyph.xMax) / 2 - UPM / 2
        if abs(offset) > CENTRING_TOLERANCE:
            raise ValueError(
                f"{name}: ink spans x {glyph.xMin}..{glyph.xMax}, whose centre is "
                f"{offset:+.0f} units from the em's. It would draw visibly "
                "off-centre wherever Flutter sizes it as an Icon."
            )
        metrics[name] = (UPM, glyph.xMin)
    return metrics


def write_font(glyphs: dict[str, object], names: list[str]) -> None:
    order = [".notdef", *names]
    all_glyphs = {".notdef": TTGlyphPen(None).glyph(), **glyphs}

    builder = FontBuilder(UPM, isTTF=True)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap(
        {code: glyph_name(icon) for icon, (code, _, _) in GLYPHS.items()}
    )
    builder.setupGlyf(all_glyphs)
    builder.setupHorizontalMetrics(horizontal_metrics(builder, all_glyphs, order))
    # The ink fills the em square and sits on the baseline, which is what makes a
    # Flutter Icon of a given fontSize come out the same visual size as a
    # Material one.
    builder.setupHorizontalHeader(ascent=UPM, descent=0)
    builder.setupNameTable(
        {
            "familyName": FAMILY,
            "styleName": "Regular",
            "psName": f"{FAMILY}-Regular",
            "version": "1.000",
            "copyright": (
                f"Icons made by {', '.join(sorted(AUTHOR_NAMES.values()))}, "
                f"available at {SOURCE_URL}. Licensed {LICENCE}."
            ),
            "licenseDescription": f"{LICENCE}, {LICENCE_URL}",
        }
    )
    builder.setupOS2(
        sTypoAscender=UPM,
        sTypoDescender=0,
        usWinAscent=UPM,
        usWinDescent=0,
        achVendID="OWM ",
    )
    builder.setupPost()
    FONT_PATH.parent.mkdir(parents=True, exist_ok=True)
    builder.save(FONT_PATH)


def write_dart() -> None:
    lines = [
        "// GENERATED BY tools/icons/build_owm_icon_font.py. DO NOT EDIT.",
        "//",
        "// Glyphs Material Icons does not have: game species, animal sign, and",
        "// the terrain and access features the outdoors needs. Drawn from",
        "// artwork by "
        + ", ".join(sorted(AUTHOR_NAMES.values()))
        + f", {SOURCE_URL},",
        f"// licensed {LICENCE}. See tools/icons/svg/ATTRIBUTION.md.",
        "",
        "import 'package:flutter/widgets.dart';",
        "",
        "/// The codepoints in this app's own icon font.",
        "///",
        "/// Each is also the codepoint the map's SDF sprite was rasterised from,",
        "/// and a test asserts the two have not drifted apart.",
        "abstract final class OwmIcons {",
    ]
    for icon_id, (codepoint, _, _) in GLYPHS.items():
        member = re.sub(r"-(\w)", lambda m: m.group(1).upper(), icon_id)
        if member in DART_RESERVED:
            raise ValueError(
                f"'{icon_id}' becomes '{member}', which is a Dart keyword. "
                "Choose a different id: it is written into saved waypoint files "
                "and is the sprite's filename, so it has to be a name Dart can "
                "also spell."
            )
        lines.append(
            f"  static const IconData {member} = "
            f"IconData(0x{codepoint:04X}, fontFamily: '{FAMILY}');"
        )
    authors = sorted(AUTHOR_NAMES.values())
    lines += [
        "}",
        "",
        "/// Credit for the artwork the glyphs above were drawn from.",
        "///",
        "/// CC BY 3.0 asks for attribution in the work itself, not just in a",
        "/// repository, so the Settings screen shows this. Generated from the",
        "/// same table as the font so that adding artwork by someone new cannot",
        "/// leave them uncredited.",
        "abstract final class OwmIconsCredit {",
        f"  static const String source = '{SOURCE_URL}';",
        f"  static const String licence = '{LICENCE}';",
        f"  static const String licenceUrl = '{LICENCE_URL}';",
        "  static const List<String> authors = <String>[",
        *[f"    '{author}'," for author in authors],
        "  ];",
        "",
        "  /// Worded the way the upstream licence asks for it.",
        f"  static const String line = '{credit_line()}';",
        "}",
        "",
    ]
    DART_PATH.write_text("\n".join(lines), encoding="utf-8")


def write_sidecar() -> None:
    SIDECAR_PATH.write_text(
        json.dumps(
            {
                "note": (
                    "Generated by tools/icons/build_owm_icon_font.py. "
                    "Do not edit by hand."
                ),
                "family": FAMILY,
                "font": FONT_PATH.relative_to(REPOSITORY_ROOT).as_posix(),
                "units_per_em": UPM,
                "source": SOURCE_URL,
                "licence": LICENCE,
                "licence_url": LICENCE_URL,
                "credit": credit_line(),
                "glyphs": {
                    icon_id: {
                        "codepoint": codepoint,
                        "author": AUTHOR_NAMES[author],
                        "file": f"{author}/{stem}.svg",
                    }
                    for icon_id, (codepoint, author, stem) in GLYPHS.items()
                },
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    codepoints = [code for code, _, _ in GLYPHS.values()]
    if len(set(codepoints)) != len(codepoints):
        raise ValueError("two glyphs share a codepoint")

    glyphs: dict[str, object] = {}
    names: list[str] = []
    for icon_id, (codepoint, author, stem) in GLYPHS.items():
        path = SVG_DIR / author / f"{stem}.svg"
        if not path.is_file():
            raise FileNotFoundError(f"{icon_id}: {path} is missing")
        glyph = build_glyph(path, icon_id)
        name = glyph_name(icon_id)
        glyphs[name] = glyph
        names.append(name)
        print(
            f"  {icon_id:<12} U+{codepoint:04X}  "
            f"{glyph.numberOfContours:>2} contours  "
            f"{AUTHOR_NAMES[author]}/{stem}"
        )

    write_font(glyphs, names)
    write_dart()
    write_sidecar()

    print(f"\nfont:     {FONT_PATH}  ({FONT_PATH.stat().st_size} bytes)")
    print(f"dart:     {DART_PATH}")
    print(f"sidecar:  {SIDECAR_PATH}")
    print(f"\n{len(GLYPHS)} glyphs. Now run build_waypoint_icons.py to")
    print("rasterise the map's sprites from this font.")


if __name__ == "__main__":
    main()
