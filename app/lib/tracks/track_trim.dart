import '../waypoints/waypoint_store.dart';
import 'track_math.dart';

/// The speed above which a stretch of track reads as driving.
///
/// About five times a brisk walk, and below what a vehicle holds on any road
/// worth the name. An ATV on a trail can reach it too, so a ride in may read as
/// driving: one more reason [suggestTrim] only ever moves the handles.
const drivingKilometresPerHour = 25.0;

const _drivingMetresPerSecond = drivingKilometresPerHour / 3.6;

/// Speed is judged over a minute either side of each point rather than from one
/// fix to the next, so a single jumpy fix does not read as a car and a minute
/// at a red light does not read as a walk.
const _speedWindowSeconds = 60.0;

/// The least that counts as the outing rather than a stop on the way to it. A
/// fuel stop is shorter; a hunt or a hike is longer.
const _activitySeconds = 15 * 60.0;

/// An outing averages walking pace or slower, stops included. Town traffic,
/// stop-start for a quarter of an hour, does not.
const _activityMetresPerSecond = 10 / 3.6;

/// Travel at vehicle speed shorter than this is not a drive worth cutting, and
/// slow stretches either side of it are the same outing. It also absorbs a GPS
/// jump, which can look fast for a moment but never covers this much ground.
const _driveMetres = 2000.0;

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

/// Where a recording turns from driving into the outing and back, as inclusive
/// point indices.
class TrimSuggestion {
  const TrimSuggestion(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is TrimSuggestion && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// A guess at the drive to and from the outing, or null when there is nothing
/// to suggest.
///
/// This is an interpretation, not a reading: it finds the first and last
/// stretch slow and long enough to be the outing and suggests cutting the
/// vehicle-speed travel beyond them. A long stop on the drive home can pass for
/// the outing. That is why it moves the handles and saves nothing; the person
/// who was there checks it on the map.
///
/// Null without usable times, since speed is the only evidence it has.
TrimSuggestion? suggestTrim(List<TrackPoint> points) {
  final n = points.length;
  if (n < 3 || !hasUsableTimes(points)) return null;
  final metres = cumulativeMetres(points);
  final seconds = secondsAlong(points);

  final fast = List<bool>.filled(n, false);
  var lo = 0;
  var hi = 0;
  for (var i = 0; i < n; i++) {
    while (seconds[i] - seconds[lo] > _speedWindowSeconds) {
      lo++;
    }
    if (hi < i) hi = i;
    while (hi + 1 < n && seconds[hi + 1] - seconds[i] <= _speedWindowSeconds) {
      hi++;
    }
    // Fixes further apart than the window still have neighbours to measure
    // against; a lone point would otherwise always read as standing still.
    final from = lo == hi ? (i > 0 ? i - 1 : i) : lo;
    final to = lo == hi ? (i < n - 1 ? i + 1 : i) : hi;
    final span = seconds[to] - seconds[from];
    fast[i] =
        span > 0 &&
        (metres[to] - metres[from]) / span >= _drivingMetresPerSecond;
  }

  final runs = <(int, int)>[];
  for (var i = 0; i < n; i++) {
    if (fast[i]) continue;
    final first = i;
    while (i + 1 < n && !fast[i + 1]) {
      i++;
    }
    if (runs.isNotEmpty &&
        metres[first] - metres[runs.last.$2] < _driveMetres) {
      runs.last = (runs.last.$1, i);
    } else {
      runs.add((first, i));
    }
  }

  bool isOuting((int, int) run) {
    final (first, last) = run;
    final span = seconds[last] - seconds[first];
    return span >= _activitySeconds &&
        (metres[last] - metres[first]) / span <= _activityMetresPerSecond;
  }

  final outings = runs.where(isOuting).toList();
  var start = 0;
  var end = n - 1;
  for (final (first, _) in outings) {
    if (metres[first] >= _driveMetres) {
      start = first;
      break;
    }
  }
  for (final (_, last) in outings.reversed) {
    if (metres[n - 1] - metres[last] >= _driveMetres) {
      end = last;
      break;
    }
  }
  if (end <= start || (start == 0 && end == n - 1)) return null;
  return TrimSuggestion(start, end);
}
