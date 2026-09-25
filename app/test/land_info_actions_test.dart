import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/data/models.dart';
import 'package:open_woods_map/data/province_loader.dart';
import 'package:open_woods_map/map/land_info.dart';
import 'package:open_woods_map/map/land_info_sheet.dart';

const _manifest = ProvinceManifest(
  id: 'on',
  name: 'Ontario',
  version: 'test',
  license: 'Open Government Licence – Ontario',
  licenseUrl: 'https://example.invalid/licence',
  layers: [],
);

void main() {
  /// Opens the sheet on an empty point, which is the ordinary case: most taps
  /// land on ground no bundled polygon covers.
  Future<int> pumpSheet(
    WidgetTester tester, {
    required bool offerSave,
  }) async {
    var saves = 0;
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showLandInfoSheet(
      ctx,
      info: const LandInfo(
        latitude: 45.0,
        longitude: -79.0,
        hits: [],
        attribution: 'test',
      ),
      provinceId: 'on',
      loader: ProvinceLoader(),
      manifest: _manifest,
      onSaveWaypoint: offerSave ? () => saves++ : null,
    );
    await tester.pumpAndSettle();
    return saves;
  }

  testWidgets('offers to save a waypoint at the spot that was asked about',
      (tester) async {
    await pumpSheet(tester, offerSave: true);
    expect(find.text('Save a waypoint here'), findsOneWidget);
  });

  testWidgets('closes before saving, so the editor is not buried under it',
      (tester) async {
    // Two sheets deep is how the editor ends up unreachable behind Land Info's
    // 88%-height sheet, which is tall enough to hide a sheet opened over it.
    await pumpSheet(tester, offerSave: true);
    await tester.tap(find.text('Save a waypoint here'));
    await tester.pumpAndSettle();
    expect(find.text('LAND INFO'), findsNothing);
  });

  group('handing the card to an AI', () {
    Finder sheetScroller() => find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> tapInSheet(WidgetTester tester, String label) async {
      final target = find.text(label);
      await tester.scrollUntilVisible(target, 300, scrollable: sheetScroller());
      // scrollUntilVisible stops as soon as the widget is in the tree, which
      // can leave it below the viewport and unhittable. ensureVisible finishes
      // the job.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the prompts folded until asked', (tester) async {
      await pumpSheet(tester, offerSave: false);
      await tester.scrollUntilVisible(
        find.text('ASK AN AI'),
        300,
        scrollable: sheetScroller(),
      );
      expect(find.textContaining('Nothing is sent from this app'),
          findsOneWidget);
      expect(find.text('Copy just the facts'), findsNothing);
      expect(find.textContaining('An AI does not know the law'), findsNothing);
    });

    testWidgets('offers the three prompts and the facts on their own',
        (tester) async {
      await pumpSheet(tester, offerSave: false);
      await tapInSheet(tester, 'Show the prompts');
      expect(find.textContaining('An AI does not know the law'), findsOneWidget);
      for (final label in [
        'Explain these records',
        'Draft an email to the authority',
        'Get a second opinion (experimental)',
        'Copy just the facts',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('copying puts the prompt on the clipboard', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpSheet(tester, offerSave: false);
      await tapInSheet(tester, 'Show the prompts');
      await tapInSheet(tester, 'Copy just the facts');
      expect(copied, hasLength(1));
      expect(copied.single, contains('45.000000, -79.000000'));
    });

    // The bug this guards is invisible rather than broken: the app's own
    // messenger lives above the Navigator, so a message raised from inside this
    // modal sheet painted underneath it. The copy worked and the button looked
    // dead. Finding the message under the sheet is what proves the sheet has a
    // messenger of its own; findsOneWidget alone would pass either way.
    testWidgets('and says so where the sheet can be seen', (tester) async {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpSheet(tester, offerSave: false);
      await tapInSheet(tester, 'Show the prompts');
      await tapInSheet(tester, 'Copy just the facts');
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(SnackBar),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('asks once', (tester) async {
    var saves = 0;
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showLandInfoSheet(
      ctx,
      info: const LandInfo(
        latitude: 45.0,
        longitude: -79.0,
        hits: [],
        attribution: 'test',
      ),
      provinceId: 'on',
      loader: ProvinceLoader(),
      manifest: _manifest,
      onSaveWaypoint: () => saves++,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a waypoint here'));
    await tester.pumpAndSettle();
    expect(saves, 1);
  });

  testWidgets('says nothing about waypoints when nobody can save one',
      (tester) async {
    // The sheet is also opened from places with no map to put a waypoint on, and
    // offering an action that cannot happen is worse than not offering it.
    await pumpSheet(tester, offerSave: false);
    expect(find.text('LAND INFO'), findsOneWidget);
    expect(find.text('Save a waypoint here'), findsNothing);
  });
}
