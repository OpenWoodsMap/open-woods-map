import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/waypoints/icon_match.dart';
import 'package:open_woods_map/waypoints/waypoint_icon.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

Waypoint _point(
  String id,
  String name, {
  WaypointIcon icon = WaypointIcon.pin,
}) => Waypoint(
  id: id,
  name: name,
  latitude: 45.0,
  longitude: -77.0,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 8),
  icon: icon,
);

Waypoint _track(String id, String name) => Waypoint(
  id: id,
  name: name,
  latitude: 45.0,
  longitude: -77.0,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 8),
  track: const [
    TrackPoint(latitude: 45.0, longitude: -77.0),
    TrackPoint(latitude: 45.01, longitude: -77.0),
  ],
);

void main() {
  group('matchName', () {
    test('a plain word or phrase starts ticked', () {
      expect(matchName('North stand'), (icon: WaypointIcon.stand, doubt: null));
      expect(matchName('Trail cam 3')?.icon, WaypointIcon.camera);
      expect(matchName('Truck')?.icon, WaypointIcon.parking);
      expect(matchName('Boat launch')?.icon, WaypointIcon.boatLaunch);
      expect(matchName('Box blind')?.icon, WaypointIcon.blind);
      expect(matchName('Blood trail')?.icon, WaypointIcon.blood);
    });

    test('forgives plurals and accents', () {
      expect(matchName('Blueberries')?.icon, WaypointIcon.berries);
      expect(matchName('Rubs')?.icon, WaypointIcon.sign);
      expect(matchName('Écureuil')?.icon, WaypointIcon.squirrel);
      expect(matchName('Spot à doré')?.icon, WaypointIcon.fishing);
    });

    test('whole words only', () {
      expect(matchName('Grandstand'), isNull);
      expect(matchName('Campbell farm')?.icon, WaypointIcon.farm);
      expect(matchName('WPT 023'), isNull);
      expect(matchName(''), isNull);
    });

    test('a place name is proposed but not ticked', () {
      for (final name in ['Bear Creek', 'Deer Lake', 'Lac Castor']) {
        final match = matchName(name);
        expect(match, isNotNull, reason: name);
        expect(match!.doubt, contains('place name'), reason: name);
      }
    });

    test('a place name does not spoil the word that is not one', () {
      expect(
        matchName('Bear Creek stand'),
        (icon: WaypointIcon.stand, doubt: null),
      );
    });

    test('two different icons are proposed but not ticked', () {
      final match = matchName('Bear stand');
      expect(match?.icon, WaypointIcon.stand);
      expect(match?.doubt, contains('bear'));
    });

    test('ordinary words that are rarely a mark are not in the table', () {
      expect(matchName('Well marked'), isNull);
      expect(matchName('Not ours'), isNull);
    });

    test('every word maps to a point icon, never a line', () {
      for (final MapEntry(:key, :value) in iconWords.entries) {
        expect(value.group, isNot(WaypointIconGroup.lines), reason: key);
        expect(value, isNot(WaypointIcon.fallback), reason: key);
        expect(key, key.toLowerCase(), reason: key);
      }
    });
  });

  group('matchIconsToNames', () {
    test('only plain pins are looked at, and the rest are counted', () {
      final matches = matchIconsToNames([
        _point('1', 'North stand'),
        _point('2', 'South stand', icon: WaypointIcon.blind),
        _point('3', 'WPT 001'),
        _track('4', 'Stand loop'),
      ]);
      expect(matches.suggestions.map((s) => s.item.id), ['1']);
      expect(matches.alreadySet, 1);
      expect(matches.unmatched, 1);
    });
  });

  group('revertIconMatches', () {
    test('puts the pin back only where the given icon is still there', () {
      final current = [
        _point('1', 'North stand', icon: WaypointIcon.stand),
        _point('2', 'Truck', icon: WaypointIcon.gate),
        _point('3', 'Other', icon: WaypointIcon.bear),
      ];
      final out = revertIconMatches(
        current: current,
        applied: {'1': WaypointIcon.stand, '2': WaypointIcon.parking},
      );
      expect(out.map((item) => item.icon), [
        WaypointIcon.pin,
        WaypointIcon.gate,
        WaypointIcon.bear,
      ]);
    });
  });
}
