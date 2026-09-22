import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/data/land_credit.dart';
import 'package:open_woods_map/data/models.dart';

LandFeature hit(String layerId) =>
    LandFeature(layerId: layerId, properties: const {}, geometry: const {});

LoadedLayer layer(
  String id, {
  String? license,
  String? licenseUrl,
  String? attribution,
}) =>
    LoadedLayer(
      manifest: LayerManifest(
        id: id,
        label: id,
        path: 'overlays/$id.geojson',
        featureCount: 1,
      ),
      metadata: {
        if (license != null) 'license': license,
        if (licenseUrl != null) 'license_url': licenseUrl,
        if (attribution != null) 'attribution': attribution,
      },
      sourceUri: 'file:///tmp/$id.geojson',
    );

const onUrl = 'https://www.ontario.ca/page/open-government-licence-ontario';
const canadaUrl = 'https://open.canada.ca/en/open-government-licence-canada';

String credit(
  List<LandFeature> hits,
  Map<String, LoadedLayer> layers, {
  String provinceLicense = 'OGL-Ontario',
  String provinceLicenseUrl = onUrl,
}) =>
    landCredit(
      hits,
      layers,
      provinceLicense: provinceLicense,
      provinceLicenseUrl: provinceLicenseUrl,
    );

void main() {
  // The bug this function exists for. Four of Ontario's sixteen layers are
  // federal, so a card built from the province manifest credited Ontario for
  // boundaries Ontario did not publish, and every Quebec card named a licence
  // none of its layers use.
  group('the card credits the sources it is showing', () {
    test('a federal layer is credited federally, not to the province', () {
      expect(
        credit(
          [hit('first_nations')],
          {
            'first_nations': layer(
              'first_nations',
              license: 'Open Government Licence – Canada',
              licenseUrl: canadaUrl,
            ),
          },
        ),
        'Open Government Licence – Canada. $canadaUrl',
      );
    });

    test('a card spanning two licences names both', () {
      final lines = credit(
        [hit('crown_land'), hit('defence_land')],
        {
          'crown_land': layer('crown_land',
              license: 'OGL-Ontario', licenseUrl: onUrl),
          'defence_land': layer('defence_land',
              license: 'Open Government Licence – Canada',
              licenseUrl: canadaUrl),
        },
      ).split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, contains('OGL-Ontario'));
      expect(lines.last, contains('Canada'));
    });

    // Ontario's own overlays spell one licence two ways while pointing at the
    // same document, so a card hitting one of each must not read as two
    // obligations.
    test('one licence spelled two ways is credited once', () {
      final credited = credit(
        [hit('crown_land'), hit('crown_disposition')],
        {
          'crown_land': layer('crown_land',
              license: 'OGL-Ontario', licenseUrl: onUrl),
          'crown_disposition': layer('crown_disposition',
              license: 'Open Government Licence – Ontario', licenseUrl: onUrl),
        },
      );
      expect(credited.split('\n'), hasLength(1));
      expect(credited, contains(onUrl));
    });

    test('the same parcel hit twice is credited once', () {
      final credited = credit(
        [hit('crown_land'), hit('crown_land')],
        {
          'crown_land': layer('crown_land',
              license: 'OGL-Ontario', licenseUrl: onUrl),
        },
      );
      expect(credited.split('\n'), hasLength(1));
    });

    // Several of these licences specify the sentence to use, and a paraphrase of
    // a specified statement is not the specified statement.
    test('a source that specified its wording gets that wording', () {
      expect(
        credit(
          [hit('municipalities')],
          {
            'municipalities': layer(
              'municipalities',
              license: 'Statistics Canada Open Licence',
              licenseUrl: 'https://www.statcan.gc.ca/en/reference/licence',
              attribution: 'Contains information licensed under the '
                  'Statistics Canada Open Licence.',
            ),
          },
        ),
        'Contains information licensed under the Statistics Canada Open Licence.',
      );
    });
  });

  group('when the layers cannot say', () {
    // Ground no layer covers is still the province's pack, so the credit does
    // not vanish — but nothing is invented for it either.
    test('a tap that hits nothing falls back to the province', () {
      expect(
        credit(const [], const {}),
        'OGL-Ontario. $onUrl',
      );
    });

    test('Quebec falls back to its own licence, not Ontario\'s', () {
      expect(
        credit(
          const [],
          const {},
          provinceLicense: 'CC-BY 4.0 / Données ouvertes du Québec',
          provinceLicenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        ),
        'CC-BY 4.0 / Données ouvertes du Québec. '
        'https://creativecommons.org/licenses/by/4.0/',
      );
    });

    // What an empty layer's metadata says about its licence. Crediting "n/a"
    // would be worse than crediting the province.
    test('a layer whose licence is n/a is not credited as one', () {
      expect(
        credit(
          [hit('municipal_forest')],
          {'municipal_forest': layer('municipal_forest', license: 'n/a')},
        ),
        'OGL-Ontario. $onUrl',
      );
    });

    test('a hit on a layer we hold no metadata for falls back', () {
      expect(credit([hit('mystery')], const {}), 'OGL-Ontario. $onUrl');
    });

    test('a licence with no URL is named without a dangling full stop', () {
      expect(
        credit(
          [hit('odd')],
          {'odd': layer('odd', license: 'Some Open Licence')},
        ),
        'Some Open Licence.',
      );
    });
  });
}
