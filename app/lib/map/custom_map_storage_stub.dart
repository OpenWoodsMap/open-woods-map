import 'dart:typed_data';

const customMapFilesSupported = false;

Future<void> writeCustomMapImages(
  String id,
  Map<String, Uint8List> images,
) =>
    Future.error(
      UnsupportedError('Importing a map file needs a device filesystem.'),
    );

Future<Uint8List?> readCustomMapImage(String id, String href) async => null;

Future<void> deleteCustomMapFiles(String id) async {}

Future<int> customMapBytes(String id) async => 0;
