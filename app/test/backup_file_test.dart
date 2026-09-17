import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/backup/backup_file.dart';
import 'package:open_woods_map/waypoints/tag_style.dart';
import 'package:open_woods_map/waypoints/waypoint_colour.dart';
import 'package:open_woods_map/waypoints/waypoint_icon.dart';
import 'package:open_woods_map/waypoints/waypoint_store.dart';

Waypoint point(
  String id, {
  String name = 'Stand',
  List<String> tags = const [],
  WaypointIcon icon = WaypointIcon.pin,
  WaypointColour? colour,
}) => Waypoint(
  id: id,
  name: name,
  latitude: 45.26195,
  longitude: -77.62932,
  notes: '',
  createdAt: DateTime.utc(2026, 9, 10, 16, 30),
  icon: icon,
  tags: tags,
  colour: colour,
);

Waypoint walk(String id) => Waypoint(
  id: id,
  name: 'Morning walk',
  latitude: 45.1,
  longitude: -77.1,
  notes: '',
  createdAt: DateTime.utc(2026, 9, 10),
  track: const [
    TrackPoint(latitude: 45.1, longitude: -77.1),
    TrackPoint(latitude: 45.2, longitude: -77.2),
  ],
);

final taken = DateTime.utc(2026, 9, 17, 12);

String backupOf(
  List<Waypoint> waypoints, {
  Map<String, TagStyle> styles = const {},
}) => writeBackup(waypoints: waypoints, tagStyles: styles, createdAt: taken);

void main() {
  group('a backup is still a GeoJSON', () {
    test('any other tool sees an ordinary FeatureCollection', () {
      final json = jsonDecode(backupOf([point('a'), walk('b')]))
          as Map<String, dynamic>;
      expect(json['type'], 'FeatureCollection');
      expect(json['features'], hasLength(2));
    });

    // The claim in the file's own doc comment, and the reason a backup can be
    // read by a tool that has never heard of this app. Worth asserting rather
    // than trusting, because breaking it is invisible until somebody tries.
    test('our member sits beside the standard ones, not inside them', () {
      final json = jsonDecode(backupOf([point('a')])) as Map<String, dynamic>;
      expect(json.keys, contains(backupMember));
      final feature = (json['features'] as List).single as Map;
      expect(feature['properties'], isNot(contains(backupMember)));
    });

    // A backup of a season's tracks runs to megabytes. Anything working out
    // what the file is should not have to read all of it first.
    test('what the file is comes before what is in it', () {
      final text = backupOf([walk('a')]);
      expect(text.indexOf(backupMember), lessThan(text.indexOf('"features"')));
    });
  });

  group('what an export drops and a backup keeps', () {
    test('tag styling survives the round trip', () {
      final styles = {
        'ridge': const TagStyle(
          icon: WaypointIcon.stand,
          colour: WaypointColour.orange,
        ),
        'water': const TagStyle(colour: WaypointColour.blue),
      };
      final restored = readBackup(backupOf([point('a')], styles: styles));
      expect(restored.tagStyles['ridge']?.icon, WaypointIcon.stand);
      expect(restored.tagStyles['ridge']?.colour, WaypointColour.orange);
      expect(restored.tagStyles['water']?.colour, WaypointColour.blue);
      expect(restored.tagStyles['water']?.icon, isNull);
    });

    test('a tag that was never styled is absent rather than blank', () {
      final text = backupOf(
        [point('a')],
        styles: {'plain': const TagStyle()},
      );
      final ours = (jsonDecode(text) as Map)[backupMember] as Map;
      expect(ours, isNot(contains('tagStyles')));
    });

    test('the waypoints themselves come back whole', () {
      final restored = readBackup(
        backupOf([
          point('a', name: 'Stand', tags: ['ridge'], colour: WaypointColour.red),
          walk('b'),
        ]),
      );
      expect(restored.waypoints, hasLength(2));
      final stand = restored.waypoints.first;
      expect(stand.id, 'a');
      expect(stand.name, 'Stand');
      expect(stand.tags, ['ridge']);
      expect(stand.colour, WaypointColour.red);
      expect(restored.waypoints.last.isTrack, isTrue);
    });
  });

  group('reading a file we did not write', () {
    const foreign = '''
{"type":"FeatureCollection","features":[{"type":"Feature",
"properties":{"title":"Camp"},
"geometry":{"type":"Point","coordinates":[-77.6,45.2]}}]}''';

    // Not an error. Someone restoring from a CalTopo export should get their
    // waypoints; they simply get no styling, because the file has none.
    test('restores its waypoints and claims no styling', () {
      final restored = readBackup(foreign);
      expect(restored.waypoints, hasLength(1));
      expect(restored.tagStyles, isEmpty);
    });

    // The UI needs to be able to say so before the restore rather than let the
    // user find out afterwards that their tag colours went.
    test('is distinguishable from one of ours', () {
      expect(readBackup(foreign).isOwnBackup, isFalse);
      expect(readBackup(backupOf([point('a')])).isOwnBackup, isTrue);
      expect(readBackup(backupOf([point('a')])).createdAt, taken);
    });

    test('something that is not GeoJSON at all fails loudly', () {
      // Silence here would be indistinguishable from restoring an empty
      // backup, and only one of the two is a failure the user must hear about.
      expect(() => readBackup('not json'), throwsA(isA<Object>()));
    });
  });

  group('a damaged backup gives up as little as it can', () {
    String withStyles(String styles) =>
        '{"type":"FeatureCollection","$backupMember":'
        '{"backup":1,"created":"2026-09-17T12:00:00.000Z","tagStyles":$styles},'
        '"features":[]}';

    test('one unreadable style does not cost the others', () {
      final restored = readBackup(
        withStyles('{"ridge":{"colour":"orange"},"broken":"not an object"}'),
      );
      expect(restored.tagStyles['ridge']?.colour, WaypointColour.orange);
      expect(restored.tagStyles, isNot(contains('broken')));
    });

    // A colour this build has never heard of is what a backup from a later
    // build looks like. It should not take the tag with it.
    test('a style naming something unknown is dropped, not fatal', () {
      final restored = readBackup(
        withStyles('{"ridge":{"colour":"ultraviolet"},"water":{"colour":"blue"}}'),
      );
      expect(restored.tagStyles, isNot(contains('ridge')));
      expect(restored.tagStyles['water']?.colour, WaypointColour.blue);
    });
  });
}
