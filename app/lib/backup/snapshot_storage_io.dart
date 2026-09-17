import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const snapshotsSupported = true;

/// Snapshots live in their own directory so the Android backup rules can name
/// it. Copying the app's own safety net into the operating system's backup
/// would multiply the upload by however many snapshots are kept, to protect
/// copies of a file that is already being backed up beside them.
Future<Directory> _root() async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory(path.join(documents.path, 'snapshots'));
}

const _prefix = 'waypoints-';

/// Gzipped, because a snapshot is mostly coordinates and they compress by
/// roughly an order of magnitude. A season of tracks is megabytes, and keeping
/// several uncompressed copies of that on a phone to guard against a mis-tap
/// would be taking back more than the feature gives. `gzip` is in `dart:io`, so
/// this costs no dependency, and a snapshot stays readable by hand with any
/// ordinary tool.
const _suffix = '.geojson.gz';

String _fileName(String id) => '$_prefix$id$_suffix';

/// Newest first. Ids are timestamps written so that lexical order is
/// chronological order, which is what lets this sort without opening anything.
Future<List<String>> listSnapshotIds() async {
  final root = await _root();
  if (!root.existsSync()) return const [];
  final ids = <String>[];
  for (final entity in root.listSync()) {
    if (entity is! File) continue;
    final name = path.basename(entity.path);
    if (!name.startsWith(_prefix) || !name.endsWith(_suffix)) continue;
    ids.add(
      name.substring(_prefix.length, name.length - _suffix.length),
    );
  }
  ids.sort();
  return ids.reversed.toList();
}

Future<void> writeSnapshot(String id, String contents) async {
  final root = await _root();
  await root.create(recursive: true);
  final file = File(path.join(root.path, _fileName(id)));
  // Staged and renamed, as the waypoints file is. A snapshot truncated by a
  // process death is worse than no snapshot: it is a restore point that looks
  // available and is not.
  final staging = File('${file.path}.writing');
  await staging.writeAsBytes(
    gzip.encode(utf8.encode(contents)),
    flush: true,
  );
  await staging.rename(file.path);
}

Future<String?> readSnapshot(String id) async {
  final file = File(path.join((await _root()).path, _fileName(id)));
  if (!file.existsSync()) return null;
  return utf8.decode(gzip.decode(await file.readAsBytes()));
}

Future<int> snapshotBytes(String id) async {
  final file = File(path.join((await _root()).path, _fileName(id)));
  return file.existsSync() ? file.length() : 0;
}

Future<void> deleteSnapshot(String id) async {
  final file = File(path.join((await _root()).path, _fileName(id)));
  if (file.existsSync()) await file.delete();
}
