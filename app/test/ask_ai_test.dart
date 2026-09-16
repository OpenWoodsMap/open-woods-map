import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/data/models.dart';
import 'package:open_woods_map/map/ask_ai.dart';
import 'package:open_woods_map/map/land_info.dart';

LandFeature feature(String layerId, Map<String, dynamic> properties) =>
    LandFeature(layerId: layerId, properties: properties, geometry: const {});

LandInfo infoWith(List<LandFeature> hits) => LandInfo(
      latitude: 45.123456,
      longitude: -79.654321,
      hits: hits,
      attribution: 'test',
    );

ProvinceManifest manifestFor(String id, String name, {DateTime? built}) =>
    ProvinceManifest(
      id: id,
      name: name,
      version: '0.13.0',
      license: 'OGL-Ontario',
      licenseUrl: '',
      layers: const [],
      built: built,
    );

LoadedLayer layer(Map<String, dynamic> metadata) => LoadedLayer(
      manifest: const LayerManifest(
        id: 'x',
        label: 'x',
        path: 'x',
        featureCount: 1,
      ),
      metadata: metadata,
      sourceUri: '',
    );

void main() {
  final ontario = manifestFor('on', 'Ontario', built: DateTime.utc(2026, 9, 1));

  group('the facts block reports absence as absence', () {
    // A blank line reads as "nothing there", and "nothing there" is a claim
    // about the ground. The whole point of handing these facts to an AI is that
    // the AI is told what the app does not know, so it cannot quietly fill the
    // gap and hand the answer back sounding settled.
    test('an unidentified WMU and municipality say so', () {
      final facts = landFacts(info: infoWith([]), manifest: ontario);
      expect(facts, contains('Wildlife management unit: not identified'));
      expect(facts, contains('Local government: not identified'));
    });

    test('no land-use polygon is not read as private land or as permission',
        () {
      final facts = landFacts(info: infoWith([]), manifest: ontario);
      expect(facts, contains('absence of record'));
      expect(facts, contains('not permission to hunt'));
    });

    test('no closure is reported against the installed data, not the world',
        () {
      final facts = landFacts(info: infoWith([]), manifest: ontario);
      expect(facts, contains('none in the installed data'));
    });

    test('what the app never maps anywhere is listed', () {
      final facts = landFacts(info: infoWith([]), manifest: ontario);
      for (final unmapped in ['by-laws', 'signage', 'leases', 'private']) {
        expect(facts, contains(unmapped));
      }
    });

    test('a pack with no build stamp does not get a guessed date', () {
      final facts = landFacts(
        info: infoWith([]),
        manifest: manifestFor('on', 'Ontario'),
      );
      expect(facts, contains('build date unknown'));
    });

    test('the pack is described as a bundled copy rather than live', () {
      final facts = landFacts(info: infoWith([]), manifest: ontario);
      expect(facts, contains('0.13.0'));
      expect(facts, contains('built 2026-09-01'));
      expect(facts, contains('not the live source'));
    });
  });

  group('the facts block says what the card says', () {
    test('a parcel carries the same verdict the badge shows', () {
      final facts = landFacts(
        info: infoWith([
          feature('crown_land', {
            'name': 'Unpatented Crown land',
            'hunting_allowed': null,
            'basis': 'tenure_only',
          }),
        ]),
        manifest: ontario,
      );
      // The wording huntingVerdict returns for tenure_only, not a paraphrase of
      // it. A prompt describing this parcel differently from the card above it
      // would break the one thing that makes the question answerable.
      expect(facts, contains('General rules apply, no local policy'));
    });

    test('a closure carries its own headline and citation', () {
      final facts = landFacts(
        info: infoWith([
          feature('game_preserve', {
            'name': 'Nonquon Crown Game Preserve',
            'hunting_allowed': false,
            'basis': 'fwca_s9',
            'citation': 'FWCA s. 9',
          }),
        ]),
        manifest: ontario,
      );
      expect(facts, contains('No hunting — Crown game preserve'));
      expect(facts, contains('Nonquon Crown Game Preserve'));
      expect(facts, contains('FWCA s. 9'));
    });

    // The card shows a unit no hunting badge, and neither does this. Passing a
    // WMU through huntingVerdict yields "hunting status not on record", which
    // about an administrative unit reads as the app not knowing whether you may
    // hunt in it. Seasons are listed per unit and the app holds them.
    test('a WMU is named as a unit, with no verdict and no tenure', () {
      final facts = landFacts(
        info: infoWith([feature('wmu', {'wmu_id': '47'})]),
        manifest: ontario,
        layers: {'wmu': layer(const {'tenure': 'should not appear'})},
      );
      expect(facts, contains('WMU 47'));
      expect(facts, contains('unit open seasons are set by'));
      expect(facts, isNot(contains('should not appear')));
      expect(facts, isNot(contains('Hunting status not on record')));
    });

    test('an approximate outline carries its caution', () {
      final facts = landFacts(
        info: infoWith([
          feature('first_nations', {
            'name': 'Somewhere IR',
            'boundary_accuracy': 'approximate',
            'basis': 'reserve_permission',
          }),
        ]),
        manifest: ontario,
      );
      expect(facts, contains('approximate'));
      expect(facts, contains('may include private land'));
    });

    test('a partly opened park says the open part is unmapped', () {
      final facts = landFacts(
        info: infoWith([
          feature('parks', {
            'name': 'Algonquin',
            'hunting_extent': 'part',
            'basis': 'reg663_part3_partial',
          }),
        ]),
        manifest: ontario,
      );
      expect(facts, contains('Open in part of this park only'));
      expect(facts, contains('not published as a boundary'));
    });
  });

  // Paraphrasing a carve-out drops exactly the part that decides legality on
  // the ground, so the quote travels whole however long it is.
  test('a regulation is quoted verbatim and never truncated', () {
    const text = 'That part of the Township of Anywhere lying east of the '
        'centreline of Highway 11, excepting those parts posted with signs '
        'prohibiting the discharge of firearms, and excepting the part in the '
        'geographic Township of Elsewhere.';
    final facts = landFacts(
      info: infoWith([
        feature('parks', {
          'name': 'Somewhere Provincial Park',
          'reg_text': text,
          'reg_schedule': 42,
          'hunting_allowed': true,
        }),
      ]),
      manifest: ontario,
      layers: {
        'parks': layer(const {
          'hunting_source': 'O. Reg. 663/98 Part 3',
          'currency_date': '2026-01-01',
        }),
      },
    );
    expect(facts, contains(text));
    expect(facts, contains('excepting those parts posted with signs'));
    expect(facts, contains('Schedule 42'));
    expect(facts, contains('O. Reg. 663/98 Part 3'));
  });

  test('an opening written into the Act travels alongside the regulation', () {
    final facts = landFacts(
      info: infoWith([
        feature('parks', {
          'name': 'Algonquin',
          'reg_text': 'Schedule 42 wording',
          'statute_text': 'Bruton and Clyde wording',
          'statute_citation': 'PPCRA s. 15 (2)',
        }),
      ]),
      manifest: ontario,
    );
    expect(facts, contains('Schedule 42 wording'));
    expect(facts, contains('Bruton and Clyde wording'));
    expect(facts, contains('PPCRA s. 15 (2)'));
  });

  group('Sunday gun hunting', () {
    // Only Ontario packs carry the schedule. Volunteering a line about Sunday
    // hunting where the app has no view would invite the model to supply one,
    // and that answer is the province's to give.
    test('is left out entirely where the pack has no schedule', () {
      final facts = landFacts(info: infoWith([]), manifest: ontario);
      expect(facts, isNot(contains('Sunday')));
    });

    test('an unlisted municipality is reported as the prohibition it is', () {
      final facts = landFacts(
        info: infoWith([]),
        manifest: ontario,
        layers: {'sunday_gun': layer(const {'citation': 'O. Reg. 663/98'})},
      );
      expect(facts, contains('Not permitted here on Sundays'));
      expect(facts, contains('O. Reg. 665/98'));
    });

    test('the uncertain band along the rivers stays uncertain', () {
      final facts = landFacts(
        info: infoWith([feature('sunday_gun', {'near_divide': true})]),
        manifest: ontario,
        layers: {'sunday_gun': layer(const {})},
      );
      expect(facts, contains('Too close to the rivers to say'));
      expect(facts, isNot(contains('Permitted here')));
    });
  });

  test('a layer known to be incomplete contributes its gap', () {
    final facts = landFacts(
      info: infoWith([]),
      manifest: ontario,
      layers: {
        'conservation_authority': layer(const {
          'coverage_incomplete': true,
          'coverage_note': 'CPCAD holds only what each authority reported.',
        }),
      },
    );
    expect(facts, contains('Known gaps'));
    expect(facts, contains('CPCAD holds only what each authority reported.'));
  });

  group('every prompt', () {
    for (final flavour in AskAi.values) {
      test('${flavour.name} carries the facts inside markers', () {
        final prompt = askAiPrompt(
          flavour,
          info: infoWith([]),
          manifest: ontario,
        );
        expect(prompt, contains('FACTS FROM OPENWOODSMAP — BEGIN'));
        expect(prompt, contains('FACTS FROM OPENWOODSMAP — END'));
        expect(
          prompt,
          contains(landFacts(info: infoWith([]), manifest: ontario)),
        );
      });

      test('${flavour.name} says the app is not the answer', () {
        final prompt = askAiPrompt(
          flavour,
          info: infoWith([]),
          manifest: ontario,
        );
        expect(prompt, contains('not as the answer'));
        expect(prompt, contains('out of date or incomplete'));
      });

      // The one instruction that has to survive every rewording of these
      // prompts. Fluency is what makes an AI dangerous here, and this is the
      // sentence that tells it a gap beats a guess.
      test('${flavour.name} tells the AI to admit what it does not know', () {
        final prompt = askAiPrompt(
          flavour,
          info: infoWith([]),
          manifest: ontario,
        );
        expect(
          prompt.toLowerCase(),
          anyOf(
            contains('say so'),
            contains('say they are silent'),
            contains('cannot verify'),
          ),
        );
      });
    }
  });

  group('the draft enquiry', () {
    test('goes to the verified Ontario address', () {
      final prompt = askAiPrompt(
        AskAi.enquiry,
        info: infoWith([]),
        manifest: ontario,
      );
      expect(prompt, contains('nrisc@ontario.ca'));
      expect(prompt, contains('1-800-387-7011'));
    });

    test('goes to the verified Quebec address', () {
      final prompt = askAiPrompt(
        AskAi.enquiry,
        info: infoWith([]),
        manifest: manifestFor('qc', 'Quebec'),
      );
      expect(
        prompt,
        contains('renseignements.faune@environnement.gouv.qc.ca'),
      );
    });

    // An address is the one thing in this feature that cannot be guessed: a
    // wrong one produces a question nobody answers and a hunter who believes
    // they asked.
    test('invents no address for a province with no verified one', () {
      final prompt = askAiPrompt(
        AskAi.enquiry,
        info: infoWith([]),
        manifest: manifestFor('zz', 'Nowhere'),
      );
      expect(prompt, isNot(contains('@')));
      expect(prompt, contains('do not have a verified address'));
      expect(prompt, contains('Help me identify the right one'));
    });

    test('asks for the facts verbatim and for a written reply', () {
      final prompt = askAiPrompt(
        AskAi.enquiry,
        info: infoWith([]),
        manifest: ontario,
      );
      expect(prompt, contains('verbatim'));
      expect(prompt, contains('in writing'));
    });

    // The user is asking a question, not making a case. An email that asserts
    // the law and turns out to be wrong is worse than no email: it is a written
    // record of them claiming something false.
    test('forbids the user asserting a legal conclusion', () {
      final prompt = askAiPrompt(
        AskAi.enquiry,
        info: infoWith([]),
        manifest: ontario,
      );
      expect(prompt, contains('asking, not arguing'));
    });

    test('adds nothing about the user or the place that is not in the facts',
        () {
      final prompt = askAiPrompt(
        AskAi.enquiry,
        info: infoWith([]),
        manifest: ontario,
      );
      expect(prompt, contains('not in the facts'));
    });
  });

  group('the second opinion', () {
    test('is the only flavour marked experimental', () {
      expect(
        AskAi.values.where((flavour) => flavour.isExperimental),
        [AskAi.secondOpinion],
      );
    });

    test('demands a citation for every assertion', () {
      final prompt = askAiPrompt(
        AskAi.secondOpinion,
        info: infoWith([]),
        manifest: ontario,
      );
      expect(prompt, contains('Cite the specific Act, regulation, section'));
      expect(prompt, contains('not present your answer as authoritative'));
    });

    test('sends the user back to the authority by name', () {
      final prompt = askAiPrompt(
        AskAi.secondOpinion,
        info: infoWith([]),
        manifest: ontario,
      );
      expect(prompt, contains('NRISC'));
    });
  });

  test('the explain flavour offers the repository rather than assert trust', () {
    final prompt = askAiPrompt(
      AskAi.explain,
      info: infoWith([]),
      manifest: ontario,
    );
    expect(prompt, contains('github.com/OpenWoodsMap/open-woods-map'));
  });

  // Nothing here fails loudly if it rots, so the shape is asserted instead: a
  // blank field or a dropped source would otherwise ship unnoticed.
  group('every authority on file', () {
    for (final entry in wildlifeAuthorities.entries) {
      test('${entry.key} is complete and cites where it came from', () {
        final authority = entry.value;
        expect(authority.name, isNotEmpty);
        expect(authority.email, contains('@'));
        expect(authority.phone, isNotEmpty);
        expect(authority.hours, isNotEmpty);
        expect(authority.source, startsWith('https://'));
      });
    }

    test('covers both provinces the app ships', () {
      expect(wildlifeAuthorities.keys, containsAll(['on', 'qc']));
    });
  });
}
