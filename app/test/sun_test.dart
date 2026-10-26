import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/weather/sun.dart';

void main() {
  void near(DateTime actual, DateTime expected) => expect(
    actual.difference(expected).inSeconds.abs(),
    lessThan(150),
    reason: '$actual is not within 2.5 minutes of $expected',
  );

  // Toronto, against the US Naval Observatory's rise and set times: 05:36 and
  // 21:03 EDT at the June solstice, 07:48 and 16:44 EST at the December one.
  test('matches published Toronto times at both solstices', () {
    final june = sunTimesOn(DateTime(2026, 6, 21), 43.6532, -79.3832)!;
    near(june.sunrise, DateTime.utc(2026, 6, 21, 9, 36));
    near(june.sunset, DateTime.utc(2026, 6, 22, 1, 3));

    final december = sunTimesOn(DateTime(2026, 12, 21), 43.6532, -79.3832)!;
    near(december.sunrise, DateTime.utc(2026, 12, 21, 12, 48));
    near(december.sunset, DateTime.utc(2026, 12, 21, 21, 44));
  });

  test('legal light is a half hour either side of the sun', () {
    final sun = sunTimesOn(DateTime(2026, 11, 3), 46.5, -81.0)!;
    expect(sun.sunrise.difference(sun.legalStart), const Duration(minutes: 30));
    expect(sun.legalEnd.difference(sun.sunset), const Duration(minutes: 30));
  });

  test('reads only the calendar date, whatever the time of day', () {
    final morning = sunTimesOn(DateTime(2026, 11, 3, 0, 5), 46.5, -81.0)!;
    final night = sunTimesOn(DateTime(2026, 11, 3, 23, 55), 46.5, -81.0)!;
    expect(morning.sunrise, night.sunrise);
  });

  test('sunrise falls on the date asked for, west of Greenwich', () {
    final sun = sunTimesOn(DateTime(2026, 11, 3), 49.77, -94.49)!;
    final local = sun.sunrise.subtract(const Duration(hours: 6));
    expect((local.year, local.month, local.day), (2026, 11, 3));
  });

  test('says so where the sun never sets', () {
    expect(sunTimesOn(DateTime(2026, 6, 21), 78.2, 15.6), isNull);
    expect(sunTimesOn(DateTime(2026, 12, 21), 78.2, 15.6), isNull);
  });
}
