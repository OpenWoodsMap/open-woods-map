import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/waypoints/waypoint_editor.dart';
import 'package:open_woods_map/waypoints/waypoint_icon.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

Waypoint _point() => Waypoint(
      id: '1',
      name: 'Stand',
      latitude: 45.1,
      longitude: -77.1,
      notes: '',
      createdAt: DateTime.utc(2026, 9, 10),
      icon: WaypointIcon.stand,
    );

void main() {
  Future<List<Waypoint>> pumpEditor(WidgetTester tester) async {
    // Tall on purpose: the grid is what makes this sheet long, and a tap that
    // lands off a phone-sized surface misses silently.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final saved = <Waypoint>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaypointEditor(
            existing: _point(),
            knownTags: const [],
            isNew: false,
            onSave: saved.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  // The report: the sheet opened so tall that the icon list was most of it, and
  // reaching Save meant scrolling past everything. The grid is the tallest part
  // and the part most edits do not touch, so it starts closed.
  group('the glyph grid starts closed', () {
    testWidgets('the row names the icon this waypoint already has',
        (tester) async {
      await pumpEditor(tester);

      expect(find.text('Tree stand'), findsOneWidget);
      expect(find.text('Hunting'), findsNothing);
      // Any glyph other than the selected one, which the closed row still draws.
      expect(find.byIcon(Icons.pets), findsNothing);
    });

    testWidgets('tapping the row opens it', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('Tree stand'));
      await tester.pumpAndSettle();

      expect(find.text('Hunting'), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget);
    });
  });

  group('picking a glyph', () {
    // The names are no longer beside the glyphs, so this row is the only thing
    // that reads back what was chosen. If it did not follow the selection, the
    // grid would be unreadable rather than merely compact.
    testWidgets('renames the row', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.text('Tree stand'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pets));
      await tester.pumpAndSettle();

      expect(find.text('Animal sign'), findsOneWidget);
      expect(find.text('Tree stand'), findsNothing);
    });

    // Closing on the first tap would take the grid away before you could
    // compare what you just picked with the glyph beside it.
    testWidgets('leaves the grid open', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.text('Tree stand'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pets));
      await tester.pumpAndSettle();

      expect(find.text('Hunting'), findsOneWidget);
    });

    testWidgets('is what gets saved', (tester) async {
      final saved = await pumpEditor(tester);
      await tester.tap(find.text('Tree stand'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pets));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(saved.single.icon, WaypointIcon.sign);
    });
  });

  // Dropping the names off the grid is only acceptable while they stay
  // reachable, and a screen reader is the case that cannot fall back to
  // recognising the picture.
  testWidgets('a glyph still carries its name for a screen reader',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpEditor(tester);
    await tester.tap(find.text('Tree stand'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Animal sign'), findsOneWidget);

    handle.dispose();
  });

  // Save was the last widget inside the scrolling area, below Notes, which is
  // what made it unreachable. Asserting on the tree rather than on a screenshot,
  // because a later refactor could bury it again and no test would notice.
  testWidgets('Done sits outside the scrolling area', (tester) async {
    await pumpEditor(tester);

    expect(find.text('Done'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Done'),
      ),
      findsNothing,
    );
  });
}
