import '../tracks/track_math.dart';
import '../waypoints/waypoint_store.dart';

/// How far from the finger, in logical pixels, a tap still counts as touching
/// one of the user's own waypoints or tracks.
///
/// A rendered track is about four pixels wide, so an exact-point query asked a
/// thumb to land on a line narrower than its own edge. Ten either side is a
/// box roughly the size of a fingertip's contact patch. It is kept that small
/// because whatever it catches takes the tap away from Land Info, and a tap a
/// thumb's width beside a track is often a question about the ground.
const ownHitSlop = 10.0;

/// The user's items a tap touched, best first, each once.
///
/// [pointIds] and [lineIds] are the `id` properties MapLibre returned for the
/// waypoint layers and the track layers, in any order and with repeats: one
/// track comes back once per tile it crosses, and once more from each of its
/// marker and stroke layers.
///
/// Waypoints come before tracks because a waypoint is the smaller target, so
/// hitting one is the more deliberate act, and it usually sits on the track it
/// was saved along. Among waypoints the nearest to [latitude], [longitude]
/// wins, because stacked pins overlap on screen without sharing a coordinate.
/// Tracks keep the order they were found in: the distance to a line is not
/// what someone aiming at one is judging by.
///
/// Ids that match nothing saved are dropped. A tap can race a delete, and a
/// follow line whose track has gone is not something to open.
List<Waypoint> rankOwnHits({
  required Iterable<String> pointIds,
  required Iterable<String> lineIds,
  required List<Waypoint> items,
  required double latitude,
  required double longitude,
}) {
  final byId = {for (final item in items) item.id: item};
  final seen = <String>{};
  final points = <Waypoint>[
    for (final id in pointIds)
      if (byId[id] case final item? when !item.isTrack && seen.add(id)) item,
  ];
  double away(Waypoint item) =>
      metresBetween(latitude, longitude, item.latitude, item.longitude);
  points.sort((a, b) => away(a).compareTo(away(b)));
  final lines = <Waypoint>[
    for (final id in lineIds)
      if (byId[id] case final item? when item.isTrack && seen.add(id)) item,
  ];
  return [...points, ...lines];
}
