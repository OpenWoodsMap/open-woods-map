import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/tracks/track_math.dart';
import 'package:open_woods_map/tracks/track_trim.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

/// Builds a track due east along one parallel from legs of (metres, km/h),
/// with a fix every [spacing] metres, and stops of so many seconds at one
/// spot with a fix every ten seconds.
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

  _Route move(double metres, double kmh) {
    if (points.isEmpty) _fix();
    final step = Duration(milliseconds: (spacing / (kmh / 3.6) * 1000).round());
    for (var done = 0.0; done < metres; done += spacing) {
      _metres += spacing;
      _time = _time.add(step);
      _fix();
    }
    return this;
  }

  _Route stop(int seconds) {
    if (points.isEmpty) _fix();
    for (var waited = 0; waited < seconds; waited += 10) {
      _time = _time.add(const Duration(seconds: 10));
      _fix();
    }
    return this;
  }

  int get last => points.length - 1;
}

void main() {
  group('suggestTrim', () {
    test('cuts the drive home off a hike', () {
      final route = _Route().move(5000, 4);
      final hikeEnd = route.last;
      route.move(30000, 80);

      final suggestion = suggestTrim(route.points)!;
      expect(suggestion.start, 0);
      expect(suggestion.end, closeTo(hikeEnd, 5));
    });

    test('cuts the drive out as well when recording started at home', () {
      final route = _Route().stop(600).move(12000, 70);
      final hikeStart = route.last;
      route.move(4000, 3.5);
      final hikeEnd = route.last;
      route.move(12000, 70).stop(1200);

      final suggestion = suggestTrim(route.points)!;
      expect(suggestion.start, closeTo(hikeStart, 5));
      expect(suggestion.end, closeTo(hikeEnd, 5));
    });

    // A red light is a slow minute in the middle of a drive, not the outing.
    test('a stop at a light on the way home is not the outing', () {
      final route = _Route().move(5000, 4);
      final hikeEnd = route.last;
      route.move(8000, 60).stop(90).move(8000, 60);

      expect(suggestTrim(route.points)!.end, closeTo(hikeEnd, 5));
    });

    // Quarter of an hour of stop-start through a town averages well above
    // walking pace, so it should not pass for the hunt.
    test('town traffic on the way home is not the outing', () {
      final route = _Route().move(5000, 4);
      final hikeEnd = route.last;
      route.move(10000, 70);
      for (var block = 0; block < 12; block++) {
        route.move(400, 40).stop(40);
      }
      route.move(5000, 70);

      expect(suggestTrim(route.points)!.end, closeTo(hikeEnd, 5));
    });

    test('a walk with no driving gets no suggestion', () {
      final route = _Route().move(3000, 4).stop(1800).move(3000, 4);
      expect(suggestTrim(route.points), isNull);
    });

    // One wild fix can look like a car for a moment. It covers nowhere near
    // the ground a drive does, so the walk either side is one walk.
    test('a GPS jump in the middle of a walk is not a drive', () {
      final route = _Route().move(2000, 4).move(300, 200).move(2000, 4);
      expect(suggestTrim(route.points), isNull);
    });

    test('without times there is nothing to judge speed by', () {
      final route = _Route().move(5000, 4).move(30000, 80);
      final untimed = [
        for (final p in route.points)
          TrackPoint(latitude: p.latitude, longitude: p.longitude),
      ];
      expect(suggestTrim(untimed), isNull);
    });
  });

  test('hasUsableTimes needs every point timed and in order', () {
    final route = _Route().move(100, 4);
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
    final route = _Route().move(200, 4);
    final kept = trimTrack(route.points, 2, 5);
    expect(kept, hasLength(4));
    expect(kept.first, same(route.points[2]));
    expect(kept.last, same(route.points[5]));
  });

  test('a trimmed track is placed where it now starts', () {
    final route = _Route().move(1000, 4);
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
