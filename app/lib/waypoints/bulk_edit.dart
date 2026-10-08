/// Restyling everything the list is showing in one go.
///
/// Scoped like export, hide and delete: what the search and tag filter show is
/// what changes. That is how "update icons from the names" works without the
/// app guessing. The user searches "stand", sees exactly which waypoints that
/// catches, and picks the icon; a keyword table would have put a stand on
/// "Stand of pines" and a bear on "Bear Creek", and a wrong icon looks every
/// bit as confident as a right one.
library;

import 'package:flutter/material.dart';

import 'waypoint_colour.dart';
import 'waypoint_icon.dart';
import 'waypoint_pickers.dart';
import 'waypoint_store.dart';

/// What to change. Every part is optional, and an absent part is left alone.
class BulkEdit {
  const BulkEdit({
    this.icon,
    this.changeColour = false,
    this.colour,
    this.tag,
  });

  /// Null leaves each icon as it is.
  final WaypointIcon? icon;

  /// Whether colour changes at all. When it does, a null [colour] means each
  /// item follows its own icon's colour again, which is a choice and not the
  /// same as leaving the colour alone.
  final bool changeColour;
  final WaypointColour? colour;

  /// Added to each item's tags. Null or blank adds nothing.
  final String? tag;

  String? get _tag {
    final normalised = normaliseTags([if (tag != null) tag!]);
    return normalised.isEmpty ? null : normalised.single;
  }

  bool get isEmpty => icon == null && !changeColour && _tag == null;
}

/// The items [edit] actually changes, already changed. Items it would leave
/// exactly as they were are not returned, so the count the user is told is
/// the count that changed.
///
/// A track never takes the icon. The map draws a track as its line and never
/// as a symbol, so an icon on one would be a change nobody could see.
List<Waypoint> applyBulkEdit(List<Waypoint> items, BulkEdit edit) {
  final tag = edit._tag;
  return [
    for (final item in items)
      if (_edited(item, edit, tag) case final changed?) changed,
  ];
}

Waypoint? _edited(Waypoint item, BulkEdit edit, String? tag) {
  var out = item;
  if (edit.icon case final icon? when !item.isTrack && item.icon != icon) {
    out = out.copyWith(icon: icon);
  }
  if (edit.changeColour && item.colour != edit.colour) {
    out = edit.colour == null
        ? out.copyWith(clearColour: true)
        : out.copyWith(colour: edit.colour);
  }
  if (tag != null && !item.tags.contains(tag)) {
    out = out.copyWith(tags: [...out.tags, tag]);
  }
  return identical(out, item) ? null : out;
}

/// [current] with [changed] swapped in by id.
List<Waypoint> withEdits(List<Waypoint> current, List<Waypoint> changed) {
  final byId = {for (final item in changed) item.id: item};
  return [for (final item in current) byId[item.id] ?? item];
}

/// Undoes one bulk edit against the list as it is now, per undo.dart.
///
/// Only the parts [edit] set are put back, from [originals]: a waypoint renamed
/// since keeps its new name, one deleted since stays deleted, and the added tag
/// comes off only where the edit was what put it there.
List<Waypoint> revertBulkEdit({
  required List<Waypoint> current,
  required List<Waypoint> originals,
  required BulkEdit edit,
}) {
  final before = {for (final item in originals) item.id: item};
  final tag = edit._tag;
  return [
    for (final item in current)
      if (before[item.id] case final was?)
        _reverted(item, was, edit, tag)
      else
        item,
  ];
}

Waypoint _reverted(Waypoint item, Waypoint was, BulkEdit edit, String? tag) {
  var out = item;
  if (edit.icon != null) out = out.copyWith(icon: was.icon);
  if (edit.changeColour) {
    out = was.colour == null
        ? out.copyWith(clearColour: true)
        : out.copyWith(colour: was.colour);
  }
  if (tag != null && !was.tags.contains(tag)) {
    out = out.copyWith(tags: [...out.tags]..remove(tag));
  }
  return out;
}

/// Icons whose name matches what the user searched or filtered on, offered as
/// one-tap suggestions and never chosen for them.
///
/// Whole words of the icon's label, so "stand" finds Stand and "deer" finds
/// Deer or moose, with a trailing s forgiven because people search in the
/// plural. Under three letters matches too much to be a suggestion.
List<WaypointIcon> iconsMatching(Iterable<String> hints) {
  final words = {
    for (final hint in hints)
      for (final word in hint.toLowerCase().split(RegExp(r'[^a-z]+')))
        if (word.length >= 3) word,
  };
  if (words.isEmpty) return const [];
  bool matches(WaypointIcon icon) => icon.label
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .any((part) =>
          part.isNotEmpty &&
          words.any((word) => word == part || word == '${part}s'));
  return [
    for (final icon in WaypointIcon.values)
      if (icon != WaypointIcon.pin && matches(icon)) icon,
  ].take(4).toList();
}

/// Asks what to change about [items]. Null if cancelled or nothing was picked.
Future<BulkEdit?> showBulkEdit(
  BuildContext context, {
  required List<Waypoint> items,
  required String title,
  required Iterable<String> hints,
}) => showModalBottomSheet<BulkEdit>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.9,
    child: _BulkEditSheet(items: items, title: title, hints: hints.toList()),
  ),
);

class _BulkEditSheet extends StatefulWidget {
  const _BulkEditSheet({
    required this.items,
    required this.title,
    required this.hints,
  });

  final List<Waypoint> items;
  final String title;
  final List<String> hints;

  @override
  State<_BulkEditSheet> createState() => _BulkEditSheetState();
}

class _BulkEditSheetState extends State<_BulkEditSheet> {
  WaypointIcon? _icon;
  var _changeColour = false;
  WaypointColour? _colour;
  final _tag = TextEditingController();
  var _showAllIcons = false;

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  BulkEdit get _edit => BulkEdit(
    icon: _icon,
    changeColour: _changeColour,
    colour: _colour,
    tag: _tag.text,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracks = widget.items.where((item) => item.isTrack).length;
    final points = widget.items.length - tracks;
    final suggested = iconsMatching(widget.hints);
    final willChange = applyBulkEdit(widget.items, _edit).length;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListTile(
                title: Text(widget.title),
                subtitle: Text(
                  'Each part is left alone unless you change it.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _label(theme, 'Icon'),
              if (points == 0)
                _note(theme, 'These are all tracks. The map draws a track as '
                    'its line, so an icon would not show.')
              else ...[
                if (tracks > 0)
                  _note(theme, 'Only the $points '
                      '${points == 1 ? 'waypoint' : 'waypoints'} take an icon. '
                      'Tracks are drawn as lines.'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Leave as they are'),
                        selected: _icon == null,
                        onSelected: (_) => setState(() => _icon = null),
                      ),
                      // Suggested by name, never preselected: the search is a
                      // hint about what these are, not a decision about them.
                      for (final icon in suggested)
                        ChoiceChip(
                          avatar: Icon(icon.icon, color: icon.colour),
                          label: Text(icon.label),
                          selected: _icon == icon,
                          onSelected: (_) => setState(() => _icon = icon),
                        ),
                      if (_icon case final icon?
                          when !suggested.contains(icon))
                        ChoiceChip(
                          avatar: Icon(icon.icon, color: icon.colour),
                          label: Text(icon.label),
                          selected: true,
                          onSelected: (_) {},
                        ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAllIcons = !_showAllIcons),
                        icon: Icon(
                          _showAllIcons ? Icons.expand_less : Icons.expand_more,
                        ),
                        label: Text(
                          _showAllIcons ? 'Fewer icons' : 'All icons',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showAllIcons)
                  for (final entry in WaypointIcon.byGroup.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        entry.key.label,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final icon in entry.value)
                            IconChoice(
                              icon: icon,
                              selected: icon == _icon,
                              onTap: () => setState(() => _icon = icon),
                            ),
                        ],
                      ),
                    ),
                  ],
              ],
              _label(theme, 'Colour'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Leave as they are'),
                      selected: !_changeColour,
                      onSelected: (_) => setState(() {
                        _changeColour = false;
                        _colour = null;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text("Each icon's own"),
                      selected: _changeColour && _colour == null,
                      onSelected: (_) => setState(() {
                        _changeColour = true;
                        _colour = null;
                      }),
                    ),
                    for (final colour in WaypointColour.values)
                      ColourSwatch(
                        colour: colour.value,
                        label: colour.label,
                        selected: _changeColour && _colour == colour,
                        onTap: () => setState(() {
                          _changeColour = true;
                          _colour = colour;
                        }),
                      ),
                  ],
                ),
              ),
              _label(theme, 'Add a tag'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _tag,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Optional. Existing tags are kept.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
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
                  _edit.isEmpty
                      ? 'Nothing chosen yet.'
                      : willChange == 0
                      ? 'They already look like this.'
                      : 'Changes ${describeItems(applyBulkEdit(widget.items, _edit))}.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: willChange == 0
                    ? null
                    : () => Navigator.pop(context, _edit),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
    ),
  );

  Widget _note(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Text(text, style: theme.textTheme.bodySmall),
  );
}
