import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/waypoints/undo.dart';
import 'package:open_woods_map/waypoints/waypoint_icon.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

Waypoint wp(String id, {String? name, List<String> tags = const []}) => Waypoint(
      id: id,
      name: name ?? 'Point $id',
      latitude: 45.5,
      longitude: -77.5,
      notes: '',
      createdAt: DateTime.utc(2026, 9, 10),
      icon: WaypointIcon.stand,
      tags: tags,
    );

List<String> ids(List<Waypoint> items) => [for (final i in items) i.id];

void main() {
  group('undoing a delete', () {
    test('puts the waypoint back where it was, not at the end', () {
      final before = [wp('a'), wp('b'), wp('c')];
      final restored = restoreDeleted(
        current: [wp('a'), wp('c')],
        before: before,
        removed: [wp('b')],
      );
      expect(ids(restored), ['a', 'b', 'c']);
    });

    // The bug this replaced: undo restored a snapshot of the whole list, so a
    // waypoint saved between the delete and the undo was silently thrown away.
    // Messages queue, so tapping a stale undo was easy to do.
    test('keeps a waypoint added since the delete', () {
      final restored = restoreDeleted(
        current: [wp('a'), wp('c'), wp('new')],
        before: [wp('a'), wp('b'), wp('c')],
        removed: [wp('b')],
      );
      expect(ids(restored), ['a', 'b', 'c', 'new']);
    });

    test('keeps an edit made to another waypoint since the delete', () {
      final restored = restoreDeleted(
        current: [wp('a', name: 'Renamed'), wp('c')],
        before: [wp('a'), wp('b'), wp('c')],
        removed: [wp('b')],
      );
      expect(restored.first.name, 'Renamed');
      expect(ids(restored), ['a', 'b', 'c']);
    });

    // This undoes one delete. Something deleted afterwards was a separate
    // decision, and reviving it would be inventing an intention the user never
    // had.
    test('does not revive a waypoint deleted by something else since', () {
      final restored = restoreDeleted(
        current: [wp('a')],
        before: [wp('a'), wp('b'), wp('c')],
        removed: [wp('b')],
      );
      expect(ids(restored), ['a', 'b']);
    });

    test('tapping undo twice does not duplicate the waypoint', () {
      final before = [wp('a'), wp('b')];
      final once = restoreDeleted(
        current: [wp('a')],
        before: before,
        removed: [wp('b')],
      );
      final twice = restoreDeleted(
        current: once,
        before: before,
        removed: [wp('b')],
      );
      expect(ids(twice), ['a', 'b']);
    });

    test('a whole tagful comes back in its original order', () {
      final before = [wp('a'), wp('b'), wp('c'), wp('d')];
      final restored = restoreDeleted(
        current: [wp('b')],
        before: before,
        removed: [wp('a'), wp('c'), wp('d')],
      );
      expect(ids(restored), ['a', 'b', 'c', 'd']);
    });
  });

  group('undoing a tag removal', () {
    test('puts the tag back where it sat in the list', () {
      final restored = restoreTag(
        current: [wp('a', tags: ['ridge', 'water'])],
        tag: 'deer',
        positions: {'a': 1},
      );
      expect(restored.single.tags, ['ridge', 'deer', 'water']);
    });

    test('leaves waypoints the removal never touched alone', () {
      final restored = restoreTag(
        current: [wp('a', tags: ['ridge']), wp('b', tags: ['ridge'])],
        tag: 'deer',
        positions: {'a': 0},
      );
      expect(restored[0].tags, ['deer', 'ridge']);
      expect(restored[1].tags, ['ridge']);
    });

    // Restoring the snapshot would have reverted this rename too.
    test('keeps a rename made since the removal', () {
      final restored = restoreTag(
        current: [wp('a', name: 'Renamed', tags: const [])],
        tag: 'deer',
        positions: {'a': 0},
      );
      expect(restored.single.name, 'Renamed');
      expect(restored.single.tags, ['deer']);
    });

    test('does not give the tag twice to a waypoint that got it back by hand',
        () {
      final restored = restoreTag(
        current: [wp('a', tags: ['deer'])],
        tag: 'deer',
        positions: {'a': 0},
      );
      expect(restored.single.tags, ['deer']);
    });

    test('a waypoint deleted since is simply not restored', () {
      final restored = restoreTag(
        current: [wp('b', tags: const [])],
        tag: 'deer',
        positions: {'a': 0, 'b': 0},
      );
      expect(ids(restored), ['b']);
      expect(restored.single.tags, ['deer']);
    });

    // The recorded index can be past the end if tags were removed since. Better
    // to put it back at the end than to throw away the restore.
    test('an index past the end of a shortened tag list still restores', () {
      final restored = restoreTag(
        current: [wp('a', tags: const [])],
        tag: 'deer',
        positions: {'a': 3},
      );
      expect(restored.single.tags, ['deer']);
    });
  });
}
