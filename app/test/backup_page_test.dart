import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/backup/backup_page.dart';
import 'package:open_woods_map/backup/backup_record.dart';
import 'package:open_woods_map/backup/snapshot_store.dart';
import 'package:open_woods_map/waypoints/tag_style.dart';
import 'package:open_woods_map/waypoints/waypoint_colour.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Documents extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Documents(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

Waypoint point(String id, {String name = 'Stand'}) => Waypoint(
  id: id,
  name: name,
  latitude: 45.5,
  longitude: -77.5,
  notes: '',
  createdAt: DateTime.utc(2026, 9, 10),
);

void main() {
  late Directory root;
  late WaypointStore store;
  late TagStyleStore tagStyles;
  late SnapshotStore snapshots;
  late BackupRecord record;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('owm-backup-page');
    PathProviderPlatform.instance = _Documents(root.path);
    SharedPreferences.setMockInitialValues({});
    snapshots = SnapshotStore();
    store = WaypointStore(snapshots: snapshots);
    tagStyles = TagStyleStore();
    record = BackupRecord();
    await record.load();
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to reap with the rest of the temp directory.
    }
  });

  /// Lets real disk work finish, then lets the frames catch up.
  ///
  /// This page reads and writes files, and `pumpAndSettle` alone will not do:
  /// inside a widget test the clock is fake, so a pending `File` operation never
  /// completes and the loading spinner turns until the ten-minute timeout. Only
  /// `runAsync` hands control back to the real event loop.
  Future<void> settle(WidgetTester tester) async {
    for (var turn = 0; turn < 12; turn++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Runs disk work from inside a test body, where the fake clock would
  /// otherwise leave it pending forever.
  Future<void> onDisk(WidgetTester tester, Future<void> Function() work) =>
      tester.runAsync(work).then((_) {});

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackupPage(
          store: store,
          tagStyles: tagStyles,
          snapshots: snapshots,
          record: record,
        ),
      ),
    );
    await settle(tester);
  }

  group('what the page says about where things stand', () {
    testWidgets('an empty list is not a warning', (tester) async {
      await pumpPage(tester);
      expect(find.textContaining('nothing to back up'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    // The one case where somebody genuinely stands to lose everything and has
    // no way of knowing it.
    testWidgets('waypoints and no backup ever is a warning', (tester) async {
      await onDisk(tester, () => store.replaceAll([point('a')]));
      await pumpPage(tester);
      expect(find.text('You have never made a backup.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('a recent backup is stated, not warned about', (tester) async {
      await onDisk(tester, () async {
        await store.replaceAll([point('a')]);
        await record.record(when: DateTime.now(), items: 1);
      });
      await pumpPage(tester);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
      expect(find.textContaining('nothing has changed since'), findsOneWidget);
    });

    testWidgets('having added since is counted, not scolded', (tester) async {
      await onDisk(tester, () async {
        await store.replaceAll([point('a'), point('b'), point('c')]);
        await record.record(when: DateTime.now(), items: 1);
      });
      await pumpPage(tester);
      expect(find.textContaining('added 2 since'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('nothing to back up means nothing to press', (tester) async {
      await pumpPage(tester);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Make a backup file'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('the copies on the phone', () {
    testWidgets('an empty history says so rather than showing nothing', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.textContaining('None yet'), findsOneWidget);
    });

    testWidgets('each copy says what is in it', (tester) async {
      await onDisk(tester, () => snapshots.preserve([point('a'), point('b')]));
      await pumpPage(tester);
      expect(find.textContaining('2 waypoints'), findsWidgets);
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('forgetting one removes it', (tester) async {
      await onDisk(tester, () => snapshots.preserve([point('a')]));
      await pumpPage(tester);
      await tester.tap(find.byTooltip('Forget this copy'));
      await settle(tester);
      expect(find.textContaining('None yet'), findsOneWidget);
    });
  });

  group('restoring', () {
    setUp(() async {
      await withClock(
        Clock.fixed(DateTime.utc(2026, 9, 1)),
        () => snapshots.preserve([point('old1'), point('old2')]),
      );
      await store.replaceAll([point('now1')]);
    });

    /// Opens the confirmation for the one stored copy.
    ///
    /// Settles rather than pumps, because reading the copy off disk happens
    /// before the dialog is built.
    Future<void> tapRestore(WidgetTester tester) async {
      await tester.tap(find.text('Restore'));
      await settle(tester);
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await settle(tester);
    }

    testWidgets('says what it will replace before doing it', (tester) async {
      await pumpPage(tester);
      await tapRestore(tester);
      expect(find.text('Restore 2 waypoints?'), findsOneWidget);
      // Scoped to the dialog: the page behind it explains that restoring
      // replaces rather than merges, so an unscoped finder matches the advice
      // as well as the warning and cannot tell which one is on screen.
      Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(text),
      );
      expect(inDialog('replaces your list'), findsOneWidget);
      // The reassurance that makes the button safe to press, and it has to be
      // true: the current list is preserved before anything is written.
      expect(inDialog('kept as a copy'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await pumpPage(tester);
      await tapRestore(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(store.items.map((item) => item.id), ['now1']);
    });

    testWidgets('confirming replaces the list', (tester) async {
      await pumpPage(tester);
      await tapRestore(tester);
      await confirm(tester);
      expect(store.items.map((item) => item.id), ['old1', 'old2']);
    });

    // Restoring the wrong file is exactly when somebody needs a way back, and
    // the rate limit that keeps ordinary editing from filling the history would
    // otherwise be in the way at the one moment it must not be.
    testWidgets('the list it replaced becomes a copy of its own', (
      tester,
    ) async {
      await pumpPage(tester);
      await tapRestore(tester);
      await confirm(tester);

      final kept = await tester.runAsync(() => snapshots.list());
      expect(kept, hasLength(2));
      expect(kept!.first.describes, '1 waypoint');
    });

    testWidgets('a snapshot leaves tag styling alone', (tester) async {
      await onDisk(
        tester,
        () => tagStyles.setStyle(
          'ridge',
          const TagStyle(colour: WaypointColour.orange),
        ),
      );
      await pumpPage(tester);
      await tapRestore(tester);
      expect(find.textContaining('left as they are'), findsOneWidget);
      await confirm(tester);
      expect(tagStyles.styleFor('ridge').colour, WaypointColour.orange);
    });
  });

  group('what a backup record can honestly claim', () {
    test('never having backed up is said plainly', () {
      expect(BackupRecord().summary(3), 'You have never made a backup.');
      expect(BackupRecord().needsAttention(3), isTrue);
    });

    test('an old backup wants attention, a recent one does not', () async {
      final now = DateTime.utc(2026, 9, 17);
      await withClock(Clock.fixed(now), () async {
        final recent = BackupRecord();
        await recent.record(
          when: now.subtract(const Duration(days: 3)),
          items: 2,
        );
        expect(recent.needsAttention(2), isFalse);

        final stale = BackupRecord();
        await stale.record(
          when: now.subtract(const Duration(days: 90)),
          items: 2,
        );
        expect(stale.needsAttention(2), isTrue);
        expect(stale.summary(2), contains('months ago'));
      });
    });

    // Nothing to lose is not a problem to be warned about.
    test('an empty list never wants attention', () {
      expect(BackupRecord().needsAttention(0), isFalse);
      expect(BackupRecord().summary(0), contains('nothing to back up'));
    });

    test('a shrunken list is described without alarm', () async {
      final now = DateTime.utc(2026, 9, 17);
      await withClock(Clock.fixed(now), () async {
        final backup = BackupRecord();
        await backup.record(when: now, items: 9);
        expect(backup.summary(4), contains('5 fewer'));
      });
    });
  });
}
