/// The list of maps the user added, and what it takes to add one.
///
/// A [ChangeNotifier] like the other settings, because the map has to redraw the
/// moment one is toggled: the panel sits over the map being adjusted, and making
/// somebody close it to see the effect makes an opacity slider impossible to
/// judge.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_map.dart';
import 'custom_map_storage_stub.dart'
    if (dart.library.io) 'custom_map_storage_io.dart' as storage;

/// What an import ended up with, so the confirmation can be specific.
///
/// [asked] is how many images the KML listed and `map.overlays.length` is how
/// many were actually in the archive. When they differ the map still works and
/// still has holes, and the user is the only one who can tell whether the
/// missing corner is the corner they care about — so the count is reported rather
/// than smoothed over.
class CustomMapImport {
  const CustomMapImport({required this.map, required this.asked});

  final FileMap map;
  final int asked;

  int get kept => map.overlays.length;
  bool get isComplete => kept == asked;
}

class CustomMapStore extends ChangeNotifier {
  static const _key = 'custom_maps';

  /// A phone is not going to carry many bought maps, and the panel is a list
  /// somebody has to read. The cap is here so the failure is a message rather
  /// than a slow map with a list nobody can find anything in.
  static const maxMaps = 12;

  List<CustomMap> _maps = const [];

  List<CustomMap> get maps => _maps;

  /// The visible ones, in the order they should be drawn — the order they were
  /// added, so a map added later goes on top of one added earlier.
  List<CustomMap> get drawn =>
      [for (final map in _maps) if (map.visible) map];

  bool get canImportFiles => storage.customMapFilesSupported;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _maps = decodeCustomMaps(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> setVisible(String id, bool visible) =>
      _replace(id, (map) => map.copyWith(visible: visible));

  Future<void> setOpacity(String id, double opacity) =>
      _replace(id, (map) => map.copyWith(opacity: opacity));

  Future<void> rename(String id, String name) =>
      _replace(id, (map) => map.copyWith(name: name.trim()));

  Future<void> addTiles({
    required String name,
    required String template,
    required String credit,
  }) async {
    if (_maps.length >= maxMaps) {
      throw const CustomMapUnreadable('That is as many maps as this will hold.');
    }
    final checked = checkTileUrl(template);
    final usable = checked.template;
    if (usable == null) {
      throw CustomMapUnreadable(checked.complaint!);
    }
    _maps = [
      ..._maps,
      TileMap(
        id: _newId(),
        name: name.trim().isEmpty ? 'Custom tiles' : name.trim(),
        credit: credit.trim(),
        template: usable,
      ),
    ];
    notifyListeners();
    await _save();
  }

  /// Unpacks a KMZ and keeps its images, or throws [CustomMapUnreadable] with
  /// something the user can act on.
  ///
  /// Nothing reaches disk until the whole file has been understood. A half
  /// imported map is worse than a refused one: it draws, so it looks like it
  /// worked, and only the missing corner of the park says otherwise.
  Future<CustomMapImport> importArchive(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (!canImportFiles) {
      throw const CustomMapUnreadable(
        'Importing a map file needs a device that can store it.',
      );
    }
    if (_maps.length >= maxMaps) {
      throw const CustomMapUnreadable('That is as many maps as this will hold.');
    }

    // Checked by magic number rather than by letting the decoder fail, because
    // it does not reliably fail: handed a plain KML it returns an archive with
    // nothing in it, and the complaint that came out then was about a missing
    // KML when the user's actual mistake was exporting the wrong format.
    if (bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      throw const CustomMapUnreadable(
        'This file is not a KMZ. A KMZ is a zip holding a KML and its map '
        'images; a plain KML on its own has no pictures in it.',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const CustomMapUnreadable(
        'This KMZ will not open. It may have been truncated by the download.',
      );
    }

    final parsed = readCustomMapKml(_kmlFrom(archive));

    // Hrefs are matched case-insensitively. Zip entries are case sensitive and
    // KML hrefs written by hand routinely are not, which on a phone shows up as
    // a map that imported cleanly and draws nothing.
    final files = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) files[file.name.toLowerCase()] = file;
    }

    final images = <String, Uint8List>{};
    final found = <GroundOverlay>[];
    for (final overlay in parsed.overlays) {
      final file = files[overlay.href.toLowerCase()];
      if (file == null) continue;
      images[overlay.href] = Uint8List.fromList(file.content as List<int>);
      found.add(overlay);
    }

    if (found.isEmpty) {
      throw const CustomMapUnreadable(
        'The map images this file refers to are not inside it. It may have been '
        'unzipped and rezipped without them.',
      );
    }

    final id = _newId();
    await storage.writeCustomMapImages(id, images);
    final map = FileMap(
      id: id,
      name: parsed.name?.trim().isNotEmpty == true
          ? parsed.name!.trim()
          : _nameFromFile(fileName),
      // Falls back to the file name rather than to nothing. An imported map has
      // an author, and a blank credit line would read as the app claiming it.
      credit: parsed.credit?.trim().isNotEmpty == true
          ? parsed.credit!.trim()
          : 'Imported from $fileName',
      overlays: found,
    );
    _maps = [..._maps, map];
    notifyListeners();
    await _save();
    return CustomMapImport(map: map, asked: parsed.overlays.length);
  }

  Future<Uint8List?> imageBytes(String id, String href) =>
      storage.readCustomMapImage(id, href);

  Future<int> bytesOnDisk(String id) => storage.customMapBytes(id);

  Future<void> remove(String id) async {
    _maps = [for (final map in _maps) if (map.id != id) map];
    notifyListeners();
    await _save();
    // After the list is written, so a process death between the two leaves
    // orphaned images rather than a row pointing at images that are gone.
    await storage.deleteCustomMapFiles(id);
  }

  Future<void> _replace(String id, CustomMap Function(CustomMap) change) async {
    _maps = [
      for (final map in _maps) if (map.id == id) change(map) else map,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_maps.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, encodeCustomMaps(_maps));
    }
  }

  /// Timestamp plus a counter: ids have to be unique and are also used as
  /// directory names, and two imports in the same millisecond would otherwise
  /// share a directory.
  static var _counter = 0;
  static String _newId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${_counter++}';
}

/// Finds the KML in a KMZ.
///
/// `doc.kml` by name first, because that is what Google Earth and Garmin write
/// and a KMZ may also carry a stray KML in a subdirectory. Failing that, the
/// first one anywhere in the archive.
String _kmlFrom(Archive archive) {
  ArchiveFile? found;
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final name = file.name.toLowerCase();
    if (name == 'doc.kml') {
      found = file;
      break;
    }
    if (found == null && name.endsWith('.kml')) found = file;
  }
  if (found == null) {
    throw const CustomMapUnreadable(
      'There is no KML inside this file, so nothing says where the images '
      'belong on the ground.',
    );
  }
  try {
    return utf8.decode(found.content as List<int>, allowMalformed: true);
  } catch (error) {
    throw CustomMapUnreadable('The KML inside this file will not read: $error');
  }
}

String _nameFromFile(String fileName) {
  final stem = fileName.split(RegExp(r'[/\\]')).last.replaceAll(
        RegExp(r'\.kmz$', caseSensitive: false),
        '',
      );
  return stem.isEmpty ? 'Imported map' : stem.replaceAll(RegExp('[-_]+'), ' ');
}
