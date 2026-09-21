import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/custom_map.dart';

/// A KML document with [overlays] inside it, so each test can vary one thing.
String kml(String overlays, {String name = 'Test map', String? description}) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
  <name>$name</name>
  ${description == null ? '' : '<description>$description</description>'}
  $overlays
</Document>
</kml>
''';

String overlay({
  String href = 'tiles/r0c0.jpg',
  double north = 45.6,
  double south = 45.5,
  double east = -78.6,
  double west = -78.8,
  String extra = '',
  int drawOrder = 50,
}) =>
    '''
  <GroundOverlay>
    <name>$href</name>
    <drawOrder>$drawOrder</drawOrder>
    <Icon><href>$href</href></Icon>
    <LatLonBox>
      <north>$north</north>
      <south>$south</south>
      <east>$east</east>
      <west>$west</west>
      $extra
    </LatLonBox>
  </GroundOverlay>
''';

void main() {
  group('reading a Garmin Custom Map', () {
    test('an overlay keeps its image and the ground it covers', () {
      final parsed = readCustomMapKml(kml(overlay()));

      expect(parsed.name, 'Test map');
      expect(parsed.overlays, hasLength(1));
      final only = parsed.overlays.single;
      expect(only.href, 'tiles/r0c0.jpg');
      expect(only.box.north, 45.6);
      expect(only.box.south, 45.5);
      expect(only.box.east, -78.6);
      expect(only.box.west, -78.8);
    });

    test('the description is carried through as the credit', () {
      final parsed = readCustomMapKml(
        kml(overlay(), description: 'Maps by Someone'),
      );
      expect(parsed.credit, 'Maps by Someone');
    });

    test('overlays come back in draw order, not document order', () {
      final parsed = readCustomMapKml(
        kml(
          overlay(href: 'top.jpg', drawOrder: 9) +
              overlay(href: 'bottom.jpg', drawOrder: 1),
        ),
      );
      expect(
        parsed.overlays.map((o) => o.href),
        ['bottom.jpg', 'top.jpg'],
      );
    });

    test('a leading ./ on the href is stripped', () {
      final parsed = readCustomMapKml(kml(overlay(href: './tiles/a.jpg')));
      expect(parsed.overlays.single.href, 'tiles/a.jpg');
    });

    test('a rotated overlay is refused rather than drawn askew', () {
      expect(
        () => readCustomMapKml(kml(overlay(extra: '<rotation>12.5</rotation>'))),
        throwsA(
          isA<CustomMapUnreadable>().having(
            (e) => e.message,
            'message',
            allOf(contains('12.5'), contains('Garmin')),
          ),
        ),
      );
    });

    test('a rotation of zero is not a rotation', () {
      final parsed = readCustomMapKml(
        kml(overlay(extra: '<rotation>0</rotation>')),
      );
      expect(parsed.overlays, hasLength(1));
    });

    test('a box with no height covers no ground, so it is dropped', () {
      expect(
        () => readCustomMapKml(kml(overlay(north: 45.5, south: 45.5))),
        throwsA(isA<CustomMapUnreadable>()),
      );
    });

    test('an href pointing out of the archive is refused', () {
      expect(
        () => readCustomMapKml(kml(overlay(href: '../../secrets.jpg'))),
        throwsA(
          isA<CustomMapUnreadable>()
              .having((e) => e.message, 'message', contains('outside the file')),
        ),
      );
    });

    test('an href on the web is refused, because it cannot work offline', () {
      expect(
        () => readCustomMapKml(kml(overlay(href: 'https://host/a.jpg'))),
        throwsA(isA<CustomMapUnreadable>()),
      );
    });

    test('a super-overlay says so, rather than saying the file is empty', () {
      expect(
        () => readCustomMapKml(
          kml('<NetworkLink><Link><href>1/0/0.kml</href></Link></NetworkLink>'),
        ),
        throwsA(
          isA<CustomMapUnreadable>().having(
            (e) => e.message,
            'message',
            allOf(contains('super-overlay'), contains('Garmin')),
          ),
        ),
      );
    });

    test('a KML with only placemarks names what is missing', () {
      expect(
        () => readCustomMapKml(
          kml('<Placemark><name>A camp</name></Placemark>'),
        ),
        throwsA(
          isA<CustomMapUnreadable>()
              .having((e) => e.message, 'message', contains('No map images')),
        ),
      );
    });

    test('something that is not XML at all fails with a reason', () {
      expect(
        () => readCustomMapKml('not xml'),
        throwsA(isA<CustomMapUnreadable>()),
      );
    });
  });

  group('checking a tile URL', () {
    test('a plain XYZ template is accepted unchanged', () {
      final checked = checkTileUrl('https://host/tiles/{z}/{x}/{y}.png');
      expect(checked.isUsable, isTrue);
      expect(checked.template, 'https://host/tiles/{z}/{x}/{y}.png');
      expect(checked.complaint, isNull);
    });

    test("CalTopo's upper-case placeholders are fixed silently", () {
      // Worth a test of its own: every worked example in CalTopo's own docs is
      // upper-cased, so this is the form people will paste.
      final checked = checkTileUrl('https://host/{Z}/{X}/{Y}.png');
      expect(checked.template, 'https://host/{z}/{x}/{y}.png');
      expect(checked.complaint, isNull);
    });

    test('surrounding whitespace is trimmed, because pasting adds it', () {
      expect(
        checkTileUrl('  https://host/{z}/{x}/{y}.png\n').template,
        'https://host/{z}/{x}/{y}.png',
      );
    });

    test('a WMS URL is named as a WMS rather than as a typo', () {
      final checked = checkTileUrl(
        'https://host/wms?BBOX={left},{bottom},{right},{top}&WIDTH={tilesize}',
      );
      expect(checked.isUsable, isFalse);
      expect(checked.complaint, contains('WMS'));
    });

    test('a URL with no placeholders says every tile would be the same', () {
      final checked = checkTileUrl('https://host/tiles.png');
      expect(checked.isUsable, isFalse);
      expect(checked.complaint, contains('the same picture'));
    });

    test('a missing placeholder is named specifically', () {
      expect(checkTileUrl('https://host/{z}/{x}.png').complaint, contains('{y}'));
    });

    test('{s} is refused, because it would request a host called {s}', () {
      final checked = checkTileUrl('https://{s}.host/{z}/{x}/{y}.png');
      expect(checked.isUsable, isFalse);
      expect(checked.complaint, contains('{s}'));
    });

    test('something that is not a URL is refused', () {
      expect(checkTileUrl('tiles/{z}/{x}/{y}.png').isUsable, isFalse);
      expect(checkTileUrl('').complaint, isNotNull);
    });

    // Both of these came out of real fumbling with this dialog, and both would
    // otherwise be accepted and then draw nothing at all.
    test('a space inside the URL is refused, not silently kept', () {
      final checked = checkTileUrl(
        'https://host/Map server/tile/{z}/{x}/{y}',
      );
      expect(checked.isUsable, isFalse);
      expect(checked.complaint, contains('space'));
    });

    test('two URLs glued together are refused', () {
      final checked = checkTileUrl(
        'https://host/partialhttps://host/tiles/{z}/{x}/{y}.png',
      );
      expect(checked.isUsable, isFalse);
      expect(checked.complaint, contains('two web addresses'));
    });
  });

  group('deciding which overlays to hold', () {
    /// A row of four tiles side by side, each a tenth of a degree wide.
    List<GroundOverlay> row(int count) => [
          for (var i = 0; i < count; i++)
            GroundOverlay(
              href: 'r0c$i.jpg',
              drawOrder: i,
              box: GeoBox(
                north: 45.6,
                south: 45.5,
                west: -79 + i * 0.1,
                east: -79 + (i + 1) * 0.1,
              ),
            ),
        ];

    test('only the overlays on screen are held', () {
      final drawn = overlaysToDraw(
        row(4),
        const GeoBox(north: 45.6, south: 45.5, west: -79, east: -78.9),
      );
      expect(drawn.map((o) => o.href), ['r0c0.jpg']);
    });

    test('an overlay off screen is not held', () {
      final drawn = overlaysToDraw(
        row(4),
        const GeoBox(north: 50, south: 49, west: -79, east: -78),
      );
      expect(drawn, isEmpty);
    });

    test('over the limit, the ones nearest the middle survive', () {
      // The cap is a memory budget, so what it keeps matters: the middle of the
      // screen has to stay covered and the holes belong at the edges.
      final drawn = overlaysToDraw(
        row(9),
        const GeoBox(north: 45.6, south: 45.5, west: -79, east: -78.1),
        limit: 3,
      );
      expect(drawn.map((o) => o.href), ['r0c3.jpg', 'r0c4.jpg', 'r0c5.jpg']);
    });

    test('what survives the cap is still in draw order', () {
      final drawn = overlaysToDraw(
        row(9),
        const GeoBox(north: 45.6, south: 45.5, west: -79, east: -78.1),
        limit: 4,
      );
      expect(
        drawn.map((o) => o.drawOrder).toList(),
        [...drawn.map((o) => o.drawOrder)]..sort(),
      );
    });

    test('the default limit is the memory budget, not unlimited', () {
      expect(maxDrawnOverlays, lessThan(20));
      final drawn = overlaysToDraw(
        row(40),
        const GeoBox(north: 45.6, south: 45.5, west: -79, east: -75),
      );
      expect(drawn, hasLength(maxDrawnOverlays));
    });
  });

  group('boxes', () {
    test('touching edges do not count as overlapping', () {
      const left = GeoBox(north: 1, south: 0, west: 0, east: 1);
      const right = GeoBox(north: 1, south: 0, west: 1, east: 2);
      expect(left.overlaps(right), isFalse);
    });

    test('the extent of a grid is the box around all of it', () {
      final around = GeoBox.around(const [
        GeoBox(north: 45.6, south: 45.5, west: -79, east: -78.9),
        GeoBox(north: 45.7, south: 45.4, west: -78.5, east: -78.1),
      ]);
      expect(around!.north, 45.7);
      expect(around.south, 45.4);
      expect(around.west, -79);
      expect(around.east, -78.1);
    });

    test('an imported map knows the ground it covers', () {
      final map = FileMap(
        id: '1',
        name: 'A map',
        credit: 'Someone',
        overlays: readCustomMapKml(
          kml(
            overlay(href: 'a.jpg', west: -79, east: -78.9) +
                overlay(href: 'b.jpg', west: -78.9, east: -78.8),
          ),
        ).overlays,
      );
      expect(map.extent!.west, -79);
      expect(map.extent!.east, -78.8);
    });

    test('a tile URL does not claim to know where its coverage stops', () {
      const map = TileMap(
        id: '1',
        name: 'Tiles',
        credit: '',
        template: 'https://host/{z}/{x}/{y}.png',
      );
      expect(map.extent, isNull);
    });
  });

  group('what gets written down', () {
    test('a tile map survives a round trip', () {
      const original = TileMap(
        id: 'abc',
        name: 'Provincial topo',
        credit: 'Someone',
        template: 'https://host/{z}/{x}/{y}.png',
        visible: false,
        opacity: 0.6,
        maxZoom: 16,
      );
      final restored = decodeCustomMaps(encodeCustomMaps([original])).single;
      expect(restored, isA<TileMap>());
      final tiles = restored as TileMap;
      expect(tiles.id, 'abc');
      expect(tiles.name, 'Provincial topo');
      expect(tiles.credit, 'Someone');
      expect(tiles.template, 'https://host/{z}/{x}/{y}.png');
      expect(tiles.visible, isFalse);
      expect(tiles.opacity, 0.6);
      expect(tiles.maxZoom, 16);
    });

    test('an imported map survives a round trip with its overlays', () {
      final original = FileMap(
        id: 'def',
        name: 'Algonquin',
        credit: 'Toporama',
        opacity: 0.8,
        overlays: readCustomMapKml(kml(overlay())).overlays,
      );
      final restored =
          decodeCustomMaps(encodeCustomMaps([original])).single as FileMap;
      expect(restored.name, 'Algonquin');
      expect(restored.opacity, 0.8);
      expect(restored.overlays.single.href, 'tiles/r0c0.jpg');
      expect(restored.overlays.single.box.north, 45.6);
    });

    test('a rubbish entry is dropped rather than failing the whole list', () {
      // The shape of a downgrade: a build that does not know a kind should lose
      // that one row, not everything the user added.
      final maps = decodeCustomMaps(
        '[{"kind":"spaceship"},'
        '{"kind":"tiles","id":"a","template":"https://h/{z}/{x}/{y}.png"}]',
      );
      expect(maps, hasLength(1));
      expect(maps.single.id, 'a');
    });

    test('unreadable storage is an empty list, not an exception', () {
      expect(decodeCustomMaps('not json'), isEmpty);
      expect(decodeCustomMaps(null), isEmpty);
      expect(decodeCustomMaps(''), isEmpty);
    });
  });
}
