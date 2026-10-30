import '../waypoints/waypoint_store.dart';

/// Whether every point has a time and the times never run backwards, which is
/// what a recording gives and what an imported file often does not.
bool hasUsableTimes(List<TrackPoint> points) {
  DateTime? previous;
  for (final point in points) {
    final time = point.time;
    if (time == null) return false;
    if (previous != null && time.isBefore(previous)) return false;
    previous = time;
  }
  return points.isNotEmpty;
}

/// Seconds from the first point to each point. Assumes [hasUsableTimes].
List<double> secondsAlong(List<TrackPoint> points) {
  final first = points.first.time!;
  return [
    for (final point in points)
      point.time!.difference(first).inMilliseconds / 1000.0,
  ];
}

/// The points from [start] to [end], both kept.
List<TrackPoint> trimTrack(List<TrackPoint> points, int start, int end) =>
    points.sublist(start, end + 1);
