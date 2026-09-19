/// A line the user is measuring along, and the words the map puts on it.
///
/// Its own file for the usual reason: the map shell cannot be widget-tested
/// against a native MapLibre view, so the arithmetic and the wording live where
/// a test can reach them. Everything here is a pure function of the points.
///
/// Distances are geodesic — the shortest path over the ellipsoid — and so ignore
/// the ground going up and down. That understates a walk across a ravine, and
/// deliberately so: a phone's elevation readings are good to tens of metres, and
/// summing their noise along a line produces a confidently wrong slope distance.
/// The same reasoning keeps total ascent out of recorded tracks. What this
/// measures is map distance, which is what a person drawing a line on a map is
/// asking for.
library;

import '../tracks/track_math.dart';
import '../waypoints/waypoint_store.dart';

/// The points tapped so far, with the readings taken off them.
///
/// [TrackPoint] rather than a new coordinate type, so the existing track
/// arithmetic applies unchanged and a measurement could later be kept as a
/// track without converting anything.
class MeasureLine {
  const MeasureLine([this.points = const []]);

  final List<TrackPoint> points;

  MeasureLine adding(double latitude, double longitude) => MeasureLine([
        ...points,
        TrackPoint(latitude: latitude, longitude: longitude),
      ]);

  /// Drops the last point, which is the one a misplaced tap put down.
  MeasureLine get withoutLast => points.isEmpty
      ? const MeasureLine()
      : MeasureLine(points.sublist(0, points.length - 1));

  bool get isEmpty => points.isEmpty;

  /// Two points is the first one that has a length at all.
  bool get hasLine => points.length >= 2;

  double get totalMetres => trackLengthMetres(points);

  /// Straight line from the first point to the last, ignoring everything
  /// tapped in between.
  ///
  /// Only interesting once there is a bend to be shorter than, which is why the
  /// bar shows it from three points on. For a two-point line it is the total.
  double get directMetres => points.length < 2
      ? 0
      : metresBetween(
          points.first.latitude,
          points.first.longitude,
          points.last.latitude,
          points.last.longitude,
        );

  /// Where the last leg is heading, as a bearing from true north.
  ///
  /// True rather than magnetic, because it is measured between two points on the
  /// map rather than read off a compass. Anybody walking it on a handheld
  /// compass has to add the declination themselves — which is the honest place
  /// to leave it, since the app no longer claims to know the device's heading.
  double? get lastBearing {
    if (!hasLine) return null;
    final from = points[points.length - 2];
    final to = points.last;
    return bearingDegrees(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// The big number. An em dash rather than "0 m" before there is a line,
  /// because nothing has been measured yet and zero is a measurement.
  String get headline => hasLine ? formatDistance(totalMetres) : '—';

  /// The quiet line under it: what to do next, or what was just measured.
  String get detail {
    if (points.isEmpty) return 'Tap the map to start the line';
    if (points.length == 1) return 'Tap again to measure to a second point';

    final bearing = lastBearing!;
    final heading = '${compassPoint(bearing)} ${bearing.round()}°';
    if (points.length == 2) return 'Straight line, heading $heading';

    // Along versus direct is the reason to tap a third point at all: it is the
    // difference between the way round and the way across.
    return '${points.length - 1} legs · '
        '${formatDistance(directMetres)} end to end · last leg $heading';
  }
}
