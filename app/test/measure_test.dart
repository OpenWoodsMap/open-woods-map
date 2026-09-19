import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/measure.dart';

void main() {
  // A degree of longitude at 45° N is about 78.7 km, so these hundredths are
  // roughly 790 m apart east-west and 1.1 km apart north-south. Real numbers
  // rather than round ones, because the point of the test is that the line
  // measures the ground and not that the arithmetic was copied from the code.
  const west = 45.0;
  const north = 45.01;
  const left = -75.0;
  const right = -74.99;

  MeasureLine lineOf(List<List<double>> points) {
    var line = const MeasureLine();
    for (final point in points) {
      line = line.adding(point[0], point[1]);
    }
    return line;
  }

  group('before there is a line', () {
    test('nothing is claimed to have been measured', () {
      const empty = MeasureLine();
      expect(empty.isEmpty, isTrue);
      expect(empty.hasLine, isFalse);
      // An em dash rather than "0 m", which would be a measurement.
      expect(empty.headline, '—');
      expect(empty.detail, 'Tap the map to start the line');
      expect(empty.lastBearing, isNull);
    });

    test('one point says what to do next rather than reading zero', () {
      final one = lineOf([
        [west, left],
      ]);
      expect(one.hasLine, isFalse);
      expect(one.headline, '—');
      expect(one.detail, contains('Tap again'));
      expect(one.lastBearing, isNull);
    });
  });

  group('two points', () {
    final line = lineOf([
      [west, left],
      [west, right],
    ]);

    test('measure the distance between them', () {
      expect(line.hasLine, isTrue);
      expect(line.totalMetres, closeTo(786, 2));
      expect(line.headline, '786 m');
    });

    test('and say which way the line runs', () {
      // Due east along a parallel leaves at exactly 90°, which is the one
      // bearing worth hard-coding: a sign error or a swapped argument moves it.
      expect(line.lastBearing, closeTo(90, 0.01));
      expect(line.detail, 'Straight line, heading E 90°');
    });

    test('with nothing about legs, because there is only one', () {
      expect(line.detail, isNot(contains('leg')));
      expect(line.detail, isNot(contains('end to end')));
      // The direct line and the line are the same thing at two points.
      expect(line.directMetres, closeTo(line.totalMetres, 0.001));
    });
  });

  group('a bent line', () {
    // East, then north: a right angle, so the way round is meaningfully longer
    // than the way across.
    final line = lineOf([
      [west, left],
      [west, right],
      [north, right],
    ]);

    test('adds its legs up', () {
      expect(line.totalMetres, closeTo(786 + 1112, 4));
    });

    test('also says how far it is end to end, which is the point of bending it',
        () {
      expect(line.directMetres, closeTo(1362, 4));
      expect(line.directMetres, lessThan(line.totalMetres));
      expect(line.detail, contains('2 legs'));
      expect(line.detail, contains('1.4 km end to end'));
    });

    test('and reports the heading of the last leg, not the first', () {
      expect(line.lastBearing, closeTo(0, 0.01));
      expect(line.detail, contains('last leg N 0°'));
    });
  });

  group('taking points back', () {
    test('undo drops the last one only', () {
      final line = lineOf([
        [west, left],
        [west, right],
        [north, right],
      ]).withoutLast;

      expect(line.points.length, 2);
      expect(line.points.last.longitude, right);
      expect(line.totalMetres, closeTo(786, 2));
    });

    test('undo on an empty line is harmless rather than an error', () {
      expect(const MeasureLine().withoutLast.isEmpty, isTrue);
    });

    test('a line is never mutated, so undo cannot reach a kept one', () {
      final two = lineOf([
        [west, left],
        [west, right],
      ]);
      final three = two.adding(north, right);

      expect(two.points.length, 2);
      expect(three.points.length, 3);
    });
  });
}
