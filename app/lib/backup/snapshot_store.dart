/// Rolling copies of the waypoints file, kept on the device.
///
/// This is the half of backup that guards against the app rather than against
/// losing the phone, and that is the more likely loss. Waypoints mostly
/// disappear because something in here removed them: a bulk delete confirmed
/// too quickly, an import that replaced instead of merged, a file that would not
/// parse. The undo for those is a snackbar, which is gone in four seconds and
/// gone for good once the app is closed.
///
/// Deliberately only the waypoints. Tag styling lives in its own file that no
/// waypoint operation touches — deleting every waypoint carrying "ridge" leaves
/// the styling for "ridge" exactly where it was — so copying it here would guard
/// against nothing. The file backup carries it, because that one has to survive
/// the device going away with both files on it.
library;

import 'package:clock/clock.dart';

import '../waypoints/waypoint_store.dart';
import 'backup_file.dart';
import 'snapshot_storage_stub.dart'
    if (dart.library.io) 'snapshot_storage_io.dart'
    if (dart.library.html) 'snapshot_storage_web.dart' as storage;

/// One stored copy, as the list on screen needs it.
class Snapshot {
  const Snapshot({
    required this.id,
    required this.takenAt,
    required this.bytes,
    required this.describes,
  });

  final String id;
  final DateTime takenAt;

  /// Size on disk, compressed. Shown because a user deciding whether to keep
  /// history is entitled to know what it costs them.
  final int bytes;

  /// "12 waypoints and 3 tracks", read out of the file's own header.
  ///
  /// The point of the list is choosing which copy to go back to, and a column
  /// of identical timestamps tells nobody anything. What people recognise is
  /// the one from before they lost half of them.
  final String describes;
}

class SnapshotStore {
  /// Whether this platform keeps history at all, so the UI can say so plainly
  /// rather than show an empty list that reads as "nothing saved yet".
  bool get supported => storage.snapshotsSupported;

  /// Five is a judgement, not a measurement: enough to cover "I broke it some
  /// time in the last few days and only just noticed", few enough that a user
  /// with a season of tracks is not carrying tens of megabytes of history.
  static const keep = 5;

  /// Below this, a removal reuses the last snapshot instead of taking another.
  ///
  /// Safe because of what the earlier copy contains. Somebody deleting in a
  /// sitting deletes repeatedly, and the state before the first deletion is a
  /// superset of the state before the fifth — so the older snapshot is the more
  /// useful one, and spending all five slots on one sitting would push out the
  /// history from before it.
  static const _quiet = Duration(minutes: 10);

  /// How long before an uneventful edit is worth preserving anyway, so that a
  /// list which only ever grows still has history behind it.
  static const _routine = Duration(hours: 20);

  /// Preserves the state that is about to be replaced, if it is worth keeping.
  ///
  /// Always the previous contents, never the new ones: the new ones are what is
  /// being written to the waypoints file in the same breath, so a copy of them
  /// duplicates a file that already exists. The previous state is the one about
  /// to stop existing anywhere.
  Future<void> recordReplacement({
    required List<Waypoint> before,
    required List<Waypoint> after,
  }) async {
    if (!supported || before.isEmpty) return;
    final latest = await _latestTime();
    // How long to leave it depends on whether anything was lost. A list that
    // only grew can wait; one that shrank is the case this exists for.
    final wait = after.length < before.length ? _quiet : _routine;
    if (latest != null && clock.now().difference(latest) < wait) return;
    await preserve(before);
  }

  /// Keeps a copy whatever the rate limits say.
  ///
  /// For the deliberate wholesale replacements — restoring a backup over the
  /// top of the current list — where waiting out a quiet window would be
  /// protecting exactly the wrong thing.
  Future<void> preserve(List<Waypoint> waypoints) async {
    if (!supported || waypoints.isEmpty) return;
    final now = clock.now();
    await storage.writeSnapshot(
      _idFor(now),
      writeBackup(waypoints: waypoints, tagStyles: const {}, createdAt: now),
    );
    await _prune();
  }

  /// When the newest snapshot was taken, from the file names alone.
  ///
  /// Nothing is opened, decompressed or parsed. This runs on every save the app
  /// makes, and [list] — which does read each file, to say what is in it — would
  /// turn saving one waypoint into decompressing the whole history.
  Future<DateTime?> _latestTime() async {
    for (final id in await storage.listSnapshotIds()) {
      if (_timeOf(id) case final time?) return time;
    }
    return null;
  }

  /// Newest first.
  Future<List<Snapshot>> list() async {
    final snapshots = <Snapshot>[];
    for (final id in await storage.listSnapshotIds()) {
      final takenAt = _timeOf(id);
      if (takenAt == null) continue;
      snapshots.add(
        Snapshot(
          id: id,
          takenAt: takenAt,
          bytes: await storage.snapshotBytes(id),
          describes: await _describe(id),
        ),
      );
    }
    return snapshots;
  }

  /// What is in a snapshot, or null when it cannot be read.
  ///
  /// Null rather than a throw because the caller is offering a restore, and a
  /// snapshot that will not open should grey out one row rather than take down
  /// the screen listing the others.
  Future<BackupContents?> read(String id) async {
    // The read is inside the guard as well as the parse. A snapshot truncated
    // by a process death fails in the decompressor rather than the parser, and
    // that threw straight through this into whatever was drawing the list.
    try {
      final text = await storage.readSnapshot(id);
      return text == null ? null : readBackup(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) => storage.deleteSnapshot(id);

  Future<void> _prune() async {
    final ids = await storage.listSnapshotIds();
    for (final id in ids.skip(keep)) {
      await storage.deleteSnapshot(id);
    }
  }

  /// Read out of the header rather than by counting features, which is why
  /// [writeBackup] puts it before them: this runs once per row every time the
  /// list is drawn, and a season of tracks is megabytes of geometry to walk
  /// past for a number that is written down at the top.
  Future<String> _describe(String id) async {
    final contents = await read(id);
    return contents == null ? 'unreadable' : describeItems(contents.waypoints);
  }

  /// Colons are legal in a file name on the platforms that matter and illegal
  /// on Windows, which is where the tests run. Replacing them keeps one naming
  /// scheme everywhere, and the fixed width is what makes lexical order and
  /// chronological order the same thing.
  static String _idFor(DateTime time) =>
      time.toUtc().toIso8601String().replaceAll(':', '-');

  static DateTime? _timeOf(String id) {
    // Only the two separating the time parts go back; the date's hyphens must
    // stay. Splitting on 'T' is what keeps this from mangling 2026-09-17.
    final parts = id.split('T');
    if (parts.length != 2) return null;
    return DateTime.tryParse('${parts.first}T${parts.last.replaceAll('-', ':')}');
  }
}
