import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/custom_map.dart';
import 'package:open_woods_map/waypoints/map_area.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

const _view = GeoBox(north: 45.6, south: 45.4, east: -77.4, west: -77.6);

Waypoint _point(double latitude, double longitude) => Waypoint(
  id: 'p',
  name: 'Point',
  latitude: latitude,
  longitude: longitude,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 30),
);

Waypoint _track(List<(double, double)> points) => Waypoint(
  id: 't',
  name: 'Track',
  latitude: points.first.$1,
  longitude: points.first.$2,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 30),
  track: [
    for (final (latitude, longitude) in points)
      TrackPoint(latitude: latitude, longitude: longitude),
  ],
);

void main() {
  test('a point counts by where it is', () {
    expect(isInBox(_point(45.5, -77.5), _view), isTrue);
    expect(isInBox(_point(45.7, -77.5), _view), isFalse);
    expect(isInBox(_point(45.5, -77.3), _view), isFalse);
  });

  test('a point on the edge of the screen is in it', () {
    expect(isInBox(_point(45.6, -77.5), _view), isTrue);
  });

  test('a track counts when any of its points is on screen', () {
    expect(isInBox(_track([(45.8, -77.5), (45.5, -77.5)]), _view), isTrue);
  });

  // An imported track can be a few points kilometres apart, and a leg that
  // crosses the view without stopping in it is still a line on the screen.
  test('a track counts when a leg crosses the screen between points', () {
    expect(isInBox(_track([(45.5, -77.8), (45.5, -77.2)]), _view), isTrue);
    expect(isInBox(_track([(45.8, -77.5), (45.2, -77.5)]), _view), isTrue);
  });

  test('a track passing the corner without touching it is not', () {
    expect(isInBox(_track([(45.7, -77.7), (45.9, -77.3)]), _view), isFalse);
    expect(isInBox(_track([(45.65, -77.8), (45.8, -77.5)]), _view), isFalse);
  });

  test('a track wholly elsewhere is not', () {
    expect(
      isInBox(_track([(46.0, -78.0), (46.1, -78.1), (46.2, -78.0)]), _view),
      isFalse,
    );
  });
}
