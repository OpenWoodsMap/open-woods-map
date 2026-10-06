import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/own_hits.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

Waypoint _point(String id, double latitude, double longitude) => Waypoint(
  id: id,
  name: id,
  latitude: latitude,
  longitude: longitude,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 6),
);

Waypoint _track(String id) => Waypoint(
  id: id,
  name: id,
  latitude: 45.0,
  longitude: -77.0,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 6),
  track: const [
    TrackPoint(latitude: 45.0, longitude: -77.0),
    TrackPoint(latitude: 45.01, longitude: -77.0),
  ],
);

void main() {
  final near = _point('near', 45.00001, -77.0);
  final far = _point('far', 45.0002, -77.0);
  final loop = _track('loop');
  final spur = _track('spur');
  final items = [far, loop, near, spur];

  List<String> rank({
    List<String> points = const [],
    List<String> lines = const [],
  }) => rankOwnHits(
    pointIds: points,
    lineIds: lines,
    items: items,
    latitude: 45.0,
    longitude: -77.0,
  ).map((item) => item.id).toList();

  test('nothing touched is nothing', () {
    expect(rank(), isEmpty);
  });

  test('a waypoint beats the track it sits on', () {
    expect(rank(points: ['near'], lines: ['loop']), ['near', 'loop']);
  });

  test('stacked waypoints come nearest first', () {
    expect(rank(points: ['far', 'near']), ['near', 'far']);
  });

  // Each track is returned by its stroke layer, its marker layer and once per
  // tile it crosses, and a pin by both its glyph and its backdrop.
  test('each item appears once however many layers found it', () {
    expect(
      rank(points: ['near', 'near', 'far', 'near'], lines: ['loop', 'loop']),
      ['near', 'far', 'loop'],
    );
  });

  test('tracks keep the order they were found in', () {
    expect(rank(lines: ['spur', 'loop', 'spur']), ['spur', 'loop']);
  });

  test('an id that matches nothing saved is dropped', () {
    expect(rank(points: ['deleted'], lines: ['gone', 'loop']), ['loop']);
  });

  // Only a track's line layers report tracks; a point layer reporting one
  // would be a style mistake, and it must not put a track above a waypoint.
  test('an item found in the wrong kind of layer is ignored', () {
    expect(rank(points: ['loop'], lines: ['near']), isEmpty);
  });
}
