import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/custom_map.dart';
import 'package:open_woods_map/map/custom_map_panel.dart';
import 'package:open_woods_map/map/custom_map_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_map_store_test.dart' show jpegish, kmlFor, kmz;

class _Documents extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Documents(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late Directory root;
  late CustomMapStore store;
  late List<GeoBox> framed;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('owm-custom-map-panel');
    PathProviderPlatform.instance = _Documents(root.path);
    SharedPreferences.setMockInitialValues({});
    store = CustomMapStore();
    await store.loadPreferences();
    framed = [];
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // See custom_map_store_test.dart: a pending write can hold a file open on
      // Windows, and failing the teardown would hide the test's own result.
    }
  });

  Future<void> pump(
    WidgetTester tester, {
    CustomMapPicker? picker,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomMapPanel(
            store: store,
            picker: picker,
            onShow: framed.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lets real file work finish. `pumpAndSettle` does not advance actual disk
  /// I/O inside a widget test's fake async zone, so an import started by a tap
  /// never completes without this.
  Future<void> settle(WidgetTester tester, {Finder? until}) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
      if (until != null && until.evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  CustomMapPicker pickerFor(Uint8List bytes, {String name = 'algonquin.kmz'}) =>
      () async => (name: name, bytes: bytes);

  testWidgets('with nothing added it says which kind works offline',
      (tester) async {
    await pump(tester);
    expect(find.text('My maps'), findsOneWidget);
    expect(
      find.textContaining('imported map file works with no signal'),
      findsOneWidget,
    );
  });

  testWidgets('an imported map is listed with its credit and image count',
      (tester) async {
    await pump(tester, picker: pickerFor(kmz()));
    await tester.tap(find.text('Import a map file'));
    await settle(tester, until: find.text('OK'));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Algonquin west'), findsOneWidget);
    expect(
      find.textContaining('Toporama, Natural Resources Canada'),
      findsOneWidget,
    );
    expect(find.textContaining('works offline'), findsOneWidget);
  });

  testWidgets('an import frames the map on where it landed', (tester) async {
    // The first question about an imported map is whether it went where it was
    // supposed to, and a row in a list does not answer it.
    await pump(tester, picker: pickerFor(kmz()));
    await tester.tap(find.text('Import a map file'));
    await settle(tester, until: find.text('OK'));

    expect(framed, hasLength(1));
    expect(framed.single.north, 45.6);
  });

  testWidgets('a partial import says how many images are missing',
      (tester) async {
    await pump(
      tester,
      picker: pickerFor(
        kmz(
          images: {'a.jpg': jpegish('a')},
          kml: kmlFor(const ['a.jpg', 'b.jpg', 'c.jpg']),
        ),
      ),
    );
    await tester.tap(find.text('Import a map file'));
    await settle(tester, until: find.text('OK'));

    expect(find.textContaining('1 of the 3 images'), findsOneWidget);
    expect(find.textContaining('will be missing'), findsOneWidget);
  });

  testWidgets('a rotated map is refused with the reason on screen',
      (tester) async {
    await pump(
      tester,
      picker: pickerFor(
        kmz(
          images: {'a.jpg': jpegish('a')},
          kml: kmlFor(const ['a.jpg'])
              .replaceAll('</LatLonBox>', '<rotation>15</rotation></LatLonBox>'),
        ),
      ),
    );
    await tester.tap(find.text('Import a map file'));
    await settle(tester, until: find.text('OK'));

    expect(find.text('That file could not be used'), findsOneWidget);
    expect(find.textContaining('rotated'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(store.maps, isEmpty);
  });

  testWidgets('backing out of the picker adds nothing and says nothing',
      (tester) async {
    await pump(tester, picker: () async => null);
    await tester.tap(find.text('Import a map file'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(store.maps, isEmpty);
  });

  group('adding a tile URL', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Add a tile URL'));
      await tester.pumpAndSettle();
    }

    testWidgets('the Add button stays dead until the URL could work',
        (tester) async {
      await pump(tester);
      await openDialog(tester);

      FilledButton add() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add'),
          );
      expect(add().onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Tile URL'),
        'https://host/tiles.png',
      );
      await tester.pumpAndSettle();
      expect(add().onPressed, isNull);
      expect(find.textContaining('the same picture'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Tile URL'),
        'https://host/{z}/{x}/{y}.png',
      );
      await tester.pumpAndSettle();
      expect(add().onPressed, isNotNull);
    });

    testWidgets('the dialog says out loud that tiles need a connection',
        (tester) async {
      await pump(tester);
      await openDialog(tester);
      expect(find.textContaining('needs a connection'), findsOneWidget);
      expect(find.textContaining('offline area does not include it'),
          findsOneWidget);
    });

    testWidgets('a good URL is added and listed as needing network',
        (tester) async {
      await pump(tester);
      await openDialog(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Provincial topo',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Tile URL'),
        'https://host/{Z}/{X}/{Y}.png',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester, until: find.text('Provincial topo'));

      expect(store.maps, hasLength(1));
      expect((store.maps.single as TileMap).template,
          'https://host/{z}/{x}/{y}.png');
      expect(find.textContaining('needs network'), findsOneWidget);
    });
  });

  testWidgets('the newest map is listed first, as the copy promises',
      (tester) async {
    await store.addTiles(
      name: 'Older',
      template: 'https://a/{z}/{x}/{y}.png',
      credit: '',
    );
    await store.addTiles(
      name: 'Newer',
      template: 'https://b/{z}/{x}/{y}.png',
      credit: '',
    );
    await pump(tester);

    // The panel says the higher map wins, and map_shell stacks the store's
    // order with the last one on top. Reversing the rows is what joins those
    // two, so an order flip in either place has to fail here.
    final first = tester.getTopLeft(find.text('Newer')).dy;
    final second = tester.getTopLeft(find.text('Older')).dy;
    expect(first, lessThan(second));
    expect(store.maps.last.name, 'Newer');
  });

  group('an added map', () {
    setUp(() async {
      await store.addTiles(
        name: 'Provincial topo',
        template: 'https://host/{z}/{x}/{y}.png',
        credit: 'Someone',
      );
    });

    testWidgets('can be switched off without being removed', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(Checkbox));
      await settle(tester);

      expect(store.maps, hasLength(1));
      expect(store.maps.single.visible, isFalse);
      expect(store.drawn, isEmpty);
    });

    testWidgets('has no opacity slider while it is switched off',
        (tester) async {
      // Nothing to fade, and a live slider over a hidden layer invites the
      // conclusion that the fading is why nothing is showing.
      await store.setVisible(store.maps.single.id, false);
      await pump(tester);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('cannot be faded all the way to invisible', (tester) async {
      await pump(tester);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, greaterThan(0));
    });

    testWidgets('is only removed after the warning is confirmed',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Provincial topo?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(store.maps, hasLength(1));

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await settle(tester);
      expect(store.maps, isEmpty);
    });

    testWidgets('a tile map offers no go-to, because it claims no coverage',
        (tester) async {
      await pump(tester);
      expect(find.byTooltip('Go to it'), findsNothing);
    });
  });
}
