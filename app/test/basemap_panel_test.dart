import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/basemap.dart';
import 'package:open_woods_map/map/basemap_panel.dart';

void main() {
  var myMapsTaps = 0;

  setUp(() => myMapsTaps = 0);

  Future<BasemapKind?> pumpPanel(
    WidgetTester tester,
    Size size, {
    int customCount = 0,
    int customDrawn = 0,
  }) async {
    BasemapKind? picked;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BasemapPanel(
            selected: BasemapKind.streets,
            onPick: (kind) => picked = kind,
            onMyMaps: () => myMapsTaps++,
            customCount: customCount,
            customDrawn: customDrawn,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picked;
  }

  // The panel is shown in a bottom sheet, so anything past the bottom edge is
  // unreachable unless the list scrolls. This is the case that broke: on a
  // landscape tablet Hybrid was in the list but below the fold, which reads as
  // the basemap simply not existing.
  testWidgets('every basemap is reachable on a short landscape screen',
      (tester) async {
    await pumpPanel(tester, const Size(1024, 575));

    for (final kind in BasemapKind.values) {
      await tester.scrollUntilVisible(find.text(kind.label), 120);
      expect(find.text(kind.label), findsOneWidget,
          reason: '${kind.label} should be reachable');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last basemap can be tapped on a short screen',
      (tester) async {
    BasemapKind? picked;
    tester.view.physicalSize = const Size(1024, 575);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BasemapPanel(
            selected: BasemapKind.streets,
            onPick: (kind) => picked = kind,
            onMyMaps: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final last = BasemapKind.values.last;
    await tester.scrollUntilVisible(find.text(last.label), 120);
    await tester.tap(find.text(last.label));
    await tester.pumpAndSettle();
    expect(picked, last);
  });

  testWidgets('the header stays put while the list scrolls', (tester) async {
    await pumpPanel(tester, const Size(1024, 575));

    final headerBefore = tester.getTopLeft(find.text('Basemap'));
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Basemap')), headerBefore);
  });

  // This panel is the only place the hints appear now. They used to be printed
  // permanently over the map as well, which was the same words about a basemap the
  // person had already picked. Removing that left one copy, and it is the copy
  // that has to survive: "needs network" is what explains a blank satellite view
  // out of signal, and it is only readable here.
  testWidgets('each basemap says what it is and what it needs', (tester) async {
    await pumpPanel(tester, const Size(1080, 2400));

    for (final kind in BasemapKind.values) {
      expect(find.text(kind.shortHint), findsOneWidget,
          reason: '${kind.label} should explain itself');
    }
    expect(
      find.textContaining('needs network'),
      findsNWidgets(
        BasemapKind.values
            .where((kind) => kind.shortHint.contains('needs network'))
            .length,
      ),
      reason: 'the basemaps that need a connection have to say so somewhere',
    );
  });

  testWidgets('a tall screen does not force a full-height sheet',
      (tester) async {
    await pumpPanel(tester, const Size(1080, 2400));

    final panel = tester.getSize(find.byType(BasemapPanel));
    expect(panel.height, lessThan(2400 * 0.85),
        reason: 'content should size the sheet when it fits');
  });

  // This sheet is where people look for what the picture under their data is,
  // which is why the door to their own maps is here and not in the overflow
  // menu. It is a door and not a fifth option: a basemap is one of four, and a
  // map you bring is one of any number with an opacity each.
  group('the door to My maps', () {
    testWidgets('is not offered as another basemap', (tester) async {
      await pumpPanel(tester, const Size(1080, 2400));

      await tester.tap(find.text('My maps'));
      await tester.pumpAndSettle();
      expect(myMapsTaps, 1);
      expect(
        BasemapKind.values.map((kind) => kind.label),
        isNot(contains('My maps')),
      );
    });

    testWidgets('invites you in when there is nothing there yet',
        (tester) async {
      await pumpPanel(tester, const Size(1080, 2400));
      expect(find.textContaining('Bring your own'), findsOneWidget);
    });

    // Added but switched off looks from the map exactly like not added at all,
    // so the count that matters is how many are actually drawn.
    testWidgets('says none are drawn when all of them are off',
        (tester) async {
      await pumpPanel(tester, const Size(1080, 2400),
          customCount: 2, customDrawn: 0);
      expect(find.text('2 added, none drawn right now'), findsOneWidget);
    });

    testWidgets('counts the drawn ones when only some are on', (tester) async {
      await pumpPanel(tester, const Size(1080, 2400),
          customCount: 3, customDrawn: 1);
      expect(find.text('1 of 3 drawn'), findsOneWidget);
    });

    testWidgets('does not bother with a fraction when all are on',
        (tester) async {
      await pumpPanel(tester, const Size(1080, 2400),
          customCount: 2, customDrawn: 2);
      expect(find.text('2 drawn over the basemap'), findsOneWidget);
    });
  });
}
