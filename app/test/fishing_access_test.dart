import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/data/models.dart';
import 'package:open_woods_map/map/fishing_access.dart';
import 'package:open_woods_map/map/land_info.dart';
import 'package:open_woods_map/map/overlay_controller.dart';
import 'package:open_woods_map/map/spot_card.dart';

LandFeature site(Map<String, dynamic> properties) => LandFeature(
      layerId: 'fishing_access',
      properties: properties,
      geometry: const {},
    );

LandFeature land(String layerId, Map<String, dynamic> properties) =>
    LandFeature(layerId: layerId, properties: properties, geometry: const {});

const accessLayer = LoadedLayer(
  manifest: LayerManifest(
    id: 'fishing_access',
    label: 'Fishing access',
    path: 'overlays/fishing_access.geojson',
    featureCount: 3,
  ),
  metadata: {
    'kind_labels': {
      'boat_launch': 'Boat launch',
      'enhanced_shoreline': 'Dock or pier',
      'shoreline': 'Shore access',
    },
  },
  sourceUri: 'file:///x',
);

LandInfo infoWith(List<LandFeature> hits) => LandInfo(
      latitude: 45.0,
      longitude: -79.0,
      hits: hits,
      attribution: 'test',
    );

void main() {
  group('what a site says about itself', () {
    test('names the kind and the site where the province named it', () {
      expect(
        fishingAccessTitle(
          site({'kind': 'boat_launch', 'name': 'Jones Lake Access'}),
          accessLayer,
        ),
        'Boat launch · Jones Lake Access',
      );
    });

    test('does not invent a name for the sites the province left unnamed', () {
      expect(
        fishingAccessTitle(site({'kind': 'shoreline'}), accessLayer),
        'Shore access',
      );
    });

    test('falls back to a plain label for a kind it has no word for', () {
      expect(
        fishingAccessTitle(site({'kind': 'something_new'}), accessLayer),
        'Fishing access',
      );
    });

    test('states only what was recorded', () {
      expect(fishingAccessFacts(site({'kind': 'boat_launch'})), isEmpty,
          reason: 'an unrecorded fact is absent, not "Unknown"');
      expect(
        fishingAccessFacts(site({
          'kind': 'boat_launch',
          'parking': true,
          'fee': false,
          'surface': 'concrete',
          'accessible': false,
          'owner': 'private',
        })),
        [
          'Parking',
          'No fee',
          'Concrete ramp',
          'Not wheelchair accessible',
          'Privately owned',
        ],
      );
    });

    test('only a launch has a ramp', () {
      expect(
        fishingAccessFacts(
            site({'kind': 'enhanced_shoreline', 'surface': 'gravel'})),
        ['Gravel surface'],
      );
    });

    test('says when nobody has confirmed the site, rather than staying quiet',
        () {
      expect(fishingAccessVerified(site({})), 'No visit on record');
      expect(
        fishingAccessVerified(site({'verified': '2024-06-01'})),
        'Last confirmed visited 2024-06-01',
      );
    });
  });

  group('a site is not land', () {
    test('never joins the land-use list', () {
      final info = infoWith([
        site({'kind': 'boat_launch'}),
        land('crown_land', {'hunting_allowed': null, 'basis': 'tenure_only'}),
      ]);
      expect(info.fishingAccess, hasLength(1));
      expect(info.landUse.map((f) => f.layerId), ['crown_land']);
    });

    test('is drawn as a point and resolved like one', () {
      expect(OverlayController.isPointLayer('fishing_access'), isTrue);
      expect(OverlayController.isPointLayer('crown_land'), isFalse);
      expect(
        OverlayController.layerOrder.last,
        'fishing_access',
        reason: 'a fill drawn over the dot would take the tap',
      );
    });
  });

  group('the small card', () {
    test('names the site beside the land answer, not instead of it', () {
      final summary = spotSummary(
        infoWith([
          site({'kind': 'boat_launch', 'name': 'Mott Lake Access'}),
          land('game_preserve', {'hunting_allowed': false, 'name': 'Preserve'}),
        ]),
        {'fishing_access': accessLayer},
      );
      expect(summary.access, 'Boat launch · Mott Lake Access');
      expect(summary.closed, isTrue,
          reason: 'a launch inside a preserve is still inside a preserve');
    });

    test('counts the rest when a tap lands on several', () {
      final summary = spotSummary(
        infoWith([
          site({'kind': 'boat_launch'}),
          site({'kind': 'shoreline'}),
        ]),
        {'fishing_access': accessLayer},
      );
      expect(summary.access, 'Boat launch and 1 more');
      expect(summary.headline, 'Nothing on record here');
    });

    test('says nothing about access where there is none', () {
      final summary = spotSummary(infoWith(const []), const {});
      expect(summary.access, isNull);
    });
  });
}
