import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/measure.dart';
import 'package:open_woods_map/map/measure_bar.dart';

void main() {
  var undone = 0;
  var cleared = 0;
  var done = 0;

  setUp(() {
    undone = 0;
    cleared = 0;
    done = 0;
  });

  Future<void> pumpBar(WidgetTester tester, MeasureLine line) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeasureBar(
              line: line,
              onUndo: () => undone++,
              onClear: () => cleared++,
              onDone: () => done++,
            ),
          ),
        ),
      );

  bool enabled(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon))
          .onPressed !=
      null;

  MeasureLine lineOf(List<List<double>> points) {
    var line = const MeasureLine();
    for (final point in points) {
      line = line.adding(point[0], point[1]);
    }
    return line;
  }

  // Measuring takes over the map's tap gesture, so the bar is what stops that
  // from being a mystery. Its title is the whole disclosure.
  testWidgets('says the map is in a mode', (tester) async {
    await pumpBar(tester, const MeasureLine());
    expect(find.text('Measuring'), findsOneWidget);
  });

  testWidgets('tells an empty line what to do next', (tester) async {
    await pumpBar(tester, const MeasureLine());
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Tap the map to start the line'), findsOneWidget);
  });

  testWidgets('shows the distance once there is one', (tester) async {
    await pumpBar(
      tester,
      lineOf([
        [45.0, -75.0],
        [45.0, -74.99],
      ]),
    );
    expect(find.text('786 m'), findsOneWidget);
    expect(find.textContaining('heading E'), findsOneWidget);
  });

  // Disabled rather than absent, so the row does not reflow out from under a
  // thumb already moving toward Done.
  testWidgets('offers undo and clear only once they would do something', (
    tester,
  ) async {
    await pumpBar(tester, const MeasureLine());
    expect(enabled(tester, Icons.undo), isFalse);
    expect(enabled(tester, Icons.clear_all), isFalse);
    // Leaving the mode is always available, including from a line with nothing
    // on it.
    expect(enabled(tester, Icons.close), isTrue);

    await pumpBar(
      tester,
      lineOf([
        [45.0, -75.0],
      ]),
    );
    expect(enabled(tester, Icons.undo), isTrue);
    expect(enabled(tester, Icons.clear_all), isTrue);
  });

  testWidgets('each button asks for its own thing', (tester) async {
    await pumpBar(
      tester,
      lineOf([
        [45.0, -75.0],
        [45.0, -74.99],
      ]),
    );

    await tester.tap(find.byTooltip('Undo last point'));
    await tester.tap(find.byTooltip('Clear the line'));
    await tester.tap(find.byTooltip('Done measuring'));
    await tester.pump();

    expect([undone, cleared, done], [1, 1, 1]);
  });
}
