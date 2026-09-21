/// Map imagery the user brings themselves, and the rules for reading it.
///
/// Two shapes, because the two things people mean by "my own map" are not the
/// same thing. One is a *service*: a tile URL, which is what ArcGIS Online,
/// Mapbox and CalTopo all mean by a custom basemap, and which needs a
/// connection. The other is a *file*: a georeferenced map somebody bought or
/// made, which is the case that prompted this — the Algonquin paddling maps sold
/// as a Garmin Custom Map — and which works with no signal at all.
///
/// Everything here is a pure function of its input so it can be tested, because
/// the map shell cannot be widget-tested against a native MapLibre view. That
/// matters more than usual here: a misread corner coordinate draws a real map in
/// the wrong place, which is worse than drawing nothing. A wrong overlay is
/// still a map, still legible, still trusted.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:xml/xml.dart';

/// A box of ground, in degrees. Bare doubles rather than MapLibre's
/// [LatLngBounds] so this file stays testable without the plugin.
class GeoBox {
  const GeoBox({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  double get centreLat => (north + south) / 2;
  double get centreLon => (east + west) / 2;

  /// Deliberately no antimeridian handling. Canada does not cross it, the app
  /// ships Ontario and Quebec, and a box that appeared to wrap would be a
  /// transposed bbox rather than a real one — so pretending to support it would
  /// turn a loud failure into a quiet one.
  bool overlaps(GeoBox other) =>
      west < other.east &&
      east > other.west &&
      south < other.north &&
      north > other.south;

  Map<String, Object?> toJson() => {
        'north': north,
        'south': south,
        'east': east,
        'west': west,
      };

  static GeoBox? fromJson(Object? json) {
    if (json is! Map) return null;
    final north = _asDouble(json['north']);
    final south = _asDouble(json['south']);
    final east = _asDouble(json['east']);
    final west = _asDouble(json['west']);
    if (north == null || south == null || east == null || west == null) {
      return null;
    }
    return GeoBox(north: north, south: south, east: east, west: west);
  }

  /// The smallest box containing all of [boxes], for framing an imported map.
  static GeoBox? around(Iterable<GeoBox> boxes) {
    GeoBox? total;
    for (final box in boxes) {
      total = total == null
          ? box
          : GeoBox(
              north: math.max(total.north, box.north),
              south: math.min(total.south, box.south),
              east: math.max(total.east, box.east),
              west: math.min(total.west, box.west),
            );
    }
    return total;
  }
}

/// One image and the ground it covers, as a KML `<GroundOverlay>` gives it.
class GroundOverlay {
  const GroundOverlay({
    required this.href,
    required this.box,
    this.drawOrder = 0,
  });

  /// Path inside the archive, kept as written so the file can be found again.
  final String href;

  final GeoBox box;

  /// KML's own stacking order, honoured because a map cut into tiles that
  /// overlap at the seams looks wrong if they stack the other way round.
  final int drawOrder;

  Map<String, Object?> toJson() => {
        'href': href,
        'box': box.toJson(),
        'drawOrder': drawOrder,
      };

  static GroundOverlay? fromJson(Object? json) {
    if (json is! Map) return null;
    final href = json['href'];
    final box = GeoBox.fromJson(json['box']);
    if (href is! String || href.isEmpty || box == null) return null;
    return GroundOverlay(
      href: href,
      box: box,
      drawOrder: _asDouble(json['drawOrder'])?.round() ?? 0,
    );
  }
}

/// A map file that could not be used, with the reason to put on screen.
///
/// Every message names what was wrong with *this file* rather than saying it is
/// invalid, because the user did not write it and cannot fix it. What they can
/// do is export it again in a different format, and that only helps if they are
/// told which part the app could not take.
class CustomMapUnreadable implements Exception {
  const CustomMapUnreadable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a KMZ's KML turned out to contain.
class ParsedCustomMap {
  const ParsedCustomMap({
    required this.overlays,
    this.name,
    this.credit,
  });

  final List<GroundOverlay> overlays;

  /// The document's own name, preferred over the file name because the person
  /// who made the map titled it and the file may have been renamed on the way.
  final String? name;

  /// Whatever the document says about where it came from.
  ///
  /// Carried through to the map so an imported map keeps its attribution the way
  /// every other layer in this app does. The app cannot verify it, and does not
  /// claim to — it repeats what the file says and says that is what it is doing.
  final String? credit;
}

/// Reads the `<GroundOverlay>` elements out of a KML document.
///
/// Rotation is refused rather than ignored. KML lets a `<LatLonBox>` carry a
/// rotation and MapLibre's image source takes four free corners, so drawing a
/// rotated overlay means rotating corners in degrees — where a degree of
/// longitude is shorter than a degree of latitude, by a factor that changes with
/// latitude. Getting that subtly wrong puts a legible map slightly off the
/// ground it describes, which is the exact failure this app exists not to
/// produce. Garmin's own Custom Maps do not support rotation either, so a file
/// aimed at a GPS will not have it.
ParsedCustomMap readCustomMapKml(String kml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(kml);
  } on XmlException catch (error) {
    throw CustomMapUnreadable('The KML inside this file will not parse: $error');
  }

  final overlays = <GroundOverlay>[];
  for (final element in document.findAllElements('GroundOverlay')) {
    final href = _text(element, 'href');
    final latLonBox = element.findAllElements('LatLonBox').firstOrNull;
    if (href == null || latLonBox == null) continue;

    final rotation = _asDouble(_text(latLonBox, 'rotation')) ?? 0;
    if (rotation.abs() > 0.01) {
      throw CustomMapUnreadable(
        'This map is rotated ${rotation.abs().toStringAsFixed(1)}° rather than '
        'squared with north, and drawing it would put it slightly off the '
        'ground it covers. A Garmin Custom Map export of the same map will not '
        'be rotated.',
      );
    }

    final north = _asDouble(_text(latLonBox, 'north'));
    final south = _asDouble(_text(latLonBox, 'south'));
    final east = _asDouble(_text(latLonBox, 'east'));
    final west = _asDouble(_text(latLonBox, 'west'));
    if (north == null || south == null || east == null || west == null) continue;
    // A box with no height or width covers no ground, and MapLibre would stretch
    // the image across the whole world rather than refuse it.
    if (north <= south || east <= west) continue;

    overlays.add(
      GroundOverlay(
        href: _archivePath(href),
        box: GeoBox(north: north, south: south, east: east, west: west),
        drawOrder: _asDouble(_text(element, 'drawOrder'))?.round() ?? 0,
      ),
    );
  }

  if (overlays.isEmpty) {
    // Worth telling these two apart. A super-overlay is a *working* Google Earth
    // map that happens to be built out of references to other files, and someone
    // holding one has a fixable problem: export the same map for Garmin.
    final linked = document.findAllElements('NetworkLink').isNotEmpty;
    throw CustomMapUnreadable(
      linked
          ? 'This is a Google Earth super-overlay: it points at other files '
              'rather than holding the map itself, and those cannot be followed '
              'offline. Export the same map as a Garmin Custom Map instead.'
          : 'No map images in this file. It needs GroundOverlay images with '
              'their corner coordinates, which is what a Garmin Custom Map or '
              'Google Earth image overlay contains.',
    );
  }

  overlays.sort((a, b) => a.drawOrder.compareTo(b.drawOrder));
  return ParsedCustomMap(
    overlays: overlays,
    name: _text(document.rootElement, 'name'),
    credit: _text(document.rootElement, 'description'),
  );
}

/// Strips the leading `./` some exporters write, and rejects anything that is
/// not a plain path inside the archive.
///
/// `..` is the reason this is a function. An href is a path out of a zip the app
/// is about to unpack, and a file that walks upward out of its own directory is
/// a zip-slip, whether it got there by malice or by a bad exporter.
String _archivePath(String href) {
  final cleaned = href.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
  if (cleaned.startsWith('/') ||
      cleaned.startsWith('http') ||
      cleaned.split('/').contains('..')) {
    throw CustomMapUnreadable(
      'This map points at "$href", which is outside the file. Only images '
      'packed inside the map itself can be used offline.',
    );
  }
  return cleaned;
}

/// A tile URL the user typed, after being looked over.
class TileUrlCheck {
  const TileUrlCheck._(this.template, this.complaint);

  const TileUrlCheck.good(String template) : this._(template, null);
  const TileUrlCheck.bad(String complaint) : this._(null, complaint);

  /// The usable template, with the placeholders in the case MapLibre wants.
  final String? template;

  /// What to tell the user, or null when there is nothing to say.
  final String? complaint;

  bool get isUsable => template != null;
}

/// Checks and normalises an XYZ tile URL template.
///
/// The placeholders are upper-cased in CalTopo's documentation and lower-cased
/// in MapLibre's, and somebody copying a working template out of one to paste
/// into the other should not have to know that. So case is fixed silently, and
/// only things that cannot be fixed are complained about.
TileUrlCheck checkTileUrl(String input) {
  var template = input.trim();
  if (template.isEmpty) return const TileUrlCheck.bad('Paste a tile URL.');

  final uri = Uri.tryParse(template);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return const TileUrlCheck.bad(
      'That is not a web address. A tile URL starts with https:// and has '
      '{z}/{x}/{y} in it where the tile numbers go.',
    );
  }

  // Both of these are what a half-finished paste leaves behind, and both pass
  // every other check here: the placeholders are present and the string starts
  // with https, so the layer would be added and then quietly draw nothing.
  // Saying so at the dialog is the only place the user can still see the cause.
  if (RegExp(r'\s').hasMatch(template)) {
    return const TileUrlCheck.bad(
      'There is a space in this URL. A tile address has none, so something was '
      'probably cut off or corrected on the way in.',
    );
  }
  if (template.indexOf('://') != template.lastIndexOf('://')) {
    return const TileUrlCheck.bad(
      'There are two web addresses here. Paste just the one, ending in the '
      '{z}/{x}/{y} part.',
    );
  }

  for (final placeholder in ['z', 'x', 'y']) {
    template = template.replaceAll('{${placeholder.toUpperCase()}}', '{$placeholder}');
  }

  // Named rather than lumped in with "no placeholders", because a template with
  // {bbox} or {left} in it is a *working WMS* URL and the user has not made a
  // mistake so much as brought the other kind of service. MapLibre's raster
  // source speaks only XYZ, so this is a limit of the app, and it should say so
  // in those terms.
  if (RegExp(r'\{(bbox|left|bottom|right|top|tilesize|width|height)\}',
          caseSensitive: false)
      .hasMatch(template)) {
    return const TileUrlCheck.bad(
      'That is a WMS address, which asks for a picture of a box rather than '
      'numbered tiles. Only XYZ tile URLs work here — the kind with '
      '{z}/{x}/{y} in them.',
    );
  }

  final missing = ['{z}', '{x}', '{y}'].where((p) => !template.contains(p));
  if (missing.isNotEmpty) {
    return TileUrlCheck.bad(
      'This URL has no ${missing.join(' or ')} in it, so every tile would be '
      'the same picture. A tile URL looks like '
      'https://example.com/tiles/{z}/{x}/{y}.png',
    );
  }

  // {s} picks a server at random from a list the template does not carry, which
  // MapLibre has no notion of. Left in, it would request a host literally named
  // "{s}" and the layer would be silently blank.
  if (template.contains('{s}')) {
    return const TileUrlCheck.bad(
      'This URL has {s} in it for rotating between servers, which this app '
      'cannot fill in. Replace {s} with one of the server letters, usually a.',
    );
  }

  return TileUrlCheck.good(template);
}

/// A map the user added, of either kind.
sealed class CustomMap {
  const CustomMap({
    required this.id,
    required this.name,
    required this.credit,
    required this.visible,
    required this.opacity,
  });

  final String id;
  final String name;

  /// Where it came from, in the user's words or the file's.
  ///
  /// Not optional. Every other layer in this app carries its source, and a
  /// borrowed basemap is the layer most likely to belong to somebody who expects
  /// to be named.
  final String credit;

  final bool visible;

  /// Faded, mostly so tenure overlays underneath can be read through a map that
  /// covers them. A borrowed map draws over everything the app knows.
  final double opacity;

  Map<String, Object?> toJson();

  CustomMap copyWith({bool? visible, double? opacity, String? name});

  /// The ground it covers, for framing the camera on it. Null for a tile URL,
  /// which does not say where it has tiles.
  GeoBox? get extent;

  static CustomMap? fromJson(Object? json) {
    if (json is! Map) return null;
    return switch (json['kind']) {
      'tiles' => TileMap._fromJson(json),
      'file' => FileMap._fromJson(json),
      _ => null,
    };
  }
}

/// Tiles fetched from a URL, the way every other tool means "custom basemap".
class TileMap extends CustomMap {
  const TileMap({
    required super.id,
    required super.name,
    required super.credit,
    required this.template,
    super.visible = true,
    super.opacity = 1,
    this.maxZoom = 19,
  });

  /// With `{z}`, `{x}` and `{y}` where the tile numbers go.
  final String template;

  /// Above this MapLibre keeps showing the deepest tiles it has rather than
  /// asking for ones the server does not hold and drawing nothing.
  final int maxZoom;

  /// Nothing in an XYZ URL says where its coverage stops, and guessing would
  /// mean claiming to know. A tile map is simply never framed automatically.
  @override
  GeoBox? get extent => null;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'tiles',
        'id': id,
        'name': name,
        'credit': credit,
        'template': template,
        'visible': visible,
        'opacity': opacity,
        'maxZoom': maxZoom,
      };

  @override
  TileMap copyWith({bool? visible, double? opacity, String? name}) => TileMap(
        id: id,
        name: name ?? this.name,
        credit: credit,
        template: template,
        visible: visible ?? this.visible,
        opacity: opacity ?? this.opacity,
        maxZoom: maxZoom,
      );

  static TileMap? _fromJson(Map<Object?, Object?> json) {
    final id = json['id'];
    final template = json['template'];
    if (id is! String || template is! String) return null;
    return TileMap(
      id: id,
      name: json['name'] as String? ?? 'Custom tiles',
      credit: json['credit'] as String? ?? '',
      template: template,
      visible: json['visible'] as bool? ?? true,
      opacity: _asDouble(json['opacity']) ?? 1,
      maxZoom: _asDouble(json['maxZoom'])?.round() ?? 19,
    );
  }
}

/// An imported map file, unpacked into a directory of images on the device.
class FileMap extends CustomMap {
  const FileMap({
    required super.id,
    required super.name,
    required super.credit,
    required this.overlays,
    super.visible = true,
    super.opacity = 1,
  });

  final List<GroundOverlay> overlays;

  @override
  GeoBox? get extent => GeoBox.around(overlays.map((o) => o.box));

  @override
  Map<String, Object?> toJson() => {
        'kind': 'file',
        'id': id,
        'name': name,
        'credit': credit,
        'visible': visible,
        'opacity': opacity,
        'overlays': [for (final overlay in overlays) overlay.toJson()],
      };

  @override
  FileMap copyWith({bool? visible, double? opacity, String? name}) => FileMap(
        id: id,
        name: name ?? this.name,
        credit: credit,
        overlays: overlays,
        visible: visible ?? this.visible,
        opacity: opacity ?? this.opacity,
      );

  static FileMap? _fromJson(Map<Object?, Object?> json) {
    final id = json['id'];
    if (id is! String) return null;
    final overlays = <GroundOverlay>[];
    for (final entry in (json['overlays'] as List? ?? const [])) {
      final overlay = GroundOverlay.fromJson(entry);
      if (overlay != null) overlays.add(overlay);
    }
    if (overlays.isEmpty) return null;
    return FileMap(
      id: id,
      name: json['name'] as String? ?? 'Imported map',
      credit: json['credit'] as String? ?? '',
      overlays: overlays,
      visible: json['visible'] as bool? ?? true,
      opacity: _asDouble(json['opacity']) ?? 1,
    );
  }
}

/// How many overlay images the map holds at once.
///
/// This is a memory budget, not a preference. MapLibre decodes an image source
/// to a bitmap and keeps it: a one-megapixel JPEG is four megabytes once
/// unpacked, whatever it weighs on disk. Garmin allows a hundred tiles in one
/// Custom Map, and holding all of them would be four hundred megabytes and a
/// dead app. Twelve is about fifty, which a phone can carry.
const maxDrawnOverlays = 12;

/// Which overlays are worth holding for a view of [view].
///
/// The ones on screen, nearest the middle first, capped. Nearest-first is what
/// makes the cap behave when someone zooms out past the budget: the tiles that
/// survive are the ones under the user's thumb rather than whichever the file
/// happened to list first, so the middle of the screen stays covered and the
/// gaps appear at the edges where they are obvious.
List<GroundOverlay> overlaysToDraw(
  List<GroundOverlay> overlays,
  GeoBox view, {
  int limit = maxDrawnOverlays,
}) {
  final visible = overlays.where((o) => o.box.overlaps(view)).toList();
  if (visible.length > limit) {
    visible.sort((a, b) {
      final byDistance =
          _distance(a.box, view).compareTo(_distance(b.box, view));
      // Draw order decides ties so the result does not depend on sort stability
      // for tiles equally far from the centre, which is every corner of a grid.
      return byDistance != 0 ? byDistance : a.drawOrder.compareTo(b.drawOrder);
    });
    visible.removeRange(limit, visible.length);
  }
  visible.sort((a, b) => a.drawOrder.compareTo(b.drawOrder));
  return visible;
}

/// Squared degrees between two box centres. Squared because only the ordering is
/// used, and degrees because the comparison is between tiles of one map at one
/// latitude, where the difference from metres is a constant factor.
double _distance(GeoBox box, GeoBox view) {
  final dLat = box.centreLat - view.centreLat;
  final dLon = box.centreLon - view.centreLon;
  return dLat * dLat + dLon * dLon;
}

String? _text(XmlElement parent, String name) {
  final found = parent.findAllElements(name).firstOrNull;
  final text = found?.innerText.trim();
  return text == null || text.isEmpty ? null : text;
}

double? _asDouble(Object? value) => switch (value) {
      num value => value.toDouble(),
      String value => double.tryParse(value.trim()),
      _ => null,
    };

/// Reads the stored list, dropping entries this build cannot make sense of.
///
/// Lenient on purpose, in both directions: a downgrade should not wipe the list,
/// and a map whose files were deleted from under it should disappear quietly
/// rather than keep a row that draws nothing.
List<CustomMap> decodeCustomMaps(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (CustomMap.fromJson(entry) case final map?) map,
    ];
  } on FormatException {
    return const [];
  }
}

String encodeCustomMaps(List<CustomMap> maps) =>
    jsonEncode([for (final map in maps) map.toJson()]);
