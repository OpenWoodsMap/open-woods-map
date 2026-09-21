import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/data/models.dart';
import 'package:open_woods_map/map/land_info.dart';
import 'package:open_woods_map/map/spot_card.dart';

LandFeature feature(String layerId, Map<String, dynamic> properties) =>
    LandFeature(layerId: layerId, properties: properties, geometry: const {});

LandInfo infoWith(List<LandFeature> hits) => LandInfo(
      latitude: 45.53467,
      longitude: -75.85012,
      hits: hits,
      attribution: 'test',
    );

LoadedLayer layer(String id, String label, {String? defaultName}) => LoadedLayer(
      manifest: LayerManifest(
        id: id,
        label: label,
        path: 'overlays/$id.geojson',
        featureCount: 1,
      ),
      metadata: {if (defaultName != null) 'default_name': defaultName},
      sourceUri: 'file:///tmp/$id.geojson',
    );

void main() {
  group('what one line about a spot may say', () {
    test('names the tenure under the tap', () {
      final summary = spotSummary(
        infoWith([
          feature('crown_land', {'name': 'Crown land', 'basis': 'tenure_only'}),
        ]),
        {'crown_land': layer('crown_land', 'Crown land')},
      );
      expect(summary.headline, 'Crown land');
      // The same amber sentence the full card shows for the 52% of Crown land
      // the atlas states no position on.
      expect(summary.status, 'General rules apply, no local policy');
      expect(summary.closed, isFalse);
    });

    test('falls back to the layer default where a feature is unnamed', () {
      final summary = spotSummary(
        infoWith([feature('crown_land', {})]),
        {'crown_land': layer('crown_land', 'Crown', defaultName: 'Crown land')},
      );
      expect(summary.headline, 'Crown land');
    });

    // The reason the status line exists. A glance at "Crown land" on ground a
    // game preserve closes would read as a yes, so the refusal has to survive
    // into the card shown before anyone opens the full sheet.
    test('a closure outranks the tenure under it', () {
      final summary = spotSummary(
        infoWith([
          feature('crown_land', {'name': 'Crown land', 'hunting_allowed': true}),
          feature('game_preserve', {
            'name': 'Somewhere Crown Game Preserve',
            'hunting_allowed': false,
            'basis': 'fwca_s9',
          }),
        ]),
        {
          'crown_land': layer('crown_land', 'Crown land'),
          'game_preserve': layer('game_preserve', 'Game preserve'),
        },
      );
      expect(summary.headline, 'Somewhere Crown Game Preserve');
      expect(summary.status, 'Hunting not permitted');
      expect(summary.closed, isTrue);
    });

    // Algonquin, which is where this was found: the regulation opens a part of
    // the park described in words the province never mapped. A card that showed
    // only the park's name said nothing about that at all.
    test('a condition travels too, not only a refusal', () {
      final summary = spotSummary(
        infoWith([
          feature('parks', {
            'name': 'Algonquin Provincial Park',
            'basis': 'reg663_part3_partial',
          }),
        ]),
        {'parks': layer('parks', 'Parks')},
      );
      expect(summary.headline, 'Algonquin Provincial Park');
      expect(summary.status, 'Open in part of this park only');
      expect(summary.closed, isFalse);
    });

    test('an occupied Crown parcel says who may turn you away', () {
      final summary = spotSummary(
        infoWith([
          feature('crown_disposition', {
            'name': 'Land use permit',
            'basis': 'disposition_occupied',
          }),
        ]),
        {'crown_disposition': layer('crown_disposition', 'Occupied Crown')},
      );
      expect(summary.status, 'Occupied — the holder may refuse entry');
    });

    // A WMU is the only thing in the land-use list that is not a landholding.
    // On unmapped private ground it is often the only hit, and leading with it
    // answered "whose land is this" with a hunting district.
    test('a unit never leads, because it is not a landholding', () {
      final summary = spotSummary(
        infoWith([feature('wmu', {'wmu_id': '64B'})]),
        {'wmu': layer('wmu', 'Wildlife management unit')},
      );
      expect(summary.headline, 'Nothing on record here');
      expect(summary.detail, 'WMU 64B');
    });

    test('a unit rides along behind the tenure it sits under', () {
      final summary = spotSummary(
        infoWith([
          feature('wmu', {'wmu_id': '57'}),
          feature('crown_land', {'name': 'Crown land'}),
        ]),
        {
          'wmu': layer('wmu', 'Wildlife management unit'),
          'crown_land': layer('crown_land', 'Crown land'),
        },
      );
      expect(summary.headline, 'Crown land');
      expect(summary.detail, 'WMU 57');
    });

    test('a closure still leads over both', () {
      final summary = spotSummary(
        infoWith([
          feature('wmu', {'wmu_id': '57'}),
          feature('crown_land', {'name': 'Crown land'}),
          feature('game_preserve', {
            'name': 'Somewhere Crown Game Preserve',
            'hunting_allowed': false,
            'basis': 'fwca_s9',
          }),
        ]),
        {
          'wmu': layer('wmu', 'Wildlife management unit'),
          'crown_land': layer('crown_land', 'Crown land'),
          'game_preserve': layer('game_preserve', 'Game preserve'),
        },
      );
      expect(summary.headline, 'Somewhere Crown Game Preserve');
      expect(summary.status, 'Hunting not permitted');
      expect(summary.detail, 'WMU 57');
      expect(summary.closed, isTrue);
    });

    test('a closure names the authority to argue with', () {
      final federal = spotSummary(
        infoWith([
          feature('federal_closure', {
            'name': 'Somewhere Migratory Bird Sanctuary',
            'hunting_allowed': false,
            'basis': 'mbs_closed',
          }),
        ]),
        {'federal_closure': layer('federal_closure', 'Federal closure')},
      );
      expect(federal.headline, 'Somewhere Migratory Bird Sanctuary');
      expect(federal.status, 'No hunting — federal protected area');
    });

    // No record and no permission are different answers, and this is the line
    // most likely to be read as the second one.
    test('nothing mapped says nothing is on record, not that it is open', () {
      final summary = spotSummary(infoWith([]), const {});
      expect(summary.headline, 'Nothing on record here');
      expect(summary.closed, isFalse);
      expect(summary.headline.toLowerCase(), isNot(contains('allowed')));
      expect(summary.headline.toLowerCase(), isNot(contains('permitted')));
    });

    test('no pack is a gap in our data, worded as one', () {
      expect(SpotSummary.noData.headline, contains('No province data'));
      expect(SpotSummary.noData.closed, isFalse);
    });

    // Nothing here may ever look like a green light. The full card is the only
    // place allowed to say hunting is permitted, because only there do the basis,
    // the quoted regulation and the coverage caveats travel with the sentence.
    test('a permission does not travel to this card', () {
      for (final permitted in [
        {'name': 'Crown land', 'hunting_allowed': true},
        {'name': 'Somewhere Conservation Reserve', 'basis': 'ppcra_s15_3'},
      ]) {
        final summary = spotSummary(
          infoWith([feature('crown_land', permitted)]),
          {'crown_land': layer('crown_land', 'Crown land')},
        );
        expect(
          summary.status,
          isNull,
          reason: 'a yes belongs only beside its basis and its quote',
        );
        expect(summary.headline, permitted['name']);
      }
    });

    test('nothing this card can say sounds like permission', () {
      // Every wording reachable from the verdicts this card is allowed to
      // repeat, checked as a set rather than one case at a time: a new
      // permissive basis added upstream would otherwise arrive here unnoticed.
      const bases = [
        'tenure_only',
        'reg663_part3_partial',
        'reg663_part3_unlisted',
        'ca_permit',
        'conservation_permission',
        'reserve_permission',
        'dnd_closed',
        'nwa_waterfowl',
        'nwa_no_entry',
        'nwa_closed',
        'mbs_unverified',
        'disposition_occupied',
        'disposition_mining',
      ];
      for (final basis in bases) {
        final summary = spotSummary(
          infoWith([feature('crown_land', {'name': 'Somewhere', 'basis': basis})]),
          {'crown_land': layer('crown_land', 'Crown land')},
        );
        final said = '${summary.headline} ${summary.status}'.toLowerCase();
        for (final green in ['is permitted', 'you may hunt', 'open to hunt']) {
          expect(said, isNot(contains(green)), reason: basis);
        }
      }
    });
  });

  group('the card itself', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      SpotSummary summary = const SpotSummary('Crown land'),
      VoidCallback? onLandInfo,
      VoidCallback? onSaveWaypoint,
      VoidCallback? onDismiss,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpotCard(
            latitude: 45.53467,
            longitude: -75.85012,
            summary: summary,
            onLandInfo: onLandInfo,
            onSaveWaypoint: onSaveWaypoint ?? () {},
            onDismiss: onDismiss ?? () {},
          ),
        ),
      ),
    );

    testWidgets('says where and what, and offers both actions', (tester) async {
      await pumpCard(tester, onLandInfo: () {});
      expect(find.text('Crown land'), findsOneWidget);
      expect(find.text('45.53467, -75.85012'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Land info'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Waypoint'), findsOneWidget);
    });

    testWidgets('the unit sits with the coordinates, not the headline',
        (tester) async {
      await pumpCard(
        tester,
        summary: const SpotSummary('Crown land', detail: 'WMU 57'),
        onLandInfo: () {},
      );
      expect(find.text('Crown land'), findsOneWidget);
      expect(find.textContaining('WMU 57'), findsOneWidget);
      expect(
        find.textContaining('45.53467, -75.85012'),
        findsOneWidget,
        reason: 'the unit joins the coordinate line rather than replacing it',
      );
    });

    testWidgets('each action reports separately', (tester) async {
      var info = 0;
      var saved = 0;
      var dismissed = 0;
      await pumpCard(
        tester,
        onLandInfo: () => info++,
        onSaveWaypoint: () => saved++,
        onDismiss: () => dismissed++,
      );
      await tester.tap(find.text('Land info'));
      await tester.tap(find.text('Waypoint'));
      await tester.tap(find.byTooltip('Dismiss'));
      expect((info, saved, dismissed), (1, 1, 1));
    });

    // Disabled rather than missing, so the row of buttons is the same shape
    // whether or not a pack is installed.
    testWidgets('Land info is disabled with no province data', (tester) async {
      await pumpCard(tester, summary: SpotSummary.noData);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Land info'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('No province data for this spot'), findsOneWidget);
      // A waypoint is the user's own and needs nothing downloaded.
      final waypoint = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Waypoint'),
      );
      expect(waypoint.onPressed, isNotNull);
    });

    testWidgets('a refusal shows the verdict and a barred icon', (tester) async {
      const red = Color(0xFFB3261E);
      await pumpCard(
        tester,
        summary: const SpotSummary(
          'Somewhere Crown Game Preserve',
          status: 'Hunting not permitted',
          statusColour: red,
          closed: true,
        ),
      );
      expect(find.text('Somewhere Crown Game Preserve'), findsOneWidget);
      final status = tester.widget<Text>(find.text('Hunting not permitted'));
      expect(status.style?.color, red);
      final context = tester.element(find.byType(SpotCard));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.block)).color,
        Theme.of(context).colorScheme.error,
      );
    });

    testWidgets('a plain spot shows no verdict line at all', (tester) async {
      await pumpCard(tester, onLandInfo: () {});
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
      expect(find.byIcon(Icons.block), findsNothing);
    });
  });
}
