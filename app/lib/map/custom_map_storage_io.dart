import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const customMapFilesSupported = true;

/// Imported maps get their own directory for the same reason snapshots and
/// offline packs do: so the Android backup rules can name it and leave it out.
/// A bought map is megabytes of JPEG, it is re-importable from the file the user
/// still has, and the backup quota is twenty-five megabytes for everything.
Future<Directory> _root(String id) async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory(path.join(documents.path, 'custom_maps', id));
}

/// Writes the images of one map, replacing anything already there.
///
/// Hrefs come out of a KML inside a zip and are joined onto a directory here, so
/// the result is checked to be inside that directory before anything is written.
/// The href is validated on the way in as well; this is the second lock on the
/// same door, because the cost of being wrong is writing into the app's private
/// storage at a path an archive chose.
Future<void> writeCustomMapImages(
  String id,
  Map<String, Uint8List> images,
) async {
  final root = await _root(id);
  if (root.existsSync()) await root.delete(recursive: true);
  await root.create(recursive: true);
  final within = path.canonicalize(root.path);
  for (final entry in images.entries) {
    final file = File(path.join(root.path, entry.key));
    if (!path.canonicalize(file.path).startsWith(within)) {
      throw ArgumentError('Image path escapes the map directory: ${entry.key}');
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(entry.value, flush: true);
  }
}

Future<Uint8List?> readCustomMapImage(String id, String href) async {
  final file = File(path.join((await _root(id)).path, href));
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}

Future<void> deleteCustomMapFiles(String id) async {
  final root = await _root(id);
  if (root.existsSync()) await root.delete(recursive: true);
}

Future<int> customMapBytes(String id) async {
  final root = await _root(id);
  if (!root.existsSync()) return 0;
  var total = 0;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File) total += entity.lengthSync();
  }
  return total;
}
