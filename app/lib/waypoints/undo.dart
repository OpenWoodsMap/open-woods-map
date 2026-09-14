/// Reversing one edit against the list as it stands now, rather than restoring a
/// snapshot of the list as it was.
///
/// Undo used to call `replaceAll` with everything captured before the edit. That
/// reverses the edit correctly only if nothing has happened since, and messages
/// queued rather than replaced, so tapping the undo on an older one was easy —
/// and it silently discarded every waypoint added, edited or deleted in between.
/// A season's work is stored here, so that is not a tolerable way to lose it.
///
/// These rebuild from the current list and touch only what the edit itself
/// touched. The snapshot is still taken, but only as a record of the order things
/// were in, never as the state to return to.
library;

import 'waypoint_store.dart';

/// Puts [removed] back, in the positions [before] had them in.
///
/// Order comes from [before], because a restored waypoint belongs where it was
/// and not at the end of the list. Everything else comes from [current]: an item
/// edited since keeps the edit, an item added since survives, and an item deleted
/// since by something other than this edit stays deleted — this undoes one
/// delete, not every delete that followed it.
List<Waypoint> restoreDeleted({
  required List<Waypoint> current,
  required List<Waypoint> before,
  required List<Waypoint> removed,
}) {
  final live = {for (final item in current) item.id: item};
  final restorable = {
    for (final item in removed)
      if (!live.containsKey(item.id)) item.id: item,
  };
  final placed = <String>{};
  final out = <Waypoint>[
    for (final item in before)
      if ((live[item.id] ?? restorable[item.id]) case final found?)
        if (placed.add(item.id)) found,
  ];
  // Added since the delete, so they have no place in [before]. They go last
  // rather than being dropped, which is what restoring the snapshot did to them.
  out.addAll(current.where((item) => !placed.contains(item.id)));
  return out;
}

/// Puts [tag] back on the waypoints it was taken off, where it used to sit.
///
/// [positions] maps a waypoint id to the index the tag held among that
/// waypoint's tags, so undo restores the order instead of appending the tag to
/// the end of each list. Nothing else about the waypoints is touched: one deleted
/// since is absent from [current] and stays gone, one renamed since keeps its new
/// name, and one that has had the tag added back by hand is left alone rather
/// than given it twice.
List<Waypoint> restoreTag({
  required List<Waypoint> current,
  required String tag,
  required Map<String, int> positions,
}) => [
      for (final item in current)
        if (positions[item.id] case final at? when !item.tags.contains(tag))
          item.copyWith(
            tags: [...item.tags]..insert(at.clamp(0, item.tags.length), tag),
          )
        else
          item,
    ];
