/// Proposing icons from waypoint names, for the user to check before anything
/// changes.
///
/// An import from another app tends to arrive as dozens of identical pins whose
/// names say what they are: "North stand", "Trail cam 3", "Truck". Reading a
/// glyph off those is worth doing, but free text is not a reliable source:
/// "Bear Creek" is a stream, "Stand of pines" is timber, and a wrong glyph looks
/// exactly as sure of itself as a right one. So nothing here changes a
/// waypoint. It proposes, the doubtful cases start unticked with the reason
/// beside them, and the user applies what they agree with.
///
/// Notes are not read. They are the longest, loosest text a waypoint has, and
/// "saw a bear from the truck" names two icons and is neither.
library;

import 'package:flutter/material.dart';

import 'waypoint_icon.dart';
import 'waypoint_store.dart';

/// Whole words and two-word phrases, already lowercased and without accents.
///
/// Common hunting, fishing and camping words in English and Quebec French.
/// Words that are as often something else are left out on purpose: "well",
/// "car" and "ours" are ordinary words far more often than they are a spring, a
/// parking spot or a bear, and a table that guesses on them would be noisy
/// enough to stop being worth reading.
const Map<String, WaypointIcon> iconWords = {
  'viewpoint': WaypointIcon.viewpoint,
  'lookout': WaypointIcon.viewpoint,
  'overlook': WaypointIcon.viewpoint,
  'vista': WaypointIcon.viewpoint,
  'belvedere': WaypointIcon.viewpoint,
  'camp': WaypointIcon.camp,
  'campsite': WaypointIcon.camp,
  'campground': WaypointIcon.camp,
  'camping': WaypointIcon.camp,
  'tent': WaypointIcon.tent,
  'firepit': WaypointIcon.firepit,
  'fire pit': WaypointIcon.firepit,
  'fire ring': WaypointIcon.firepit,
  'campfire': WaypointIcon.firepit,
  'water': WaypointIcon.water,
  'water source': WaypointIcon.water,
  'cache': WaypointIcon.cache,
  'forage': WaypointIcon.foraging,
  'foraging': WaypointIcon.foraging,
  'mushroom': WaypointIcon.mushroom,
  'chanterelle': WaypointIcon.mushroom,
  'morel': WaypointIcon.mushroom,
  'champignon': WaypointIcon.mushroom,
  'berry': WaypointIcon.berries,
  'blueberry': WaypointIcon.berries,
  'raspberry': WaypointIcon.berries,
  'blackberry': WaypointIcon.berries,
  'bleuet': WaypointIcon.berries,
  'acorn': WaypointIcon.nuts,
  'beechnut': WaypointIcon.nuts,
  'mast': WaypointIcon.nuts,
  'deer': WaypointIcon.deer,
  'buck': WaypointIcon.deer,
  'doe': WaypointIcon.deer,
  'moose': WaypointIcon.deer,
  'elk': WaypointIcon.deer,
  'chevreuil': WaypointIcon.deer,
  'orignal': WaypointIcon.deer,
  'cerf': WaypointIcon.deer,
  'bear': WaypointIcon.bear,
  'boar': WaypointIcon.boar,
  'hog': WaypointIcon.boar,
  'wolf': WaypointIcon.wolf,
  'wolves': WaypointIcon.wolf,
  'coyote': WaypointIcon.wolf,
  'loup': WaypointIcon.wolf,
  'rabbit': WaypointIcon.rabbit,
  'hare': WaypointIcon.rabbit,
  'lapin': WaypointIcon.rabbit,
  'lievre': WaypointIcon.rabbit,
  'squirrel': WaypointIcon.squirrel,
  'ecureuil': WaypointIcon.squirrel,
  'beaver': WaypointIcon.beaver,
  'castor': WaypointIcon.beaver,
  'duck': WaypointIcon.waterfowl,
  'goose': WaypointIcon.waterfowl,
  'geese': WaypointIcon.waterfowl,
  'canard': WaypointIcon.waterfowl,
  'outarde': WaypointIcon.waterfowl,
  'grouse': WaypointIcon.feather,
  'turkey': WaypointIcon.feather,
  'partridge': WaypointIcon.feather,
  'pheasant': WaypointIcon.feather,
  'woodcock': WaypointIcon.feather,
  'perdrix': WaypointIcon.feather,
  'dindon': WaypointIcon.feather,
  'stand': WaypointIcon.stand,
  'treestand': WaypointIcon.stand,
  'tree stand': WaypointIcon.stand,
  'ladder': WaypointIcon.stand,
  'ladder stand': WaypointIcon.stand,
  'tower': WaypointIcon.towerStand,
  'tower stand': WaypointIcon.towerStand,
  'box stand': WaypointIcon.towerStand,
  'blind': WaypointIcon.blind,
  'ground blind': WaypointIcon.blind,
  'box blind': WaypointIcon.blind,
  'glassing': WaypointIcon.glassing,
  'camera': WaypointIcon.camera,
  'cam': WaypointIcon.camera,
  'trailcam': WaypointIcon.camera,
  'trail cam': WaypointIcon.camera,
  'trail camera': WaypointIcon.camera,
  'scrape': WaypointIcon.sign,
  'rub': WaypointIcon.sign,
  'blood': WaypointIcon.blood,
  'blood trail': WaypointIcon.blood,
  'harvest': WaypointIcon.harvest,
  'food plot': WaypointIcon.food,
  'foodplot': WaypointIcon.food,
  'feeder': WaypointIcon.food,
  'bait': WaypointIcon.food,
  'lick': WaypointIcon.food,
  'salt lick': WaypointIcon.food,
  'mineral lick': WaypointIcon.food,
  'fishing': WaypointIcon.fishing,
  'fishing spot': WaypointIcon.fishing,
  'fishing hole': WaypointIcon.fishing,
  'trout': WaypointIcon.fishing,
  'bass': WaypointIcon.fishing,
  'pike': WaypointIcon.fishing,
  'walleye': WaypointIcon.fishing,
  'pickerel': WaypointIcon.fishing,
  'muskie': WaypointIcon.fishing,
  'perch': WaypointIcon.fishing,
  'dore': WaypointIcon.fishing,
  'dock': WaypointIcon.dock,
  'mooring': WaypointIcon.dock,
  'wharf': WaypointIcon.dock,
  'quai': WaypointIcon.dock,
  'boat launch': WaypointIcon.boatLaunch,
  'launch': WaypointIcon.boatLaunch,
  'timber': WaypointIcon.forest,
  'swamp': WaypointIcon.swamp,
  'marsh': WaypointIcon.swamp,
  'bog': WaypointIcon.swamp,
  'fen': WaypointIcon.swamp,
  'wetland': WaypointIcon.swamp,
  'marais': WaypointIcon.swamp,
  'tourbiere': WaypointIcon.swamp,
  'waterfall': WaypointIcon.waterfall,
  'falls': WaypointIcon.waterfall,
  'rapids': WaypointIcon.waterfall,
  'chute': WaypointIcon.waterfall,
  'spring': WaypointIcon.spring,
  'cave': WaypointIcon.cave,
  'overhang': WaypointIcon.cave,
  'grotte': WaypointIcon.cave,
  'farm': WaypointIcon.farm,
  'field': WaypointIcon.farm,
  'pasture': WaypointIcon.farm,
  'hayfield': WaypointIcon.farm,
  'cornfield': WaypointIcon.farm,
  'ferme': WaypointIcon.farm,
  'parking': WaypointIcon.parking,
  'truck': WaypointIcon.parking,
  'stationnement': WaypointIcon.parking,
  'trailhead': WaypointIcon.trailhead,
  'signpost': WaypointIcon.signpost,
  'junction': WaypointIcon.signpost,
  'intersection': WaypointIcon.signpost,
  'fork': WaypointIcon.signpost,
  'ford': WaypointIcon.ford,
  'crossing': WaypointIcon.ford,
  'bridge': WaypointIcon.bridge,
  'pont': WaypointIcon.bridge,
  'gate': WaypointIcon.gate,
  'barrier': WaypointIcon.gate,
  'barriere': WaypointIcon.gate,
  'hazard': WaypointIcon.hazard,
  'danger': WaypointIcon.hazard,
};

/// Words that make the one before them part of a place name: "Bear Creek",
/// "Deer Lake", "Beaver Pond", "Trout River".
const _placeAfter = {
  'creek',
  'lake',
  'river',
  'pond',
  'bay',
  'hill',
  'hills',
  'mountain',
  'mount',
  'mt',
  'brook',
  'island',
  'point',
  'road',
  'rd',
  'street',
  'valley',
  'ridge',
  'run',
  'hollow',
  'township',
  'twp',
  'narrows',
  'portage',
};

/// The French order puts the feature first: "Lac Castor", "Rivière à l'Ours".
const _placeBefore = {
  'lac',
  'riviere',
  'ruisseau',
  'mont',
  'montagne',
  'baie',
  'chemin',
  'rang',
  'pointe',
  'ile',
  'canton',
};

/// What a name suggests, and whether it is safe to start ticked.
typedef NameMatch = ({WaypointIcon icon, String? doubt});

/// The icon [name] suggests, or null if no word in it is one this knows.
NameMatch? matchName(String name) {
  final tokens = _tokens(name);
  final hits = <({WaypointIcon icon, int start, int end})>[];
  for (var i = 0; i < tokens.length; i++) {
    if (i + 1 < tokens.length) {
      final pair = iconWords['${tokens[i]} ${tokens[i + 1]}'];
      if (pair != null) {
        hits.add((icon: pair, start: i, end: i + 1));
        i++;
        continue;
      }
    }
    if (_lookup(tokens[i]) case final icon?) {
      hits.add((icon: icon, start: i, end: i));
    }
  }
  if (hits.isEmpty) return null;

  bool inPlaceName(({WaypointIcon icon, int start, int end}) hit) {
    final after = hit.end + 1 < tokens.length ? tokens[hit.end + 1] : null;
    if (after != null && _placeAfter.contains(after)) return true;
    for (var back = 1; back <= 3 && hit.start - back >= 0; back++) {
      if (_placeBefore.contains(tokens[hit.start - back])) return true;
    }
    return false;
  }

  final firm = hits.where((hit) => !inPlaceName(hit)).toList();
  if (firm.isEmpty) {
    return (
      icon: hits.last.icon,
      doubt: 'Reads like a place name, so not ticked.',
    );
  }
  final icons = {for (final hit in firm) hit.icon};
  if (icons.length == 1) return (icon: icons.single, doubt: null);
  // The last one, because an English name usually ends on the thing it is
  // ("Bear stand"), but never ticked: that rule is a habit, not a fact.
  final chosen = firm.last.icon;
  final others = icons
      .where((icon) => icon != chosen)
      .map((icon) => icon.label.toLowerCase());
  return (
    icon: chosen,
    doubt: 'Also mentions ${others.join(' and ')}, so not ticked.',
  );
}

WaypointIcon? _lookup(String token) {
  for (final form in [
    token,
    if (token.endsWith('ies')) '${token.substring(0, token.length - 3)}y',
    if (token.endsWith('es')) token.substring(0, token.length - 2),
    if (token.endsWith('s')) token.substring(0, token.length - 1),
  ]) {
    if (iconWords[form] case final icon?) return icon;
  }
  return null;
}

List<String> _tokens(String name) {
  const folded = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
  };
  final plain =
      name.toLowerCase().split('').map((char) => folded[char] ?? char).join();
  return plain
      .split(RegExp(r'[^a-z]+'))
      .where((token) => token.isNotEmpty)
      .toList();
}

/// One proposed change.
class IconSuggestion {
  const IconSuggestion(this.item, this.icon, this.doubt);

  final Waypoint item;
  final WaypointIcon icon;

  /// Why it starts unticked, or null if it starts ticked.
  final String? doubt;
}

/// What scanning [items] found.
class IconMatches {
  const IconMatches({
    required this.suggestions,
    required this.unmatched,
    required this.alreadySet,
  });

  final List<IconSuggestion> suggestions;

  /// Plain pins whose name had no word this knows.
  final int unmatched;

  /// Waypoints with an icon of their own, which are never touched.
  final int alreadySet;
}

/// Proposals for the plain pins among [items].
///
/// Only the plain pin, because any other icon was a choice, by the user or by
/// the file it came from, and a name is weaker evidence than either.
IconMatches matchIconsToNames(Iterable<Waypoint> items) {
  final suggestions = <IconSuggestion>[];
  var unmatched = 0;
  var alreadySet = 0;
  for (final item in items) {
    if (item.isTrack) continue;
    if (item.icon != WaypointIcon.fallback) {
      alreadySet++;
      continue;
    }
    final match = matchName(item.name);
    if (match == null) {
      unmatched++;
    } else {
      suggestions.add(IconSuggestion(item, match.icon, match.doubt));
    }
  }
  return IconMatches(
    suggestions: suggestions,
    unmatched: unmatched,
    alreadySet: alreadySet,
  );
}

/// Puts the pin back on whatever still carries the icon it was given, per
/// undo.dart: one changed again since keeps its newer icon.
List<Waypoint> revertIconMatches({
  required List<Waypoint> current,
  required Map<String, WaypointIcon> applied,
}) => [
  for (final item in current)
    if (applied[item.id] == item.icon)
      item.copyWith(icon: WaypointIcon.fallback)
    else
      item,
];

/// Shows the proposals and returns the ones the user kept, by waypoint id.
Future<Map<String, WaypointIcon>?> showIconMatches(
  BuildContext context, {
  required IconMatches matches,
}) => showModalBottomSheet<Map<String, WaypointIcon>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder:
      (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _IconMatchSheet(matches: matches),
      ),
);

class _IconMatchSheet extends StatefulWidget {
  const _IconMatchSheet({required this.matches});

  final IconMatches matches;

  @override
  State<_IconMatchSheet> createState() => _IconMatchSheetState();
}

class _IconMatchSheetState extends State<_IconMatchSheet> {
  late final Set<String> _ticked = {
    for (final suggestion in widget.matches.suggestions)
      if (suggestion.doubt == null) suggestion.item.id,
  };

  Map<WaypointIcon, List<IconSuggestion>> get _byIcon {
    final grouped = <WaypointIcon, List<IconSuggestion>>{};
    for (final suggestion in widget.matches.suggestions) {
      (grouped[suggestion.icon] ??= []).add(suggestion);
    }
    for (final list in grouped.values) {
      list.sort(
        (a, b) =>
            a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()),
      );
    }
    final ordered =
        grouped.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Map.fromEntries(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = widget.matches;
    final notes = [
      if (matches.alreadySet > 0)
        '${matches.alreadySet} already ${matches.alreadySet == 1 ? 'has its own icon' : 'have their own icons'} '
            'and ${matches.alreadySet == 1 ? 'is' : 'are'} left alone.',
      if (matches.unmatched > 0)
        '${matches.unmatched} ${matches.unmatched == 1 ? 'name gives' : 'names give'} '
            'nothing to go on and stay as pins.',
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListTile(
                title: const Text('Match icons to names'),
                subtitle: Text(
                  'Guessed from a word in each name. Untick any that are '
                  'wrong; nothing changes until you apply.'
                  '${notes.isEmpty ? '' : '\n${notes.join(' ')}'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              for (final MapEntry(key: icon, value: group)
                  in _byIcon.entries) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(icon.icon, color: icon.colour),
                  title: Text(icon.label),
                  trailing: Checkbox(
                    tristate: true,
                    value: switch (group
                        .where((s) => _ticked.contains(s.item.id))
                        .length) {
                      0 => false,
                      final n when n == group.length => true,
                      _ => null,
                    },
                    onChanged:
                        (_) => setState(() {
                          final all = group.every(
                            (s) => _ticked.contains(s.item.id),
                          );
                          for (final s in group) {
                            all
                                ? _ticked.remove(s.item.id)
                                : _ticked.add(s.item.id);
                          }
                        }),
                  ),
                ),
                for (final suggestion in group)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: Text(suggestion.item.name),
                    subtitle:
                        suggestion.doubt == null
                            ? null
                            : Text(suggestion.doubt!),
                    value: _ticked.contains(suggestion.item.id),
                    onChanged:
                        (on) => setState(() {
                          on == true
                              ? _ticked.add(suggestion.item.id)
                              : _ticked.remove(suggestion.item.id);
                        }),
                  ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _ticked.isEmpty
                      ? 'Nothing ticked.'
                      : 'Changes ${_ticked.length} '
                          '${_ticked.length == 1 ? 'waypoint' : 'waypoints'}.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    _ticked.isEmpty
                        ? null
                        : () => Navigator.pop(context, {
                          for (final s in matches.suggestions)
                            if (_ticked.contains(s.item.id)) s.item.id: s.icon,
                        }),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
