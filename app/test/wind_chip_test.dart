import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/wind_chip.dart';

void main() {
  final taken = DateTime(2026, 10, 3, 7, 30);

  WindReading reading({
    int from = 315,
    double speed = 18,
    double gusts = 22,
  }) =>
      WindReading(
        directionFrom: from,
        speedKmh: speed,
        gustsKmh: gusts,
        takenAt: taken,
      );

  /// The reading's own words as of [minutes] after it was fetched.
  ///
  /// Read inside the fixed clock rather than built inside it: the age is worked
  /// out when the chip asks for it, which is the moment being faked.
  String detailAtAge(int minutes, WindReading Function() read) => withClock(
        Clock.fixed(taken.add(Duration(minutes: minutes))),
        () => read().detail,
      );

  group('which way the wind is going', () {
    // The error this class exists to prevent. Meteorological bearings name where
    // the wind comes from, so reading one as "blowing toward" puts a hunter
    // downwind of what they are hunting, and nothing on screen would say so.
    test('is the opposite of where it is coming from', () {
      expect(reading(from: 315).directionTo, 135);
      expect(reading(from: 10).directionTo, 190);
      expect(reading(from: 270).directionTo, 90);
      expect(reading(from: 180).directionTo, 0);
    });

    test('is named in the small print, so the arrow cannot be read backwards',
        () {
      expect(reading(from: 0).headline, 'From N · 18 km/h');
      expect(detailAtAge(0, () => reading(from: 0)), startsWith('Toward S'));
    });
  });

  group('the arrow on a map that has been turned', () {
    // A north-up map: the arrow's angle is simply where the air is going.
    test('points along the air when north is up', () {
      expect(reading(from: 0).screenRadians(0), closeTo(math.pi, 1e-9));
      expect(reading(from: 270).screenRadians(0), closeTo(math.pi / 2, 1e-9));
    });

    // The half that is easy to get wrong, and wrong silently: the map rotates on
    // a two-finger twist unless north is locked, and an arrow that ignores that
    // is confidently incorrect with nothing to give it away.
    test('turns with the map, not with the screen', () {
      final wind = reading(from: 0);
      // Turn the map so the way the air is going is up the screen, and the arrow
      // should sit upright.
      expect(wind.screenRadians(wind.directionTo.toDouble()), closeTo(0, 1e-9));
      // Turn it a quarter further and the arrow follows the ground round.
      expect(
        wind.screenRadians(wind.directionTo - 90),
        closeTo(math.pi / 2, 1e-9),
      );
    });
  });

  group('air that is barely moving', () {
    // The model reports a direction for a dead calm morning, and drawing an arrow
    // from it would dress noise up as a bearing. Scent pools rather than travels
    // at these speeds, so there is nothing honest to point at.
    test('is called calm and given no direction', () {
      final calm = reading(speed: 1.2, gusts: 3);
      expect(calm.isCalm, isTrue);
      expect(calm.headline, 'Calm');
      final detail = detailAtAge(0, () => calm);
      expect(detail, contains('No steady direction'));
      expect(detail, isNot(contains('Toward')));
    });

    test('but a light steady wind still gets one', () {
      final light = reading(speed: 4, gusts: 6);
      expect(light.isCalm, isFalse);
      expect(detailAtAge(0, () => light), contains('Toward'));
    });
  });

  group('what the chip admits about its own numbers', () {
    // Open-Meteo reports modelled wind ten metres up over a grid cell kilometres
    // across. Under canopy the wind on the ground can sit still or run the other
    // way, so the chip has to say which kind of number this is.
    test('says it is a forecast, and how high up', () {
      expect(detailAtAge(0, () => reading()), contains('forecast, 10 m up'));
      // Including when it is too calm to say anything else.
      expect(
        detailAtAge(0, () => reading(speed: 0.5)),
        contains('forecast, 10 m up'),
      );
    });

    test('stays quiet about its age while it is fresh', () {
      expect(detailAtAge(5, () => reading()), isNot(contains('ago')));
    });

    // Wind turns, and a chip that sat on screen through a two-hour walk would
    // otherwise keep presenting the morning's wind as the current one.
    test('says how old it is once it is worth knowing', () {
      expect(detailAtAge(45, () => reading()), contains('read 45 min ago'));
    });
  });

  group('the chip on screen', () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required WindReading? wind,
      bool refreshing = false,
      required VoidCallback onRefresh,
      required VoidCallback onDismiss,
    }) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WindChip(
                reading: wind,
                mapBearing: 0,
                refreshing: refreshing,
                onRefresh: onRefresh,
                onDismiss: onDismiss,
              ),
            ),
          ),
        );

    testWidgets('reads out the wind and how to get rid of it', (tester) async {
      var refreshed = 0;
      var dismissed = 0;
      await withClock(Clock.fixed(taken), () async {
        await pumpChip(
          tester,
          wind: reading(),
          onRefresh: () => refreshed++,
          onDismiss: () => dismissed++,
        );
      });

      expect(find.text('From NW · 18 km/h'), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsOneWidget);

      // The body refreshes and the cross puts it away: the age is the reason to
      // want the first, and the second is what the user asked the menu for.
      await tester.tap(find.text('From NW · 18 km/h'));
      await tester.tap(find.byTooltip('Hide wind'));
      await tester.pump();
      expect([refreshed, dismissed], [1, 1]);
    });

    // Getting here needs a GPS fix and a network round trip, and showing nothing
    // until both land made the menu item look broken for as long as it took. The
    // chip arrives empty-handed instead and fills in.
    testWidgets('shows up before it has anything to say', (tester) async {
      await pumpChip(
        tester,
        wind: null,
        refreshing: true,
        onRefresh: () {},
        onDismiss: () {},
      );

      expect(find.text('Reading the wind'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Nothing to put away yet, and the request ends on its own either way.
      expect(find.byTooltip('Hide wind'), findsNothing);
    });

    testWidgets('draws no arrow for calm air', (tester) async {
      await withClock(Clock.fixed(taken), () async {
        await pumpChip(
          tester,
          wind: reading(speed: 0.8, gusts: 2),
          onRefresh: () {},
          onDismiss: () {},
        );
      });

      expect(find.text('Calm'), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsNothing);
    });

    testWidgets('cannot be asked to refresh twice at once', (tester) async {
      var refreshed = 0;
      await withClock(Clock.fixed(taken), () async {
        await pumpChip(
          tester,
          wind: reading(),
          refreshing: true,
          onRefresh: () => refreshed++,
          onDismiss: () {},
        );
      });

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('From NW · 18 km/h'));
      await tester.pump();
      expect(refreshed, 0);
    });
  });

  group('gusts', () {
    // Worth saying when they change what the wind will actually feel like, and
    // noise on the chip when they do not.
    test('are mentioned only when well above the steady wind', () {
      expect(
        detailAtAge(0, () => reading(speed: 18, gusts: 22)),
        isNot(contains('gusts')),
      );
      expect(
        detailAtAge(0, () => reading(speed: 18, gusts: 31)),
        contains('gusts 31'),
      );
    });
  });
}
