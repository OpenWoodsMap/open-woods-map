import 'package:flutter/material.dart';

/// `#RRGGBB`, which is what MapLibre's `icon-color` wants.
String hexColour(Color colour) =>
    '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// `aabbggrr` — KML's byte order, which is reversed from everyone else's and is
/// a standing source of blue waypoints that were meant to be red.
String kmlColour(Color colour) {
  final rgb = colour.toARGB32() & 0xFFFFFF;
  String two(int value) => value.toRadixString(16).padLeft(2, '0');
  return 'ff${two(rgb & 0xFF)}${two((rgb >> 8) & 0xFF)}${two((rgb >> 16) & 0xFF)}';
}

/// The colours a waypoint can be given, as the user sees them.
///
/// A short list on purpose. These have to stay apart from each other on a
/// satellite basemap and on a green land-cover one, and a free colour picker
/// mostly produces choices that fail on one or the other.
enum WaypointColour {
  red(id: 'red', label: 'Red', value: Color(0xFFB3261E)),
  orange(id: 'orange', label: 'Orange', value: Color(0xFFE65100)),
  yellow(id: 'yellow', label: 'Yellow', value: Color(0xFFF9A825)),
  green(id: 'green', label: 'Green', value: Color(0xFF2E7D32)),
  teal(id: 'teal', label: 'Teal', value: Color(0xFF00838F)),
  blue(id: 'blue', label: 'Blue', value: Color(0xFF1565C0)),
  purple(id: 'purple', label: 'Purple', value: Color(0xFF6A1B9A)),
  brown(id: 'brown', label: 'Brown', value: Color(0xFF5D4037)),
  black(id: 'black', label: 'Black', value: Color(0xFF212121)),
  white(id: 'white', label: 'White', value: Color(0xFFFAFAFA));

  const WaypointColour({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final Color value;

  static WaypointColour? fromId(String? id) {
    if (id == null) return null;
    final wanted = id.trim().toLowerCase();
    for (final colour in values) {
      if (colour.id == wanted) return colour;
    }
    return null;
  }

  /// The closest of these ten to an arbitrary `#RRGGBB`, or null if it is not a
  /// colour at all.
  ///
  /// Needed because other apps store a free colour and this list is closed.
  /// CalTopo alone writes `0000FF`, `#FFFFFF` and `#ff0000` in one file, so the
  /// spelling is tolerated as well as the value.
  ///
  /// Approximating is the right answer here rather than dropping the colour: the
  /// user picked it deliberately and which of ten buckets it lands in is a
  /// question of appearance, not a claim about the world. Nothing legal or
  /// factual rests on it. It is still an approximation, which is why the import
  /// says how many colours it had to approximate rather than implying the file
  /// round tripped.
  static WaypointColour? fromHex(String? hex) {
    final parsed = _parseHex(hex);
    return parsed == null ? null : nearest(parsed);
  }

  /// The closest of these ten to [colour].
  static WaypointColour nearest(Color colour) {
    // Weighted so the comparison is roughly perceptual rather than a raw RGB
    // distance, under which mid greens and mid browns swap places. Cheap
    // weights instead of a real colour space because the targets are ten
    // deliberately well separated hues, not a gradient.
    const rWeight = 2.0;
    const gWeight = 4.0;
    const bWeight = 3.0;
    double distance(Color a, Color b) {
      final dr = ((a.toARGB32() >> 16) & 0xFF) - ((b.toARGB32() >> 16) & 0xFF);
      final dg = ((a.toARGB32() >> 8) & 0xFF) - ((b.toARGB32() >> 8) & 0xFF);
      final db = (a.toARGB32() & 0xFF) - (b.toARGB32() & 0xFF);
      return rWeight * dr * dr + gWeight * dg * dg + bWeight * db * db;
    }

    var best = values.first;
    var bestDistance = distance(colour, best.value);
    for (final candidate in values.skip(1)) {
      final candidateDistance = distance(colour, candidate.value);
      if (candidateDistance < bestDistance) {
        best = candidate;
        bestDistance = candidateDistance;
      }
    }
    return best;
  }

  /// `#RRGGBB`, `RRGGBB`, `#RGB` or `RGB`, in any case, or null.
  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final trimmed = hex.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) return null;
    final expanded = switch (trimmed.length) {
      3 => trimmed.split('').map((digit) => '$digit$digit').join(),
      6 => trimmed,
      // Eight digits carry an alpha channel, and where it sits is not knowable
      // from the digits: CSS puts it last, KML and Flutter put it first, and
      // reading it at the wrong end turns an opaque red into a transparent one.
      // Neither format this app imports writes eight, so refusing beats a coin
      // toss that silently recolours a waypoint.
      _ => null,
    };
    if (expanded == null) return null;
    return Color(0xFF000000 | int.parse(expanded, radix: 16));
  }
}
