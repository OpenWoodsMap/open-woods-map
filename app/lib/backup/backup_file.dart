/// A backup is an export that is allowed to be complete.
///
/// The distinction matters because the two have opposite obligations. An export
/// is a file for somebody else's program, so it carries what that program can
/// understand and nothing more — which is why [WaypointImportExport] writes no
/// tag styling into GPX, KML or GeoJSON, and is right not to. A backup is a file
/// for this app to read back, so anything it omits is data the user quietly
/// loses on the day they need it. Exporting and backing up are not the same act
/// and this app should not pretend otherwise.
///
/// The format is still GeoJSON rather than something private, because a backup
/// outlives the build that wrote it and may well outlive the app. RFC 7946
/// section 6.1 permits foreign members at the top level and requires a reader to
/// ignore what it does not understand, so one file is both: every other tool
/// sees a plain collection of waypoints, and this app sees the styling too.
library;

import 'dart:convert';

import '../waypoints/import_export.dart';
import '../waypoints/tag_style.dart';
import '../waypoints/waypoint_store.dart';

/// The top-level member the styling travels in.
///
/// Namespaced because the top level of a GeoJSON belongs to everybody. A bare
/// `tags` up there would be ours today and somebody else's tomorrow, and the
/// collision would be silent.
const backupMember = 'openwoodsmap';

/// Raised when a later build writes something this one would misread.
///
/// Not a licence to break the format. A backup's whole value is that an old file
/// still restores, so the bar for changing this is that the alternative is
/// losing data, not that a different shape would have been tidier.
const backupSchemaVersion = 1;

/// What came out of a backup file.
class BackupContents {
  const BackupContents({
    required this.waypoints,
    required this.tagStyles,
    this.createdAt,
  });

  final List<Waypoint> waypoints;

  /// Empty for any GeoJSON this app did not write, which is not an error: a file
  /// exported from CalTopo restores its waypoints perfectly well and simply has
  /// no opinion about what a tag looks like.
  final Map<String, TagStyle> tagStyles;

  /// When the backup was taken, or null if the file did not say — which is how
  /// a file from another app, or from a build before backups existed, arrives.
  final DateTime? createdAt;

  /// Whether this file was written as a backup by this app.
  ///
  /// Worth telling the user before a restore. Any GeoJSON can be restored from,
  /// but only one of ours carries styling, so restoring from a foreign file is
  /// a narrower thing than it looks and the UI should say so rather than let
  /// somebody discover it afterwards.
  bool get isOwnBackup => createdAt != null;
}

/// Writes every part of what the user made into one GeoJSON.
///
/// [createdAt] is passed in rather than read from the clock here so the caller
/// can record the same instant it stores as the last-backup time, and so tests
/// are not racing a real clock.
String writeBackup({
  required List<Waypoint> waypoints,
  required Map<String, TagStyle> tagStyles,
  required DateTime createdAt,
}) {
  final collection = WaypointImportExport().geoJsonCollection(waypoints);
  // Filtered before it is tested, not after. A tag can be present with no
  // styling at all — typing one creates it immediately and styling it is a
  // separate act — so testing the map the caller handed over writes an empty
  // object on a file whose every tag is unstyled.
  final styled = {
    for (final entry in tagStyles.entries)
      if (!entry.value.isEmpty) entry.key: entry.value.toJson(),
  };
  // Ahead of `features` deliberately. A backup can run to megabytes of track
  // geometry, and anything diagnosing one — a person with a text editor, or a
  // reader that only takes the head of the file, as the pack loader already
  // does — should not have to walk all of it to find out what it is.
  return const JsonEncoder.withIndent('  ').convert({
    'type': collection['type'],
    backupMember: {
      'backup': backupSchemaVersion,
      'created': createdAt.toUtc().toIso8601String(),
      // Written for a human reading the file, never read back. The features are
      // the count; a stored number could only ever disagree with them.
      'describes': describeItems(waypoints),
      if (styled.isNotEmpty) 'tagStyles': styled,
    },
    'features': collection['features'],
  });
}

/// Reads a backup, or any GeoJSON, back into what the app stores.
///
/// Throws [FormatException] on a file that is not GeoJSON at all, because a
/// restore that silently produced nothing would look identical to restoring an
/// empty backup, and one of those is a failure the user has to know about.
BackupContents readBackup(String text) {
  final waypoints = WaypointImportExport().fromGeoJson(text);
  final json = jsonDecode(text) as Map<String, dynamic>;
  final ours = json[backupMember] as Map<String, dynamic>?;
  if (ours == null) {
    return BackupContents(waypoints: waypoints, tagStyles: const {});
  }
  final styles = ours['tagStyles'] as Map<String, dynamic>? ?? const {};
  return BackupContents(
    waypoints: waypoints,
    // Styling degrades to none rather than failing the restore, matching
    // TagStyleStore.load: the waypoints are the irreplaceable thing here and a
    // colour on a chip is two taps to choose again. Losing the whole file over
    // one unreadable colour would be the wrong trade.
    tagStyles: {
      for (final entry in styles.entries)
        if (_styleOf(entry.value) case final style?) entry.key: style,
    },
    createdAt: DateTime.tryParse(ours['created']?.toString() ?? ''),
  );
}

TagStyle? _styleOf(Object? value) {
  if (value is! Map) return null;
  try {
    final style = TagStyle.fromJson(Map<String, dynamic>.from(value));
    return style.isEmpty ? null : style;
  } catch (_) {
    return null;
  }
}
