import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/tracks/track_math.dart';
import 'package:open_woods_map/tracks/track_trim.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

/// Builds a track due east along one parallel at a walking pace, with a fix
/// every [spacing] metres.
class _Route {
  static const spacing = 20.0;
  final points = <TrackPoint>[];
  var _metres = 0.0;
  var _time = DateTime.utc(2026, 10, 3, 6);

  static const _latitude = 45.5;
  static final _metresPerDegree = 111320 * math.cos(_latitude * math.pi / 180);

  void _fix() => points.add(
    TrackPoint(
      latitude: _latitude,
      longitude: -77 + _metres / _metresPerDegree,
      time: _time,
    ),
  );

  _Route move(double metres) {
    if (points.isEmpty) _fix();
    for (var done = 0.0; done < metres; done += spacing) {
      _metres += spacing;
      _time = _time.add(const Duration(seconds: 18));
      _fix();
    }
    return this;
  }
}

void main() {
  test('hasUsableTimes needs every point timed and in order', () {
    final route = _Route().move(100);
    expect(hasUsableTimes(route.points), isTrue);
    expect(hasUsableTimes([route.points[1], route.points[0]]), isFalse);
    expect(
      hasUsableTimes([
        ...route.points,
        const TrackPoint(latitude: 45, longitude: -77),
      ]),
      isFalse,
    );
  });

  test('trimTrack keeps both ends it is given', () {
    final route = _Route().move(200);
    final kept = trimTrack(route.points, 2, 5);
    expect(kept, hasLength(4));
    expect(kept.first, same(route.points[2]));
    expect(kept.last, same(route.points[5]));
  });

  test('a trimmed track is placed where it now starts', () {
    final route = _Route().move(1000);
    final track = Waypoint(
      id: 't',
      name: 'Ridge walk',
      latitude: route.points.first.latitude,
      longitude: route.points.first.longitude,
      notes: '',
      createdAt: DateTime.utc(2026),
      tags: const ['ridge'],
      track: route.points,
    );
    final trimmed = track.withTrack(trimTrack(route.points, 10, 20));
    expect(trimmed.longitude, route.points[10].longitude);
    expect(trimmed.tags, ['ridge']);
    expect(trimmed.name, 'Ridge walk');
    expect(
      trackLengthMetres(trimmed.track),
      closeTo(trackLengthMetres(route.points.sublist(10, 21)), 0.01),
    );
  });
}
