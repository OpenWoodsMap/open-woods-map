/// Which waypoints and tracks sit inside a piece of the map.
library;

import '../map/custom_map.dart';
import 'waypoint_store.dart';

/// Whether [item] is anywhere inside [box].
///
/// A track counts as soon as any part of its line is inside, not only when one
/// of its recorded points is. An imported track can be a handful of points
/// kilometres apart, and a leg that crosses the screen without stopping on it
/// is still a line drawn across what the user was looking at.
bool isInBox(Waypoint item, GeoBox box) {
  if (!item.isTrack) return _contains(box, item.latitude, item.longitude);
  final track = item.track;
  for (var i = 0; i < track.length; i++) {
    final point = track[i];
    if (_contains(box, point.latitude, point.longitude)) return true;
    if (i > 0) {
      final previous = track[i - 1];
      if (_crosses(
        box,
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      )) {
        return true;
      }
    }
  }
  return false;
}

bool _contains(GeoBox box, double latitude, double longitude) =>
    latitude >= box.south &&
    latitude <= box.north &&
    longitude >= box.west &&
    longitude <= box.east;

/// Liang–Barsky: whether the segment from (lat0, lon0) to (lat1, lon1) passes
/// through [box]. Degrees are treated as flat. The map draws the leg straight
/// in Mercator, which bends latitude, but across one track leg the difference
/// is far below what a fingertip could frame.
bool _crosses(GeoBox box, double lat0, double lon0, double lat1, double lon1) {
  final dLon = lon1 - lon0;
  final dLat = lat1 - lat0;
  var low = 0.0;
  var high = 1.0;
  for (final (p, q) in [
    (-dLon, lon0 - box.west),
    (dLon, box.east - lon0),
    (-dLat, lat0 - box.south),
    (dLat, box.north - lat0),
  ]) {
    if (p == 0) {
      if (q < 0) return false;
      continue;
    }
    final t = q / p;
    if (p < 0) {
      if (t > high) return false;
      if (t > low) low = t;
    } else {
      if (t < low) return false;
      if (t < high) high = t;
    }
  }
  return low <= high;
}
