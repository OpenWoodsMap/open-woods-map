import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:open_woods_map/settings/visibility_settings.dart';
import 'package:open_woods_map/waypoints/waypoint_icon.dart';
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

Waypoint _point(
  String id,
  String name, {
  WaypointIcon icon = WaypointIcon.pin,
  List<String> tags = const [],
}) => Waypoint(
  id: id,
  name: name,
  latitude: 45.5,
  longitude: -77.5,
  notes: '',
  createdAt: DateTime.utc(2026, 9, 10),
  icon: icon,
  tags: tags,
);

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('owm-waypoints-search');
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
  /// Pumps the tree while letting the store's real file writes run. See the
  /// same helper in `waypoints_page_test.dart` for why [until] exists: deleting
  /// shows its message only after the write returns, and no fixed duration is
  /// both long enough for a loaded runner's disk and short enough to leave the
  /// SnackBar still on screen.
  Future<void> settle(WidgetTester tester, {Finder? until}) async {
    for (var turn = 0; turn < 40; turn++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump(const Duration(milliseconds: 120));
      if (until == null) {
        if (turn >= 7) return;
      } else if (until.evaluate().isNotEmpty) {
        // Present is not yet tappable: the SnackBar is still sliding in.
        for (var settling = 0; settling < 4; settling++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        return;
      }
    }
  }

  Future<WaypointStore> pumpPage(
    WidgetTester tester,
    List<Waypoint> items,
  ) async {
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
          visibility: VisibilitySettings(),
        ),
      ),
    );
    await settle(tester);
    return store;
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await settle(tester);
  }

  // The report: finding anything meant side-scrolling a single row of tag chips,
  // and a name could not be searched for at all.
  group('searching', () {
    testWidgets('matches a name', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand'),
        _point('2', 'Gariepy creek'),
      ]);

      await search(tester, 'bonn');

      expect(find.text('Bonnechere stand'), findsOneWidget);
      expect(find.text('Gariepy creek'), findsNothing);
    });

    testWidgets('matches a tag on an item whose name does not', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand', tags: ['grouse']),
        _point('2', 'Gariepy creek'),
      ]);

      await search(tester, 'grouse');

      expect(find.text('Bonnechere stand'), findsOneWidget);
      expect(find.text('Gariepy creek'), findsNothing);
    });

    // The icon picker stopped printing names beside the glyphs, so the name has
    // to be findable somewhere. This is where.
    testWidgets('matches the name of the glyph', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand', icon: WaypointIcon.stand),
        _point('2', 'Gariepy creek', icon: WaypointIcon.water),
      ]);

      await search(tester, 'tree stand');

      expect(find.text('Bonnechere stand'), findsOneWidget);
      expect(find.text('Gariepy creek'), findsNothing);
    });

    // The bug this design nearly shipped with: sections were keyed off "is
    // anything filtering" rather than "are tags picked", so a search on its own
    // dropped every tag section and showed the untagged group alone.
    testWidgets('still sections by the tags the results carry', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand', tags: ['ridge']),
        _point('2', 'Gariepy creek', tags: ['creek']),
      ]);

      await search(tester, 'bonn');

      expect(find.text('ridge · 1'), findsOneWidget);
      expect(find.text('creek · 1'), findsNothing);
    });
  });

  // "A search bar to help find the tag to filter on" was the ask, so the search
  // narrows the chips as well as the list.
  group('the search narrows the tag chips', () {
    testWidgets('to the tags it matches', (tester) async {
      await pumpPage(tester, [
        _point('1', 'North stand', tags: ['ridge']),
        _point('2', 'South stand', tags: ['creek']),
      ]);
      expect(find.text('ridge 1'), findsOneWidget);
      expect(find.text('creek 1'), findsOneWidget);

      await search(tester, 'rid');

      expect(find.text('ridge 1'), findsOneWidget);
      expect(find.text('creek 1'), findsNothing);
    });

    // A filter in force with nothing on screen to switch it off is the failure
    // this page can least afford, because the result looks like missing data.
    testWidgets('but never hides a tag being filtered on', (tester) async {
      await pumpPage(tester, [
        _point('1', 'North stand', tags: ['ridge']),
        _point('2', 'Gariepy creek', tags: ['creek']),
      ]);

      await tester.tap(find.text('creek 1'));
      await settle(tester);
      await search(tester, 'rid');

      expect(find.text('creek 1'), findsOneWidget);
    });

    testWidgets('and says so when no tag matches', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand', tags: ['ridge']),
      ]);

      await search(tester, 'bonn');

      expect(find.text('No tag matches this search'), findsOneWidget);
    });
  });

  group('more tags than fit', () {
    List<Waypoint> manyTags() => [
      for (var i = 0; i < 8; i++)
        _point('$i', 'Stand $i', tags: ['tag${i + 1}']),
    ];

    testWidgets('the rest go behind one chip', (tester) async {
      await pumpPage(tester, manyTags());

      expect(find.text('tag1 1'), findsOneWidget);
      expect(find.text('tag6 1'), findsOneWidget);
      expect(find.text('tag7 1'), findsNothing);
      expect(find.text('2 more'), findsOneWidget);
    });

    testWidgets('tapping it shows them, and Fewer puts them back', (
      tester,
    ) async {
      await pumpPage(tester, manyTags());

      await tester.tap(find.text('2 more'));
      await settle(tester);
      expect(find.text('tag8 1'), findsOneWidget);

      await tester.tap(find.text('Fewer'));
      await settle(tester);
      expect(find.text('tag8 1'), findsNothing);
    });

    testWidgets('a tag being filtered on is shown even past the cap', (
      tester,
    ) async {
      await pumpPage(tester, manyTags());

      await tester.tap(find.text('2 more'));
      await settle(tester);
      await tester.tap(find.text('tag8 1'));
      await settle(tester);
      await tester.tap(find.text('Fewer'));
      await settle(tester);

      expect(find.text('tag8 1'), findsOneWidget);
    });
  });

  // The one screen where an empty list can read as lost data.
  group('when nothing matches', () {
    testWidgets('it names the search and what is still saved', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand'),
        _point('2', 'Gariepy creek'),
      ]);

      await search(tester, 'Moose');

      // Quoted as typed rather than in the lowered form matching runs on.
      expect(find.text('Nothing matches "Moose".'), findsOneWidget);
      expect(find.text('Still saved: 2 waypoints.'), findsOneWidget);
    });

    testWidgets('naming both when a tag is picked too', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand', tags: ['ridge']),
      ]);

      await tester.tap(find.text('ridge 1'));
      await settle(tester);
      await search(tester, 'Moose');

      expect(
        find.text('Nothing matching "Moose" carries any of ridge.'),
        findsOneWidget,
      );
    });

    testWidgets('Show everything clears the search and the tags', (
      tester,
    ) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand', tags: ['ridge']),
      ]);

      await tester.tap(find.text('ridge 1'));
      await settle(tester);
      await search(tester, 'Moose');
      await tester.tap(find.text('Show everything'));
      await settle(tester);

      expect(find.text('Bonnechere stand'), findsOneWidget);
      expect(find.text('ridge 1'), findsOneWidget);
    });
  });

  // The chip means "show me everything", so leaving a search running under it
  // would make it lie.
  testWidgets('All clears the search as well', (tester) async {
    await pumpPage(tester, [
      _point('1', 'Bonnechere stand'),
      _point('2', 'Gariepy creek'),
    ]);

    await search(tester, 'bonn');
    expect(find.text('Gariepy creek'), findsNothing);

    await tester.tap(find.text('All 2'));
    await settle(tester);

    expect(find.text('Gariepy creek'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty);
  });

  // The gap this closes: an imported file lands as a pile of untagged items, and
  // before this the only way to remove them was one row at a time. Scoped to
  // what is shown rather than to a tag, because "what is shown" is the one
  // description that can name a set with no tag in common.
  group('deleting what is shown', () {
    Future<void> deleteShown(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Actions for the whole list'));
      await settle(tester);
      await tester.tap(find.textContaining('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete them'));
      // Until the undo appears, because it is only offered once the store's
      // write has returned. A fixed wait let a slow disk report the items as
      // still there.
      await settle(tester, until: find.text('UNDO'));
    }

    testWidgets('a search deletes its results and leaves the rest', (
      tester,
    ) async {
      final store = await pumpPage(tester, [
        _point('1', 'Bonnechere stand'),
        _point('2', 'Bonnechere creek'),
        _point('3', 'Gariepy creek'),
      ]);

      await search(tester, 'bonn');
      await deleteShown(tester);

      expect(store.items.map((item) => item.name), ['Gariepy creek']);
    });

    // The same action, on the same set, has to be able to say it is about to
    // empty the list. A count cannot: 3 of 3 reads exactly like 3 of 300 to
    // someone who has not counted the rest.
    testWidgets('unfiltered, it says it is deleting everything', (tester) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand'),
        _point('2', 'Gariepy creek'),
      ]);

      await tester.tap(find.byTooltip('Actions for the whole list'));
      await settle(tester);

      expect(find.text('Delete all 2…'), findsOneWidget);
      await tester.tap(find.text('Delete all 2…'));
      await settle(tester);

      expect(find.text('Delete everything? All 2 waypoints.'), findsOneWidget);
      expect(find.textContaining('Nothing will be left'), findsOneWidget);
    });

    testWidgets('filtered, it says it is only deleting the shown', (
      tester,
    ) async {
      await pumpPage(tester, [
        _point('1', 'Bonnechere stand'),
        _point('2', 'Gariepy creek'),
      ]);

      await search(tester, 'bonn');
      await tester.tap(find.byTooltip('Actions for the whole list'));
      await settle(tester);

      expect(find.text('Delete the 1 shown…'), findsOneWidget);
      await tester.tap(find.text('Delete the 1 shown…'));
      await settle(tester);

      expect(find.text('Delete the 1 waypoint shown?'), findsOneWidget);
      expect(find.textContaining('Everything they are hiding stays'),
          findsOneWidget);
    });

    // A confirmation is something people dismiss on reflex, which is the whole
    // reason the undo exists as well.
    testWidgets('cancelling deletes nothing', (tester) async {
      final store = await pumpPage(tester, [
        _point('1', 'Bonnechere stand'),
        _point('2', 'Gariepy creek'),
      ]);

      await tester.tap(find.byTooltip('Actions for the whole list'));
      await settle(tester);
      await tester.tap(find.textContaining('Delete all'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(store.items, hasLength(2));
    });

    testWidgets('what it deleted can be undone', (tester) async {
      final store = await pumpPage(tester, [
        _point('1', 'Bonnechere stand'),
        _point('2', 'Gariepy creek'),
      ]);

      await deleteShown(tester);
      expect(store.items, isEmpty);

      await tester.tap(find.text('UNDO'));
      await settle(tester);

      expect(
        store.items.map((item) => item.name),
        ['Bonnechere stand', 'Gariepy creek'],
      );
    });

    // A search matching nothing must not offer to delete nothing, or the menu
    // reads as though it is about to do something.
    testWidgets('a search matching nothing offers no delete', (tester) async {
      await pumpPage(tester, [_point('1', 'Bonnechere stand')]);

      await search(tester, 'nothing matches this');
      await tester.tap(find.byTooltip('Actions for the whole list'));
      await settle(tester);

      final item = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Delete the 0 shown…'),
      );
      expect(item.enabled, isFalse);
    });
  });
}
