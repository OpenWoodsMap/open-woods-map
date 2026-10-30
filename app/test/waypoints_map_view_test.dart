import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:open_woods_map/map/custom_map.dart';
import 'package:open_woods_map/settings/visibility_settings.dart';
import 'package:open_woods_map/waypoints/bulk_edit.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';
import 'package:open_woods_map/waypoints/waypoints_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Documents extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Documents(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

const _view = GeoBox(north: 45.6, south: 45.4, east: -77.4, west: -77.6);

Waypoint _point(
  String id,
  String name, {
  double latitude = 45.5,
  double longitude = -77.5,
  List<String> tags = const [],
}) => Waypoint(
  id: id,
  name: name,
  latitude: latitude,
  longitude: longitude,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 30),
  tags: tags,
);

Waypoint _track(String id, String name, List<(double, double)> points) =>
    Waypoint(
      id: id,
      name: name,
      latitude: points.first.$1,
      longitude: points.first.$2,
      notes: '',
      createdAt: DateTime.utc(2026, 10, 30),
      track: [
        for (final (latitude, longitude) in points)
          TrackPoint(latitude: latitude, longitude: longitude),
      ],
    );

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('owm-waypoints-map-view');
    PathProviderPlatform.instance = _Documents(root.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to reap with the rest of the temp directory.
    }
  });

  /// See waypoints_page_test.dart: the store reads a real file and the loading
  /// spinner never settles, so this pumps in real time rather than settling.
  Future<void> settle(WidgetTester tester) async {
    for (var turn = 0; turn < 8; turn++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<WaypointStore> pumpPage(
    WidgetTester tester,
    List<Waypoint> items, {
    VisibilitySettings? visibility,
    GeoBox? mapView = _view,
    bool startInMapView = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = WaypointStore();
    await tester.runAsync(() async {
      await store.load();
      await store.replaceAll(items);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WaypointsPage(
          store: store,
          suggestedLocation: const LatLng(45, -77),
          visibility: visibility ?? VisibilitySettings(),
          mapView: mapView,
          startInMapView: startInMapView,
        ),
      ),
    );
    await settle(tester);
    return store;
  }

  group('in map view', () {
    testWidgets('shows what the map drew on screen and nothing else', (
      tester,
    ) async {
      final visibility = VisibilitySettings();
      await tester.runAsync(
        () => visibility.setItemHidden('hidden', hidden: true),
      );
      await pumpPage(tester, [
        _point('here', 'Stand on the ridge'),
        _point('away', 'Camp road', latitude: 46.2),
        _point('hidden', 'Old blind'),
        _track('crossing', 'Walk in', [(45.5, -77.9), (45.5, -77.1)]),
      ], visibility: visibility);

      expect(find.text('Stand on the ridge'), findsOneWidget);
      expect(find.text('Walk in'), findsOneWidget);
      expect(find.text('Camp road'), findsNothing);
      expect(find.text('Old blind'), findsNothing);
      expect(find.text('In map view 2'), findsOneWidget);
    });

    testWidgets('is a chip, off, when the list is opened the usual way', (
      tester,
    ) async {
      await pumpPage(tester, [
        _point('here', 'Stand on the ridge'),
        _point('away', 'Camp road', latitude: 46.2),
      ], startInMapView: false);

      expect(find.text('Camp road'), findsOneWidget);
      await tester.tap(find.text('In map view 1'));
      await settle(tester);
      expect(find.text('Camp road'), findsNothing);
      expect(find.text('Stand on the ridge'), findsOneWidget);
    });

    testWidgets('is not offered when the map had not drawn', (tester) async {
      await pumpPage(tester, [
        _point('here', 'Stand on the ridge'),
      ], mapView: null);

      expect(find.textContaining('In map view'), findsNothing);
      expect(find.text('Stand on the ridge'), findsOneWidget);
    });

    // Hidden is the one thing an item in view can be that keeps it off the
    // screen, so the two filters can never both match.
    testWidgets('and hidden from map let go of each other', (tester) async {
      final visibility = VisibilitySettings();
      await tester.runAsync(
        () => visibility.setItemHidden('hidden', hidden: true),
      );
      await pumpPage(tester, [
        _point('here', 'Stand on the ridge'),
        _point('hidden', 'Old blind'),
      ], visibility: visibility);

      await tester.tap(find.text('Hidden from map 1'));
      await settle(tester);
      expect(find.text('Old blind'), findsOneWidget);
      expect(find.text('Stand on the ridge'), findsNothing);
    });

    testWidgets('says what is filtering when nothing is left', (tester) async {
      await pumpPage(tester, [
        _point('here', 'Stand on the ridge', tags: ['ridge']),
        _point('away', 'Camp road', latitude: 46.2),
      ]);

      await tester.tap(find.text('Untagged 1'));
      await settle(tester);

      expect(
        find.text('Nothing is drawn in the map view and untagged.'),
        findsOneWidget,
      );
      expect(find.text('Show everything'), findsOneWidget);
    });

    // The point of the feature: a day's marks, tagged in one go, and nothing
    // outside the view touched.
    testWidgets('a tag added to what is shown reaches only those', (
      tester,
    ) async {
      final store = await pumpPage(tester, [
        _point('here', 'Stand on the ridge'),
        _track('walk', 'Walk in', [(45.45, -77.55), (45.5, -77.5)]),
        _point('away', 'Camp road', latitude: 46.2),
      ]);

      await tester.tap(find.byTooltip('Actions for the whole list'));
      await settle(tester);
      await tester.tap(find.text('Edit the 2 shown…'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Optional. Existing tags are kept.'),
        'Opening day',
      );
      await settle(tester);
      await tester.tap(find.text('Apply'));
      await settle(tester);

      final tags = {for (final item in store.items) item.id: item.tags};
      expect(tags['here'], ['opening day']);
      expect(tags['walk'], ['opening day']);
      expect(tags['away'], isEmpty);
    });
  });

  group('untagged', () {
    testWidgets('narrows to items with no tag', (tester) async {
      await pumpPage(tester, [
        _point('tagged', 'Stand on the ridge', tags: ['ridge']),
        _point('bare', 'Imported 14'),
      ], startInMapView: false);

      await tester.tap(find.text('Untagged 1'));
      await settle(tester);

      expect(find.text('Imported 14'), findsOneWidget);
      expect(find.text('Stand on the ridge'), findsNothing);
    });

    testWidgets('and a picked tag let go of each other', (tester) async {
      await pumpPage(tester, [
        _point('tagged', 'Stand on the ridge', tags: ['ridge']),
        _point('bare', 'Imported 14'),
      ], startInMapView: false);

      await tester.tap(find.text('Untagged 1'));
      await settle(tester);
      await tester.tap(find.text('ridge 1'));
      await settle(tester);

      expect(find.text('Stand on the ridge'), findsOneWidget);
      expect(find.text('Imported 14'), findsNothing);
    });
  });

  group('tag suggestions', () {
    test('offer the most used tags when nothing is typed', () {
      expect(tagSuggestions({'ridge': 2, 'hunt-2026': 9, 'creek': 2}, ''), [
        'hunt-2026',
        'creek',
        'ridge',
      ]);
    });

    test('narrow to what is typed, in the form a tag is stored', () {
      expect(tagSuggestions({'hunt-2026': 9, 'ridge': 2}, ' Hunt'), [
        'hunt-2026',
      ]);
    });

    test('drop the tag already typed in full', () {
      expect(tagSuggestions({'ridge': 2, 'ridge top': 1}, 'ridge'), [
        'ridge top',
      ]);
    });

    testWidgets('fill the tag box when tapped', (tester) async {
      await pumpPage(tester, [
        _point('one', 'Stand on the ridge', tags: ['hunt-2026']),
        _point('two', 'Imported 14'),
      ], startInMapView: false);

      await tester.tap(find.byTooltip('Actions for the whole list'));
      await settle(tester);
      await tester.tap(find.text('Edit all 2…'));
      await settle(tester);
      await tester.tap(find.byTooltip('Use the existing tag "hunt-2026"'));
      await settle(tester);

      expect(find.text('Changes 1 waypoint.'), findsOneWidget);
    });
  });
}
