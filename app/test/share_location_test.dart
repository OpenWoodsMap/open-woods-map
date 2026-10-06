import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/share_location.dart';
import 'package:open_woods_map/search/coordinate_parser.dart';

void main() {
  final now = DateTime(2026, 10, 6, 17, 0);

  group('how old a fix is', () {
    test('under a minute is just now', () {
      expect(fixAge(now.subtract(const Duration(seconds: 40)), now), 'just now');
    });

    test('minutes and hours are counted, and one is not plural', () {
      expect(fixAge(now.subtract(const Duration(minutes: 1)), now),
          '1 minute ago');
      expect(fixAge(now.subtract(const Duration(minutes: 14)), now),
          '14 minutes ago');
      expect(fixAge(now.subtract(const Duration(hours: 3)), now),
          '3 hours ago');
    });

    test('older than a day gives the date', () {
      expect(fixAge(DateTime(2026, 10, 3, 9), now), 'on 2026-10-03');
    });
  });

  group('my location', () {
    String mine({double accuracy = 12.4, Duration age = Duration.zero}) =>
        myLocationText(
          latitude: 45.583412,
          longitude: -78.362497,
          accuracyMetres: accuracy,
          taken: now.subtract(age),
          now: now,
        );

    test('leads with the coordinates and says how good the fix is', () {
      final text = mine();
      expect(text, startsWith('My location: 45.58341, -78.36250'));
      expect(text, contains('Accurate to about 12 m, from a GPS fix just now.'));
      expect(text, isNot(contains('moved')));
    });

    // A last known position is still worth sending, but only if it says so.
    test('an old fix admits the sender may have moved', () {
      final text = mine(age: const Duration(minutes: 25));
      expect(text, contains('25 minutes ago'));
      expect(text, contains('I may have moved since.'));
    });

    test('a fix with no accuracy says so rather than inventing one', () {
      expect(mine(accuracy: 0), contains('the phone gave no accuracy'));
    });

    test('ends with a link that opens in a map app', () {
      expect(
        mine().split('\n').last,
        'https://maps.google.com/?q=45.58341,-78.36250',
      );
    });
  });

  test('a tapped spot says it is not where the sender is', () {
    expect(
      spotText(latitude: 45.1, longitude: -77.2),
      startsWith('A spot on the map, not where I am: 45.10000, -77.20000'),
    );
  });

  test('a waypoint goes by name, without its notes', () {
    expect(
      waypointText(name: 'Ridge stand', latitude: 45.1, longitude: -77.2),
      'Ridge stand: 45.10000, -77.20000\n'
      'https://maps.google.com/?q=45.10000,-77.20000',
    );
  });

  // Someone who also has the app should be able to paste the whole message
  // into search and land on the spot, without trimming it first.
  group('the whole message pasted into search', () {
    for (final (kind, text) in [
      (
        'my location',
        myLocationText(
          latitude: 45.58341,
          longitude: -78.3625,
          accuracyMetres: 8,
          taken: now,
          now: now,
        ),
      ),
      ('a spot', spotText(latitude: 45.58341, longitude: -78.3625)),
      (
        'a waypoint',
        waypointText(
          name: 'Stand 3, by the creek',
          latitude: 45.58341,
          longitude: -78.3625,
        ),
      ),
    ]) {
      test('reads back $kind', () {
        final parsed = parseCoordinate(text);
        expect(parsed, isA<Coordinate>());
        final point = parsed! as Coordinate;
        expect(point.latitude, closeTo(45.58341, 1e-9));
        expect(point.longitude, closeTo(-78.3625, 1e-9));
      });
    }
  });
}
