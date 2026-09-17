import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/backup/snapshot_store.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Documents extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Documents(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

Waypoint point(String id) => Waypoint(
  id: id,
  name: 'Stand $id',
  latitude: 45.5,
  longitude: -77.5,
  notes: '',
  createdAt: DateTime.utc(2026, 9, 10),
);

List<Waypoint> points(int count) =>
    [for (var i = 0; i < count; i++) point('$i')];

final start = DateTime.utc(2026, 9, 17, 8);

void main() {
  late Directory root;
  late SnapshotStore snapshots;

  setUp(() {
    root = Directory.systemTemp.createTempSync('owm-snapshots');
    PathProviderPlatform.instance = _Documents(root.path);
    snapshots = SnapshotStore();
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to reap with the rest of the temp directory.
    }
  });

  /// Runs [action] as if the clock read [at].
  Future<T> at<T>(DateTime moment, Future<T> Function() action) =>
      withClock(Clock.fixed(moment), action);

  Future<void> replace(
    DateTime moment, {
    required List<Waypoint> before,
    required List<Waypoint> after,
  }) => at(
    moment,
    () => snapshots.recordReplacement(before: before, after: after),
  );

  group('what is worth preserving', () {
    // The first save of a user's life replaces nothing. A snapshot of an empty
    // list is a restore point that loses everything.
    test('an empty previous state is not kept', () async {
      await replace(start, before: const [], after: points(1));
      expect(await snapshots.list(), isEmpty);
    });

    test('a removal keeps the state from before it', () async {
      await replace(start, before: points(5), after: points(2));
      final kept = await snapshots.list();
      expect(kept, hasLength(1));
      expect(kept.single.describes, '5 waypoints');
      expect(kept.single.takenAt, start);
    });

    test('an ordinary edit is kept too, but only now and then', () async {
      await replace(start, before: points(3), after: points(4));
      expect(await snapshots.list(), hasLength(1));

      // Nothing was lost, so there is no hurry. A list that only grows should
      // not spend its five slots on five minutes of typing.
      await replace(
        start.add(const Duration(hours: 2)),
        before: points(4),
        after: points(5),
      );
      expect(await snapshots.list(), hasLength(1));

      await replace(
        start.add(const Duration(hours: 21)),
        before: points(5),
        after: points(6),
      );
      expect(await snapshots.list(), hasLength(2));
    });
  });

  group('deleting in a sitting', () {
    // The case the quiet window exists for. Somebody clearing up deletes
    // repeatedly, and every deletion is a removal, so without the window five
    // taps would spend all five slots and push out the history from before the
    // tidying began.
    test('repeated removals reuse the first snapshot', () async {
      await replace(start, before: points(9), after: points(8));
      await replace(
        start.add(const Duration(minutes: 2)),
        before: points(8),
        after: points(7),
      );
      await replace(
        start.add(const Duration(minutes: 5)),
        before: points(7),
        after: points(1),
      );

      final kept = await snapshots.list();
      expect(kept, hasLength(1));
      // And the one kept is the most useful of the three: it holds everything
      // the later deletions took, which the later copies do not.
      expect(kept.single.describes, '9 waypoints');
    });

    test('a removal after the quiet window is its own snapshot', () async {
      await replace(start, before: points(9), after: points(8));
      await replace(
        start.add(const Duration(minutes: 11)),
        before: points(8),
        after: points(2),
      );
      expect(await snapshots.list(), hasLength(2));
    });
  });

  group('what it costs', () {
    test('only the newest few are kept', () async {
      for (var turn = 0; turn < SnapshotStore.keep + 3; turn++) {
        await replace(
          start.add(Duration(hours: turn * 2)),
          before: points(20 - turn),
          after: points(1),
        );
      }
      final kept = await snapshots.list();
      expect(kept, hasLength(SnapshotStore.keep));
      // Newest first, and the oldest have gone rather than the newest.
      expect(kept.first.takenAt.isAfter(kept.last.takenAt), isTrue);
    });

    // Snapshots are mostly repeated coordinates, and a season of tracks is
    // megabytes. Keeping several uncompressed would take back more than the
    // feature gives.
    test('a snapshot is smaller than the text it holds', () async {
      final many = [
        for (var i = 0; i < 400; i++)
          Waypoint(
            id: '$i',
            name: 'Morning walk $i',
            latitude: 45.5,
            longitude: -77.5,
            notes: 'A note that repeats itself a great deal, as notes do.',
            createdAt: DateTime.utc(2026, 9, 10),
          ),
      ];
      await replace(start, before: many, after: const []);
      final kept = await snapshots.list();
      expect(kept.single.bytes, greaterThan(0));
      expect(kept.single.bytes, lessThan(10000));
    });
  });

  group('getting it back', () {
    test('a snapshot restores what was in it', () async {
      await replace(start, before: points(3), after: const []);
      final kept = await snapshots.list();
      final contents = await snapshots.read(kept.single.id);
      expect(contents, isNotNull);
      expect(contents!.waypoints.map((item) => item.id), ['0', '1', '2']);
    });

    test('one that will not open is null rather than a crash', () async {
      await replace(start, before: points(3), after: const []);
      final kept = await snapshots.list();
      File(
        '${root.path}/snapshots/waypoints-${kept.single.id}.geojson.gz',
      ).writeAsBytesSync([0, 1, 2, 3]);
      expect(await snapshots.read(kept.single.id), isNull);
      // And the row still lists, so one bad file does not hide the good ones.
      expect((await snapshots.list()).single.describes, 'unreadable');
    });

    test('deleting one leaves the rest', () async {
      await replace(start, before: points(3), after: const []);
      await replace(
        start.add(const Duration(days: 1)),
        before: points(2),
        after: const [],
      );
      final kept = await snapshots.list();
      await snapshots.delete(kept.first.id);
      expect(await snapshots.list(), hasLength(1));
    });
  });

  // The ids are timestamps, and the listing sorts them as text rather than
  // opening every file. If those two orders ever disagree the newest snapshot
  // stops being the one offered first, and nothing else would show it.
  test('lexical order of ids is chronological order', () async {
    for (final moment in [
      DateTime.utc(2026, 9, 9, 23),
      DateTime.utc(2026, 9, 10, 1),
      DateTime.utc(2026, 10, 1, 0),
      DateTime.utc(2026, 12, 31, 23, 59),
    ]) {
      await replace(moment, before: points(2), after: const []);
    }
    final kept = await snapshots.list();
    final times = kept.map((snapshot) => snapshot.takenAt).toList();
    expect(times, [
      DateTime.utc(2026, 12, 31, 23, 59),
      DateTime.utc(2026, 10, 1, 0),
      DateTime.utc(2026, 9, 10, 1),
      DateTime.utc(2026, 9, 9, 23),
    ]);
  });
}
