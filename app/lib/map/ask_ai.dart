import '../data/models.dart';
import 'land_info.dart';
import 'land_info_sheet.dart';

/// The repository, offered to the AI so it can check how a verdict was reached
/// rather than take the user's word for it.
const _repository = 'https://github.com/OpenWoodsMap/open-woods-map';

/// The office that answers questions about hunting and access on a given piece
/// of ground.
///
/// Hardcoded per province and cited, for the same reason the Sunday gun
/// provisions in [sundayGunVerdict] are: this is administrative fact about a
/// province rather than geometry, it changes on the province's timescale and not
/// the pack's, and an address carried in the pack would leave everybody on an
/// older pack with nowhere to write. [source] is recorded so the next person
/// re-checks it instead of trusting it.
class WildlifeAuthority {
  const WildlifeAuthority({
    required this.name,
    required this.email,
    required this.phone,
    required this.hours,
    required this.source,
  });

  final String name;
  final String email;
  final String phone;
  final String hours;

  /// The province's own contact page this was read off.
  final String source;
}

/// Read off each province's own contact page on 2026-09-16.
///
/// A wrong address here fails silently in the worst way: it produces a question
/// that is never answered and a hunter who believes they asked. Re-check the
/// source before editing rather than correcting one from memory.
const wildlifeAuthorities = <String, WildlifeAuthority>{
  'on': WildlifeAuthority(
    name: 'Natural Resources Information and Support Centre (NRISC), Ontario '
        'Ministry of Natural Resources',
    email: 'nrisc@ontario.ca',
    phone: '1-800-387-7011',
    hours: 'Monday to Friday, 8:30 a.m. to 5:00 p.m. Eastern',
    source: 'https://www.ontario.ca/document/ontario-hunting-regulations-'
        'summary/how-use-this-summary',
  ),
  'qc': WildlifeAuthority(
    name: 'Biodiversité, Faune et Parcs — Service à la clientèle, ministère de '
        "l'Environnement, de la Lutte contre les changements climatiques, de la "
        'Faune et des Parcs',
    email: 'renseignements.faune@environnement.gouv.qc.ca',
    phone: '1-877-346-6763',
    hours: 'Monday, Tuesday, Thursday and Friday 8:30–12:00 and 13:00–16:30, '
        'Wednesday 10:00–12:00 and 13:00–16:30',
    source: 'https://www.quebec.ca/gouvernement/ministeres-organismes/'
        'environnement/coordonnees-structure/coordonnees-generales',
  ),
};

/// What the user wants an AI to do with what the card found.
enum AskAi {
  /// Put the card's records into plain language. The safest of the three: it
  /// asks for a reading of supplied text rather than for law from memory.
  explain,

  /// Help write the question that gets an answer from the authority in writing.
  /// The facts travel verbatim and the AI only supplies the wording, which is
  /// the division of labour this feature is built around: the coordinates and
  /// citations must be exact, and the phrasing is what benefits from being a
  /// person's own rather than a template every recipient learns to skim.
  enquiry,

  /// Check the app's reading against the AI's own knowledge of the legislation.
  /// Marked experimental in the UI, because this is the one flavour whose output
  /// is the model's recollection of law rather than a restatement of supplied
  /// text, and a confident wrong answer here is the failure this app exists to
  /// avoid.
  secondOpinion;

  String get label => switch (this) {
        AskAi.explain => 'Explain these records',
        AskAi.enquiry => 'Draft an email to the authority',
        AskAi.secondOpinion => 'Get a second opinion',
      };

  bool get isExperimental => this == AskAi.secondOpinion;
}

/// What the app knows about the tapped point, in the words the card already
/// uses, for an AI to work from.
///
/// Assembled from the same functions the card renders, so the two cannot drift
/// apart: a prompt that described this point differently from the screen above
/// it would undermine the only thing that makes the question answerable. Every
/// line is either a value from the pack or an explicit statement that the pack
/// has no value, because an omitted line reads as "nothing there" and that is a
/// claim this app does not get to make by staying quiet.
String landFacts({
  required LandInfo info,
  required ProvinceManifest manifest,
  Map<String, LoadedLayer> layers = const {},
}) {
  final lines = <String>[
    'Coordinates: ${info.latitude.toStringAsFixed(6)}, '
        '${info.longitude.toStringAsFixed(6)} (WGS84 decimal degrees)',
    'Province: ${manifest.name}',
    'Wildlife management unit: ${info.wmuId ?? _unknown}',
    'Local government: ${info.localGovernmentLabel ?? _unknown}',
  ];

  if (info.closures.isEmpty) {
    lines.add('Outright closures at this point: none in the installed data');
  } else {
    lines.add('Outright closures at this point:');
    for (final closure in info.closures) {
      final layer = layers[closure.layerId];
      lines.add('  - ${closureHeadline(closure)}: '
          '${featureTitle(closure, layer)}');
      if (closure.properties['citation'] case final citation?) {
        lines.add('    Citation: $citation');
      }
    }
  }

  // Only where the pack carries the schedule. Without the layer the app has no
  // view on Sunday hunting, and a line saying so would invite the AI to supply
  // one — which is the province's answer to give, not a model's.
  if (layers.containsKey('sunday_gun')) {
    final verdict = sundayGunVerdict(info.sundayGun);
    lines.add('Sunday gun hunting: ${verdict.headline}');
    lines.add('  ${verdict.body}');
    if (verdict.citation ?? layers['sunday_gun']?.citation case final cited?) {
      lines.add('  Citation: $cited');
    }
  }

  if (info.landUse.isEmpty) {
    lines.add('Land use records at this point: none. The app holds no land-use '
        'polygon here. That is an absence of record, not evidence of private '
        'ownership and not permission to hunt.');
  } else {
    lines.add('Land use records at this point:');
    for (final feature in info.landUse) {
      final layer = layers[feature.layerId];
      lines.add('  - ${featureTitle(feature, layer)}');
      // A unit gets no verdict, because the card gives it none either. Running
      // huntingVerdict over a WMU produces "hunting status not on record",
      // which about an administrative unit reads as the app not knowing whether
      // you may hunt in it — alarming, and untrue: seasons are listed per unit
      // and the app carries them.
      if (feature.layerId == 'wmu') {
        lines.add('    This is the unit open seasons are set by. It is not a '
            'landholding and says nothing about who owns the ground inside it.');
        continue;
      }
      final (verdict, _) = huntingVerdict(feature.huntingAllowed, feature.basis);
      lines.add('    The app reports: $verdict');
      if (tenureLabel(feature, layer) case final tenure?) {
        lines.add('    Tenure: $tenure');
      }
      if (feature.designation case final designation?) {
        lines.add('    Designation: $designation');
      }
      if (feature.within case final within?) lines.add('    Inside: $within');
      if (feature.lot case final lot?) lines.add('    Lot: $lot');
      if (feature.isApproximate) {
        lines.add('    Caution: this outline is approximate. It is not a '
            'property boundary and may include private land.');
      }
      if (feature.huntingExtent == 'part') {
        lines.add('    Caution: the regulation opens only part of this area, '
            'and that part is not published as a boundary, so the app cannot '
            'tell whether this point is inside it.');
      }
      if (feature.isOverWater) {
        lines.add('    This parcel is almost entirely the bed of a lake or '
            'river.');
      }
      // Verbatim and untruncated. A carve-out such as "excepting those parts
      // posted with signs" is the part that decides legality, and it is exactly
      // what a length limit would cut.
      if (feature.regulationText case final text?) {
        final source = [
          if (feature.regulationSchedule case final schedule?)
            'Schedule $schedule',
          if (layer?.huntingSource case final cited?) cited,
          if (layer?.currencyDate case final date?) 'consolidated $date',
        ].join(', ');
        lines.add('    The regulation says${source.isEmpty ? '' : ' ($source)'}'
            ': "$text"');
      }
      if (feature.statuteText case final text?) {
        final source = [
          if (feature.statuteCitation case final cited?) cited,
          if (feature.statuteCurrencyDate case final date?)
            'consolidated $date',
        ].join(', ');
        lines.add('    The Act also says${source.isEmpty ? '' : ' ($source)'}'
            ': "$text"');
      }
      if (layer?.basisNote(feature.basis) case final note?) {
        lines.add('    Basis: $note');
      }
      if (feature.summary case final summary?) {
        lines.add('    Note: $summary');
      }
    }
  }

  final gaps = info.incompleteCoverage(layers);
  if (gaps.isNotEmpty) {
    lines.add('Known gaps in the data at this point:');
    for (final gap in gaps) {
      lines.add('  - $gap');
    }
  }

  lines.add('Not mapped by this app anywhere: municipal discharge and hunting '
      'by-laws, posted signage, leases and land use permits, and private '
      'ownership.');
  lines.add('Data: ${manifest.name} pack version ${manifest.version}'
      '${manifest.built == null ? ', build date unknown' : ', built '
          '${manifest.built!.toIso8601String().split('T').first}'}. This is a '
      'bundled offline copy of government data, not the live source.');

  return lines.join('\n');
}

/// A prompt the user copies and pastes into whichever AI they trust.
///
/// Built here rather than in the widget so the wording can be tested. Every
/// flavour is bound by the same two rules — reproduce the facts, and say so when
/// you do not know — because those are what keep an AI's fluency from being read
/// as authority on a question where a confident wrong answer gets someone
/// charged.
String askAiPrompt(
  AskAi flavour, {
  required LandInfo info,
  required ProvinceManifest manifest,
  Map<String, LoadedLayer> layers = const {},
}) {
  final facts = landFacts(info: info, manifest: manifest, layers: layers);
  final authority = wildlifeAuthorities[manifest.id];
  final preamble = 'I am asking about one specific point of ground in '
      '${manifest.name}, Canada.\n\n'
      'Everything between the FACTS markers below was copied verbatim out of '
      'OpenWoodsMap, an offline map that reads bundled government data. Treat '
      'it as the input to the question, not as the answer. The app can be out '
      'of date or incomplete, and it does not see posted signage, leases, '
      'municipal by-laws or private ownership.';

  final task = switch (flavour) {
    AskAi.explain => '''
What I want: explain, in plain language, what these records mean for whether I
may lawfully hunt at this point, and be equally clear about what they do not
settle.

- Work from the records above. Where they are silent, say they are silent.
- Do not state a rule you cannot tie to a named Act, regulation, section or
  by-law.
- If you do not know something, say so. I would rather carry a gap than a guess.
- End with the specific things I should confirm before hunting, and who with.

The app's source is open, at $_repository, if you would rather check how it
reached these verdicts than take them from me.''',
    AskAi.enquiry => '''
What I want: help me write a short email asking the responsible office to
confirm in writing whether hunting is permitted at this point.

${authority == null ? '''
I do not have a verified address for the office that answers this in
${manifest.name}. Help me identify the right one and tell me how you know, then
write the email to it.''' : '''
Send it to: ${authority.email}
That is ${authority.name}.
By phone instead: ${authority.phone}, ${authority.hours}.'''}

Rules for the draft:
- Reproduce the FACTS block above verbatim in the email, unchanged. Those
  coordinates and citations are the entire reason the question is answerable.
- Ask one specific, answerable question. "Is this legal?" cannot be answered.
  "Is hunting permitted at these coordinates, and does the Sunday gun
  prohibition apply there?" can be.
- Ask for the reply in writing, so I have something to point to later.
- Keep it under 250 words, not counting the facts block.
- Plain, polite, first person. It should read like me, not like a form letter.
- Do not tell them what the law is, and do not have me assert a legal conclusion
  in my own words. I am asking, not arguing.
- Do not add any fact about me or about this place that is not in the facts
  block. If you think the office will need something more from me, list it
  separately and let me decide.
- If anything in the facts is unclear or looks contradictory to you, say so
  before the draft rather than smoothing it over inside the email. An ambiguity
  you quietly resolve becomes a question that gets the wrong answer.''',
    AskAi.secondOpinion => '''
What I want: an independent second opinion. Using your own knowledge of the
legislation that applies in ${manifest.name}, check whether the app's reading of
this point looks right.

- Cite the specific Act, regulation, section or schedule behind anything you
  assert. An uncited assertion is of no use to me here.
- Where you and the app disagree, say so plainly, say which of you you think is
  wrong, and say why.
- Where you cannot verify something, say that rather than filling the gap.
- Do not present your answer as authoritative. Finish by telling me what to
  confirm with the responsible authority${authority == null ? '' : ', which '
        'here is ${authority.name}'}.

The app's source is open, at $_repository, if you want to check its reasoning.''',
  };

  return '$preamble\n\n=== FACTS FROM OPENWOODSMAP — BEGIN ===\n$facts\n'
      '=== FACTS FROM OPENWOODSMAP — END ===\n\n$task\n';
}

/// What the card says where the pack has no value, rather than a blank that
/// reads as nothing being there.
const _unknown = 'not identified in the installed data';
