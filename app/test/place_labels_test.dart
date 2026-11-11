import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/data/gazetteer.dart';
import 'package:open_woods_map/map/place_labels.dart';

/// Real CGNDB names, in the shape `tools/gis/fetch_cgndb.py` writes.
GazetteerIndex index() {
  const records = [
    ('Gariepy Mountains', 'Mountains', 45.7, -77.4),
    ('Mud Lake', 'Lake', 45.0, -76.0),
    ('Alfred Bog', 'Bog', 45.48, -74.78),
    ('Smiths Shanty Hill', 'Hill', 45.75, -77.35),
    ('Big Swamp', 'Swamp', 44.9, -76.3),
    ('Pigeon Rock', 'Rock', 45.1, -76.2),
  ];
  final types = <String>[];
  for (final (_, type, _, _) in records) {
    if (!types.contains(type)) types.add(type);
  }
  return GazetteerIndex.parse(
    jsonEncode({
      'metadata': {
        'province': 'on',
        'province_name': 'Ontario',
        'record_count': records.length,
        'coordinate_scale': 100000,
        'attribution':
            'Contains information licensed under the Open '
            'Government Licence – Canada.',
        'types': types,
        'contexts': [''],
      },
      'names': [for (final r in records) r.$1],
      'type_ids': [for (final r in records) types.indexOf(r.$2)],
      'context_ids': [for (final _ in records) 0],
      'lat_e5': [for (final r in records) (r.$3 * 100000).round()],
      'lon_e5': [for (final r in records) (r.$4 * 100000).round()],
    }),
  );
}

Map<String, String> kindsByName(Map<String, dynamic> collection) => {
  for (final feature in collection['features'] as List)
    (feature['properties'] as Map)['name'] as String:
        (feature['properties'] as Map)['kind'] as String,
};

void main() {
  test('only landforms and wetlands become labels', () {
    expect(kindsByName(placeLabelCollection(index())), {
      'Gariepy Mountains': 'terrain',
      'Alfred Bog': 'wetland',
      'Smiths Shanty Hill': 'terrain',
      'Big Swamp': 'wetland',
    });
  });

  test('a label sits on the CGNDB point, longitude first', () {
    final features = placeLabelCollection(index())['features'] as List;
    final hill = features.firstWhere(
      (f) => (f['properties'] as Map)['name'] == 'Smiths Shanty Hill',
    );
    final coordinates = (hill['geometry'] as Map)['coordinates'] as List;
    expect(coordinates[0], closeTo(-77.35, 1e-9));
    expect(coordinates[1], closeTo(45.75, 1e-9));
  });

  test('the two sets do not overlap', () {
    expect(terrainLabelTypes.intersection(wetlandLabelTypes), isEmpty);
  });

  // Guards the type spellings against what the source actually uses: a set
  // entry that matches nothing in either province is a typo, not a choice.
  test('every chosen type occurs in a real pack index', () {
    final seen = <String>{};
    for (final province in ['on', 'qc']) {
      final file = File('../data/$province/gazetteer/places.json');
      if (!file.existsSync()) continue;
      final metadata =
          (jsonDecode(file.readAsStringSync()) as Map)['metadata'] as Map;
      seen.addAll((metadata['types'] as List).cast<String>());
    }
    if (seen.isEmpty) {
      markTestSkipped('no gazetteer is built under data/');
      return;
    }
    expect(
      {...terrainLabelTypes, ...wetlandLabelTypes}.difference(seen),
      isEmpty,
    );
  });
}
