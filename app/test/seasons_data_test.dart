import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/data/seasons.dart';

/// Checks the season packs that actually ship, not a fixture.
///
/// `ProvinceSeasons.fromJson` is lenient on purpose so one odd row cannot blank
/// the Seasons tab on a phone: an unparseable date becomes 1970, an unknown
/// residency becomes "Resident", and an out-of-range unit index is dropped.
/// That makes "it parses" worthless as a check on a fresh scrape, so these tests
/// read the raw JSON and hold it to what the parser would otherwise paper over.
///
/// `refresh-seasons.yml` runs this file before it opens a pull request, because
/// that pull request is made with the workflow token and so triggers no other
/// checks.
void main() {
  final files = Directory('../data')
      .listSync()
      .whereType<Directory>()
      .map((province) => Directory('${province.path}/seasons'))
      .where((dir) => dir.existsSync())
      .expand((dir) => dir.listSync().whereType<File>())
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('at least one season pack ships', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final segments = file.uri.pathSegments;
    final province = segments[segments.length - 3];
    final name = segments.last;
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rows = (raw['seasons'] as List).cast<Map<String, dynamic>>();
    final units = (raw['units'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, (value as List).cast<num>()));
    final pack = ProvinceSeasons.fromJson(raw);

    group('$province/seasons/$name', () {
      test('names the province and year its path says it covers', () {
        expect(raw['province'], province);
        expect(raw['schema'], 2);
        final stem = name.replaceAll('.json', '');
        if (stem != 'current') expect('${raw['year']}', stem);
      });

      test('covers one regulation year', () {
        expect(pack.validFrom, isNotNull, reason: 'season_year_start');
        expect(pack.validTo, isNotNull, reason: 'season_year_end');
        final days = pack.validTo!.difference(pack.validFrom!).inDays;
        expect(days, inInclusiveRange(360, 370));
      });

      test('says where it came from and that it is a summary', () {
        expect(pack.sourceUrl, startsWith('https://'));
        expect(pack.disclaimer.trim(), isNotEmpty);
      });

      test('has seasons and units to show', () {
        expect(rows, isNotEmpty);
        expect(units, isNotEmpty);
      });

      test('every date is a real date inside the regulation year', () {
        final problems = <String>[];
        for (final (index, row) in rows.indexed) {
          final start = DateTime.tryParse('${row['start']}');
          final end = DateTime.tryParse('${row['end']}');
          final where = '#$index ${row['species']} ${row['label'] ?? ''}';
          if (start == null || end == null) {
            problems.add('$where: unparseable ${row['start']}..${row['end']}');
            continue;
          }
          if (start.isAfter(end)) problems.add('$where: opens after it closes');
          if (start.isBefore(pack.validFrom!) || end.isAfter(pack.validTo!)) {
            problems.add('$where: $start..$end outside the regulation year');
          }
        }
        expect(problems, isEmpty);
      });

      test('every residency is one the app can word', () {
        const known = {'resident', 'non_resident', 'any'};
        final unknown = {
          for (final row in rows)
            if (!known.contains(row['residency'])) '${row['residency']}',
        };
        expect(unknown, isEmpty,
            reason: 'the parser would label these "Resident"');
      });

      test('every species has a display name and a group', () {
        final labels = (raw['species_labels'] as Map).keys.toSet();
        final groups = (raw['species_groups'] as Map).keys.toSet();
        final species = {for (final row in rows) '${row['species']}'};
        expect(species.where((s) => s.isEmpty), isEmpty);
        expect(species.difference(labels), isEmpty);
        expect(species.difference(groups), isEmpty);
        final groupLabels = (raw['group_labels'] as Map).keys.toSet();
        expect(
          (raw['species_groups'] as Map).values.toSet().difference(groupLabels),
          isEmpty,
        );
      });

      test('every unit points only at rows that exist', () {
        final bad = <String>[
          for (final entry in units.entries)
            if (entry.value.isEmpty) '${entry.key}: no rows',
          for (final entry in units.entries)
            for (final index in entry.value)
              if (index < 0 || index >= rows.length) '${entry.key}: $index',
        ];
        expect(bad, isEmpty, reason: 'forUnit silently drops these');
      });

      final wmu = File('../data/$province/overlays/wmu.geojson');
      test(
        'every season unit is a WMU on the map, and every WMU is accounted for',
        () {
          String key(Object? v) =>
              '$v'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          final features = (jsonDecode(wmu.readAsStringSync())
              as Map<String, dynamic>)['features'] as List;
          final onMap = {
            for (final f in features)
              key((f as Map)['properties']['wmu_id']),
          };
          final withSeasons = {for (final unit in units.keys) key(unit)};
          final declaredEmpty = {
            for (final unit in raw['units_without_seasons'] as List? ?? [])
              key(unit),
          };
          expect(withSeasons.difference(onMap), isEmpty,
              reason: 'seasons nobody can tap to see');
          expect(onMap.difference(withSeasons).difference(declaredEmpty),
              isEmpty,
              reason: 'WMUs that would silently show no seasons');
        },
        skip: wmu.existsSync() ? false : 'no WMU layer for $province',
      );
    });
  }
}
