import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/waypoints/bulk_edit.dart';
import 'package:open_woods_map/waypoints/waypoint_colour.dart';
import 'package:open_woods_map/waypoints/waypoint_icon.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

Waypoint _point(
  String id, {
  WaypointIcon icon = WaypointIcon.pin,
  WaypointColour? colour,
  List<String> tags = const [],
}) => Waypoint(
  id: id,
  name: id,
  latitude: 45.0,
  longitude: -77.0,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 8),
  icon: icon,
  colour: colour,
  tags: tags,
);

Waypoint _track(String id, {WaypointColour? colour}) => Waypoint(
  id: id,
  name: id,
  latitude: 45.0,
  longitude: -77.0,
  notes: '',
  createdAt: DateTime.utc(2026, 10, 8),
  colour: colour,
  track: const [
    TrackPoint(latitude: 45.0, longitude: -77.0),
    TrackPoint(latitude: 45.01, longitude: -77.0),
  ],
);

Waypoint _byId(List<Waypoint> items, String id) =>
    items.singleWhere((item) => item.id == id);

void main() {
  group('applyBulkEdit', () {
    test('an empty edit changes nothing', () {
      expect(const BulkEdit().isEmpty, isTrue);
      expect(const BulkEdit(tag: '  ').isEmpty, isTrue);
      expect(applyBulkEdit([_point('a')], const BulkEdit()), isEmpty);
    });

    test('sets the icon on waypoints and never on tracks', () {
      final changed = applyBulkEdit(
        [_point('a'), _track('t')],
        const BulkEdit(icon: WaypointIcon.stand),
      );
      expect(changed.map((item) => item.id), ['a']);
      expect(changed.single.icon, WaypointIcon.stand);
    });

    test('leaves out items that already look like the edit', () {
      final changed = applyBulkEdit(
        [_point('a', icon: WaypointIcon.stand), _point('b')],
        const BulkEdit(icon: WaypointIcon.stand),
      );
      expect(changed.map((item) => item.id), ['b']);
    });

    test('colour reaches tracks too, and can go back to the icon colour', () {
      final items = [
        _point('a', colour: WaypointColour.red),
        _track('t', colour: WaypointColour.red),
        _point('b'),
      ];
      final ownColour = applyBulkEdit(
        items,
        const BulkEdit(changeColour: true),
      );
      expect(ownColour.map((item) => item.id), ['a', 't']);
      expect(ownColour.every((item) => item.colour == null), isTrue);

      final orange = applyBulkEdit(
        items,
        const BulkEdit(changeColour: true, colour: WaypointColour.orange),
      );
      expect(orange.map((item) => item.id), ['a', 't', 'b']);
    });

    test('adds a tag once, normalised, keeping the existing ones', () {
      final changed = applyBulkEdit(
        [_point('a', tags: ['ridge']), _point('b', tags: ['stands'])],
        const BulkEdit(tag: '  Stands '),
      );
      expect(changed.map((item) => item.id), ['a']);
      expect(changed.single.tags, ['ridge', 'stands']);
    });
  });

  test('withEdits swaps changed items in by id and keeps the rest', () {
    final current = [_point('a'), _point('b'), _point('c')];
    final out = withEdits(current, [
      _point('b', icon: WaypointIcon.bear),
    ]);
    expect(out.map((item) => item.id), ['a', 'b', 'c']);
    expect(_byId(out, 'b').icon, WaypointIcon.bear);
    expect(_byId(out, 'a').icon, WaypointIcon.pin);
  });

  group('revertBulkEdit', () {
    const edit = BulkEdit(
      icon: WaypointIcon.stand,
      changeColour: true,
      colour: WaypointColour.orange,
      tag: 'stands',
    );

    test('puts back exactly what the edit changed', () {
      final originals = [
        _point('a', icon: WaypointIcon.camp, tags: ['ridge']),
        _point('b', colour: WaypointColour.red, tags: ['stands']),
      ];
      final edited = withEdits(originals, applyBulkEdit(originals, edit));
      final undone = revertBulkEdit(
        current: edited,
        originals: originals,
        edit: edit,
      );
      expect(_byId(undone, 'a').icon, WaypointIcon.camp);
      expect(_byId(undone, 'a').colour, isNull);
      expect(_byId(undone, 'a').tags, ['ridge']);
      expect(_byId(undone, 'b').icon, WaypointIcon.pin);
      expect(_byId(undone, 'b').colour, WaypointColour.red);
      // It had the tag before the edit, so undo must not take it off.
      expect(_byId(undone, 'b').tags, ['stands']);
    });

    test('keeps what changed since and what was deleted since', () {
      final originals = [_point('a'), _point('b')];
      final edited = withEdits(originals, applyBulkEdit(originals, edit));
      final since = [
        _byId(edited, 'a').copyWith(name: 'Renamed', tags: ['stands', 'new']),
        _point('later'),
      ];
      final undone = revertBulkEdit(
        current: since,
        originals: originals,
        edit: edit,
      );
      expect(undone.map((item) => item.id), ['a', 'later']);
      expect(undone.first.name, 'Renamed');
      expect(undone.first.tags, ['new']);
      expect(undone.first.icon, WaypointIcon.pin);
    });

    test('a colour-only edit leaves icons and tags alone', () {
      final originals = [_point('a', colour: WaypointColour.red)];
      const colourOnly = BulkEdit(changeColour: true);
      final edited = withEdits(
        originals,
        applyBulkEdit(originals, colourOnly),
      );
      final since = [_byId(edited, 'a').copyWith(icon: WaypointIcon.bear)];
      final undone = revertBulkEdit(
        current: since,
        originals: originals,
        edit: colourOnly,
      );
      expect(undone.single.colour, WaypointColour.red);
      expect(undone.single.icon, WaypointIcon.bear);
    });
  });

  group('iconsMatching', () {
    test('matches whole words of the label, forgiving a plural', () {
      expect(iconsMatching(['stand']), [
        WaypointIcon.stand,
        WaypointIcon.towerStand,
      ]);
      expect(iconsMatching(['stands']), contains(WaypointIcon.stand));
      expect(iconsMatching(['Deer']), [WaypointIcon.deer]);
    });

    test('says nothing for short or unmatched hints', () {
      expect(iconsMatching(['']), isEmpty);
      expect(iconsMatching(['or']), isEmpty);
      expect(iconsMatching(['zzz']), isEmpty);
      // Part of a word is not the word: "camper" is not a camp.
      expect(iconsMatching(['camper']), isEmpty);
    });

    test('draws on every hint, the search and the picked tags', () {
      expect(
        iconsMatching(['', 'bear', 'camp']),
        containsAll([WaypointIcon.bear, WaypointIcon.camp]),
      );
    });
  });
}
