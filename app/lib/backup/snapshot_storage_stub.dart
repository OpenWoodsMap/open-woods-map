const snapshotsSupported = false;

Future<List<String>> listSnapshotIds() async => const [];

Future<void> writeSnapshot(String id, String contents) async {}

Future<String?> readSnapshot(String id) async => null;

Future<int> snapshotBytes(String id) async => 0;

Future<void> deleteSnapshot(String id) async {}
