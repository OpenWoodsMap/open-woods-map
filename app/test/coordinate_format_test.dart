import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/search/coordinate_parser.dart';
import 'package:open_woods_map/settings/coordinate_format.dart';

void main() {
  // The same PROJ values coordinate_parser_test.dart reads in the other
  // direction, from tools/gis/build_utm_fixtures.py.
  group('UTM forward', () {
    for (final (zone, easting, northing, lat, lon) in const [
      (18, 439000.0, 4991000.0, 45.06983250215938, -75.77490332018807),
      (18, 500000.0, 5000000.0, 45.153477183356024, -75.0),
      (17, 612345.0, 5432109.0, 49.031622374401444, -79.46302734428295),
      (16, 400000.0, 5600000.0, 50.54337955474289, -88.41133877037352),
    ]) {
      test('zone $zone $easting $northing', () {
        final (e, n) = utmFromLatLon(lat, lon, zone);
        expect(e, closeTo(easting, 0.01));
        expect(n, closeTo(northing, 0.01));
      });
    }

    test('picks the zone and band from the point', () {
      expect(
        utmGridReference(45.06983250215938, -75.77490332018807),
        '18T 439000 E 4991000 N',
      );
    });
  });

  group('degrees', () {
    test('degrees and minutes', () {
      expect(
        CoordinateFormat.degreesMinutes.format(45.5, -78.25),
        '45° 30.000′ N, 78° 15.000′ W',
      );
    });

    test('seconds carry rather than printing sixty', () {
      expect(
        CoordinateFormat.degreesMinutesSeconds.format(45.999999, -78.5),
        '46° 0′ 0.0″ N, 78° 30′ 0.0″ W',
      );
    });

    test('decimal keeps the precision the caller asks for', () {
      expect(
        CoordinateFormat.decimal.format(45.5, -78.25, decimals: 6),
        '45.500000, -78.250000',
      );
    });
  });

  // What a card shows can be copied and pasted back into search, so every
  // format has to land within a couple of metres of where it started.
  test('the search box reads every format back to the same place', () {
    const latitude = 47.123456;
    const longitude = -80.654321;
    for (final format in CoordinateFormat.values) {
      final text = format.format(latitude, longitude);
      final read = parseCoordinate(text);
      expect(read, isA<Coordinate>(), reason: text);
      final c = read! as Coordinate;
      expect(c.latitude, closeTo(latitude, 2e-5), reason: text);
      expect(c.longitude, closeTo(longitude, 3e-5), reason: text);
    }
  });

  testWidgets('decimal where no scope is above', (tester) async {
    late CoordinateFormat seen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = CoordinateFormatScope.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(seen, CoordinateFormat.decimal);
  });

  test('an unknown stored id falls back rather than throwing', () {
    expect(CoordinateFormat.fromId('mgrs'), CoordinateFormat.decimal);
    expect(CoordinateFormat.fromId('utm'), CoordinateFormat.utm);
  });
}
