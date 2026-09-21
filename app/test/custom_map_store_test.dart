import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/custom_map.dart';
import 'package:open_woods_map/map/custom_map_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Documents extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Documents(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Stand-in image bytes. Nothing in the store decodes them — MapLibre does that
/// on the platform side — so what matters is that the right bytes reach the right
/// file.
Uint8List jpegish(String marker) =>
    Uint8List.fromList([0xFF, 0xD8, ...marker.codeUnits, 0xFF, 0xD9]);

String kmlFor(Iterable<String> hrefs, {String name = 'Algonquin west'}) => '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
  <name>$name</name>
  <description>Toporama, Natural Resources Canada</description>
  ${hrefs.indexed.map((entry) => '''
  <GroundOverlay>
    <drawOrder>${50 + entry.$1}</drawOrder>
    <Icon><href>${entry.$2}</href></Icon>
    <LatLonBox>
      <north>45.6</north><south>45.5</south>
      <east>${-78.8 + (entry.$1 + 1) * 0.1}</east>
      <west>${-78.8 + entry.$1 * 0.1}</west>
    </LatLonBox>
  </GroundOverlay>
''').join()}
</Document>
</kml>
''';

/// Builds a KMZ the way Garmin and Google Earth do: a doc.kml plus its images.
Uint8List kmz({
  Map<String, Uint8List>? images,
  String? kml,
  bool includeKml = true,
}) {
  final tiles = images ?? {'tiles/r0c0.jpg': jpegish('a')};
  final archive = Archive();
  if (includeKml) {
    final text = kml ?? kmlFor(tiles.keys);
    archive.addFile(
      ArchiveFile('doc.kml', text.length, text.codeUnits),
    );
  }
  for (final entry in tiles.entries) {
    archive.addFile(
      ArchiveFile(entry.key, entry.value.length, entry.value),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  late Directory root;
  late CustomMapStore store;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('owm-custom-maps');
    PathProviderPlatform.instance = _Documents(root.path);
    SharedPreferences.setMockInitialValues({});
    store = CustomMapStore();
    await store.loadPreferences();
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort: on Windows a write the store started may still hold a file,
      // and failing the teardown would hide the result of the test itself.
    }
  });

  Directory mapDir(String id) =>
      Directory(p.join(root.path, 'custom_maps', id));

  group('importing a KMZ', () {
    test('the images land on disk and the overlays are remembered', () async {
      final result = await store.importArchive(
        kmz(
          images: {
            'tiles/r0c0.jpg': jpegish('left'),
            'tiles/r0c1.jpg': jpegish('right'),
          },
        ),
        fileName: 'algonquin.kmz',
      );

      expect(result.isComplete, isTrue);
      expect(result.kept, 2);
      expect(store.maps, hasLength(1));

      final map = result.map;
      expect(map.name, 'Algonquin west');
      expect(map.credit, 'Toporama, Natural Resources Canada');
      expect(map.overlays, hasLength(2));

      expect(
        File(p.join(mapDir(map.id).path, 'tiles', 'r0c0.jpg')).existsSync(),
        isTrue,
      );
      expect(
        await store.imageBytes(map.id, 'tiles/r0c1.jpg'),
        jpegish('right'),
      );
    });

    test('the document name wins over the file name', () async {
      final result = await store.importArchive(
        kmz(
          images: {'a.jpg': jpegish('a')},
          kml: kmlFor(const ['a.jpg'], name: 'Jeff-ish Algonquin'),
        ),
        fileName: 'some-download-3.kmz',
      );
      expect(result.map.name, 'Jeff-ish Algonquin');
    });

    test('a nameless document falls back to a tidied file name', () async {
      final result = await store.importArchive(
        kmz(
          images: {'a.jpg': jpegish('a')},
          kml: kmlFor(const ['a.jpg'], name: ''),
        ),
        fileName: 'algonquin_canoe-lake.kmz',
      );
      expect(result.map.name, 'algonquin canoe lake');
    });

    test('the credit never ends up blank, so the app never looks like the author',
        () async {
      final result = await store.importArchive(
        kmz(
          images: {'a.jpg': jpegish('a')},
          kml: kmlFor(const ['a.jpg']).replaceAll(
            RegExp(r'<description>.*</description>'),
            '',
          ),
        ),
        fileName: 'mystery.kmz',
      );
      expect(result.map.credit, contains('mystery.kmz'));
    });

    test('hrefs are matched whatever their case', () async {
      // A KMZ written by hand routinely disagrees with itself about case, and on
      // a phone that showed up as an import that worked and drew nothing.
      final result = await store.importArchive(
        kmz(
          images: {'Tiles/R0C0.JPG': jpegish('a')},
          kml: kmlFor(const ['tiles/r0c0.jpg']),
        ),
        fileName: 'mixed.kmz',
      );
      expect(result.kept, 1);
      expect(await store.imageBytes(result.map.id, 'tiles/r0c0.jpg'), isNotNull);
    });

    test('a missing image is reported rather than silently left out', () async {
      final result = await store.importArchive(
        kmz(
          images: {'tiles/r0c0.jpg': jpegish('a')},
          kml: kmlFor(const ['tiles/r0c0.jpg', 'tiles/r0c1.jpg']),
        ),
        fileName: 'partial.kmz',
      );
      expect(result.asked, 2);
      expect(result.kept, 1);
      expect(result.isComplete, isFalse);
    });

    test('a KMZ with no images at all is refused, and nothing is stored',
        () async {
      await expectLater(
        store.importArchive(
          kmz(images: const {}, kml: kmlFor(const ['gone.jpg'])),
          fileName: 'empty.kmz',
        ),
        throwsA(
          isA<CustomMapUnreadable>()
              .having((e) => e.message, 'message', contains('not inside it')),
        ),
      );
      expect(store.maps, isEmpty);
    });

    test('a zip with no KML says what is missing', () async {
      await expectLater(
        store.importArchive(kmz(includeKml: false), fileName: 'images.zip'),
        throwsA(
          isA<CustomMapUnreadable>()
              .having((e) => e.message, 'message', contains('no KML')),
        ),
      );
    });

    test('a plain KML rather than a KMZ is told what it is', () async {
      await expectLater(
        store.importArchive(
          Uint8List.fromList(kmlFor(const ['a.jpg']).codeUnits),
          fileName: 'doc.kml',
        ),
        throwsA(
          isA<CustomMapUnreadable>()
              .having((e) => e.message, 'message', contains('not a KMZ')),
        ),
      );
    });

    test('a refused file leaves no directory behind', () async {
      await expectLater(
        store.importArchive(
          // A box with no height. The image is present, so the only thing wrong
          // is the geometry, which is what this asserts is caught before any
          // file is written.
          kmz(
            images: {'a.jpg': jpegish('a')},
            kml: kmlFor(const ['a.jpg']).replaceAll('45.5', '45.6'),
          ),
          fileName: 'flat.kmz',
        ),
        throwsA(isA<CustomMapUnreadable>()),
      );
      expect(store.maps, isEmpty);
      final maps = Directory(p.join(root.path, 'custom_maps'));
      expect(
        maps.existsSync() ? maps.listSync() : const [],
        isEmpty,
      );
    });

    test('two imports in the same moment do not share a directory', () async {
      final first = await store.importArchive(kmz(), fileName: 'a.kmz');
      final second = await store.importArchive(kmz(), fileName: 'b.kmz');
      expect(first.map.id, isNot(second.map.id));
      expect(await store.imageBytes(first.map.id, 'tiles/r0c0.jpg'), isNotNull);
      expect(await store.imageBytes(second.map.id, 'tiles/r0c0.jpg'), isNotNull);
    });
  });

  group('tile URLs', () {
    test('a good one is stored with its placeholders normalised', () async {
      await store.addTiles(
        name: 'Provincial topo',
        template: 'https://host/{Z}/{X}/{Y}.png',
        credit: 'Someone',
      );
      final map = store.maps.single as TileMap;
      expect(map.template, 'https://host/{z}/{x}/{y}.png');
      expect(map.name, 'Provincial topo');
      expect(map.visible, isTrue);
    });

    test('a bad one is refused with the reason, and nothing is stored', () async {
      await expectLater(
        store.addTiles(name: 'Bad', template: 'https://host/tiles.png', credit: ''),
        throwsA(isA<CustomMapUnreadable>()),
      );
      expect(store.maps, isEmpty);
    });

    test('an unnamed one still has something to show in the list', () async {
      await store.addTiles(
        name: '   ',
        template: 'https://host/{z}/{x}/{y}.png',
        credit: '',
      );
      expect(store.maps.single.name, isNotEmpty);
    });
  });

  group('the list itself', () {
    test('it survives a restart', () async {
      await store.importArchive(kmz(), fileName: 'algonquin.kmz');
      await store.addTiles(
        name: 'Tiles',
        template: 'https://host/{z}/{x}/{y}.png',
        credit: '',
      );

      final reopened = CustomMapStore();
      await reopened.loadPreferences();
      expect(reopened.maps, hasLength(2));
      expect(reopened.maps.first, isA<FileMap>());
      expect(reopened.maps.last, isA<TileMap>());
    });

    test('hiding one keeps it in the list but out of what is drawn', () async {
      final result = await store.importArchive(kmz(), fileName: 'a.kmz');
      await store.setVisible(result.map.id, false);
      expect(store.maps, hasLength(1));
      expect(store.drawn, isEmpty);
    });

    test('opacity is remembered', () async {
      final result = await store.importArchive(kmz(), fileName: 'a.kmz');
      await store.setOpacity(result.map.id, 0.4);

      final reopened = CustomMapStore();
      await reopened.loadPreferences();
      expect(reopened.maps.single.opacity, 0.4);
    });

    test('removing one deletes its images', () async {
      final result = await store.importArchive(kmz(), fileName: 'a.kmz');
      final directory = mapDir(result.map.id);
      expect(directory.existsSync(), isTrue);

      await store.remove(result.map.id);
      expect(store.maps, isEmpty);
      expect(directory.existsSync(), isFalse);
    });

    test('removing one leaves the others alone', () async {
      final keep = await store.importArchive(kmz(), fileName: 'keep.kmz');
      final drop = await store.importArchive(kmz(), fileName: 'drop.kmz');
      await store.remove(drop.map.id);

      expect(store.maps.single.id, keep.map.id);
      expect(mapDir(keep.map.id).existsSync(), isTrue);
    });

    test('an empty list writes nothing, so it cannot pin a later default',
        () async {
      final result = await store.importArchive(kmz(), fileName: 'a.kmz');
      await store.remove(result.map.id);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_maps'), isNull);
    });

    test('the cap is enforced with a message rather than a slow map', () async {
      for (var i = 0; i < CustomMapStore.maxMaps; i++) {
        await store.addTiles(
          name: 'Map $i',
          template: 'https://host/$i/{z}/{x}/{y}.png',
          credit: '',
        );
      }
      await expectLater(
        store.addTiles(
          name: 'One too many',
          template: 'https://host/x/{z}/{x}/{y}.png',
          credit: '',
        ),
        throwsA(isA<CustomMapUnreadable>()),
      );
      expect(store.maps, hasLength(CustomMapStore.maxMaps));
    });

    test('bytes on disk are reported, because a bought map is not small',
        () async {
      final result = await store.importArchive(
        kmz(images: {'a.jpg': jpegish('x' * 500)}),
        fileName: 'a.kmz',
      );
      expect(await store.bytesOnDisk(result.map.id), greaterThan(500));
    });
  });
}
