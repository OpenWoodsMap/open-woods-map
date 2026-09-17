/// Snapshots are not kept on the web.
///
/// The browser build stores waypoints in local storage, which is a handful of
/// megabytes for the whole origin and is cleared by the same "clear site data"
/// the user reaches for when something looks wrong. Several compressed copies of
/// the waypoints file would crowd out the file they exist to protect, and would
/// be wiped by exactly the event worth protecting against. [snapshotsSupported]
/// is false so the UI says there is no history here rather than showing an empty
/// list that looks like nothing has been saved yet.
library;

const snapshotsSupported = false;

Future<List<String>> listSnapshotIds() async => const [];

Future<void> writeSnapshot(String id, String contents) async {}

Future<String?> readSnapshot(String id) async => null;

Future<int> snapshotBytes(String id) async => 0;

Future<void> deleteSnapshot(String id) async {}
