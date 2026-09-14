import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/waypoints/waypoint_icon.dart';
import 'package:open_woods_map/waypoints/waypoint_editor.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

Waypoint _point({List<String> tags = const []}) => Waypoint(
      id: '1',
      name: 'Stand',
      latitude: 45.1,
      longitude: -77.1,
      notes: '',
      createdAt: DateTime.utc(2026, 9, 10),
      icon: WaypointIcon.stand,
      tags: tags,
    );

/// The chip carrying [tag], whatever kind of chip it is.
FilterChip _chip(WidgetTester tester, String tag) => tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, tag),
    );

void main() {
  Future<List<Waypoint>> pumpEditor(
    WidgetTester tester, {
    required Waypoint existing,
    List<String> knownTags = const [],
  }) async {
    // Tall on purpose: the editor scrolls itself and the tag chips sit well
    // below the icon grid, where a tap on a phone-sized surface silently misses.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final saved = <Waypoint>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaypointEditor(
            existing: existing,
            knownTags: knownTags,
            isNew: false,
            onSave: saved.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  // The bug: applied tags were InputChips and available ones ActionChips, which
  // differ only by a small leading glyph. On a phone the two read the same, so
  // there was no way to tell what this waypoint would be saved with.
  group('a tag on this waypoint looks different from one merely available', () {
    testWidgets('applied tags are selected and available ones are not',
        (tester) async {
      await pumpEditor(
        tester,
        existing: _point(tags: ['ridge']),
        knownTags: const ['ridge', 'swamp'],
      );

      expect(_chip(tester, 'ridge').selected, isTrue);
      expect(_chip(tester, 'swamp').selected, isFalse);
    });

    // Material draws a checkmark and a filled container for a selected
    // FilterChip. Both were what the report asked for, and asserting the
    // checkmark is not suppressed is the part a theme change could quietly undo.
    testWidgets('a selected tag keeps its checkmark', (tester) async {
      await pumpEditor(tester, existing: _point(tags: ['ridge']));

      expect(_chip(tester, 'ridge').showCheckmark, isNot(false));
    });
  });

  group('tapping a tag chip toggles it', () {
    testWidgets('an available tag becomes selected', (tester) async {
      await pumpEditor(
        tester,
        existing: _point(),
        knownTags: const ['swamp'],
      );
      expect(_chip(tester, 'swamp').selected, isFalse);

      await tester.tap(find.widgetWithText(FilterChip, 'swamp'));
      await tester.pumpAndSettle();

      expect(_chip(tester, 'swamp').selected, isTrue);
    });

    testWidgets('an applied tag comes off, and off the saved waypoint',
        (tester) async {
      final saved = await pumpEditor(
        tester,
        existing: _point(tags: ['ridge', 'swamp']),
      );

      await tester.tap(find.widgetWithText(FilterChip, 'ridge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(saved.single.tags, ['swamp']);
    });

    testWidgets('what is selected is what gets saved', (tester) async {
      final saved = await pumpEditor(
        tester,
        existing: _point(),
        knownTags: const ['ridge', 'swamp'],
      );

      await tester.tap(find.widgetWithText(FilterChip, 'swamp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(saved.single.tags, ['swamp']);
    });
  });

  // Making a tag and adopting a built-in example are acts rather than states, so
  // they stay ActionChips. Otherwise they would look like tags that are on this
  // waypoint but unselected, which is the confusion this fix removes.
  testWidgets('New tag is not offered as something to select', (tester) async {
    await pumpEditor(tester, existing: _point());

    expect(find.widgetWithText(ActionChip, 'New tag'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'New tag'), findsNothing);
  });
}
