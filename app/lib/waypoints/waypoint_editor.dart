import 'package:flutter/material.dart';

import '../tracks/track_math.dart';
import '../tracks/track_preview.dart';
import '../tracks/track_style.dart';
import 'legacy_categories.dart';
import 'waypoint_colour.dart';
import 'waypoint_icon.dart';
import 'waypoint_store.dart';

/// Opens the waypoint editor, returning the edited waypoint or null if cancelled.
///
/// One editor for both new and existing waypoints, because the fields are the
/// same and two of them would drift apart. [existing] decides which.
Future<Waypoint?> showWaypointEditor(
  BuildContext context, {
  required Waypoint existing,
  required List<String> knownTags,
  required bool isNew,
}) => showModalBottomSheet<Waypoint>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: WaypointEditor(
        existing: existing,
        knownTags: knownTags,
        isNew: isNew,
        onSave: (waypoint) => Navigator.pop(context, waypoint),
      ),
    ),
  ),
);

class WaypointEditor extends StatefulWidget {
  const WaypointEditor({
    super.key,
    required this.existing,
    required this.knownTags,
    required this.isNew,
    required this.onSave,
  });

  final Waypoint existing;

  /// Tags already in use, offered as chips. Typing the same tag twice with a
  /// different capitalisation is the main way a tag list turns to noise.
  final List<String> knownTags;

  final bool isNew;
  final ValueChanged<Waypoint> onSave;

  @override
  State<WaypointEditor> createState() => _WaypointEditorState();
}

class _WaypointEditorState extends State<WaypointEditor> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late WaypointIcon _icon;
  late WaypointColour? _colour;
  late List<String> _tags;
  late TrackStroke _stroke;
  late TrackMarker _marker;

  /// Collapsed to start with. Nineteen chips on show would read as a list the
  /// user is expected to work through, which is the opposite of what they are.
  var _showSuggestions = false;

  /// Also collapsed to start with, and for a stronger version of that reason:
  /// the glyph grid is the tallest thing in this sheet, and most edits do not
  /// change the icon at all.
  var _showIcons = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing.name);
    _notes = TextEditingController(text: widget.existing.notes);
    _icon = widget.existing.icon;
    _colour = widget.existing.colour;
    _tags = [...widget.existing.tags];
    _stroke = widget.existing.stroke;
    _marker = widget.existing.marker;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isLine => widget.existing.isTrack;

  void _save() {
    final name = _name.text.trim();
    widget.onSave(
      widget.existing.copyWith(
        name: name.isEmpty ? widget.existing.name : name,
        notes: _notes.text.trim(),
        icon: _icon,
        tags: _tags,
        colour: _colour,
        clearColour: _colour == null,
        stroke: _stroke,
        marker: _marker,
      ),
    );
  }

  /// What this will actually be drawn in, which is not [_colour]: null there
  /// means the glyph's own colour, and anything claiming to preview it has to
  /// resolve that to be telling the truth.
  Color get _drawnColour => _colour?.value ?? _icon.colour;

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(
            hintText: 'ridge, north block, opening day',
            helperText: 'Commas separate several at once.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added == null || !mounted) return;
    setState(
      () => _tags = normaliseTags([..._tags, ...added.split(',')]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unusedKnownTags = widget.knownTags
        .where((tag) => !_tags.contains(tag))
        .toList();
    // A suggestion the user has adopted is their tag now, and showing it in
    // both places would say it was still only an example.
    final unusedSuggestions = suggestedTags
        .where(
          (tag) => !_tags.contains(tag) && !widget.knownTags.contains(tag),
        )
        .toList();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: _SheetBody(
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _save,
              child: Text(widget.isNew ? 'Save' : 'Done'),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                switch ((_isLine, widget.isNew)) {
                  (true, _) => 'Edit track',
                  (false, true) => 'New waypoint',
                  (false, false) => 'Edit waypoint',
                },
              ),
              // A track's own start coordinate is not what identifies it, so it
              // gets its length and how long it took instead.
              subtitle: Text(
                _isLine
                    ? describeTrack(widget.existing.track)
                    : '${widget.existing.latitude.toStringAsFixed(5)}, '
                          '${widget.existing.longitude.toStringAsFixed(5)}',
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _name,
                autofocus: widget.isNew,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Name',
                ),
              ),
            ),
            _label(theme, 'Icon'),
            // Collapsed to start with, for the same reason the tag examples
            // below are. The labelled chips sat between the name field and
            // everything else, so colour, tags, notes and Save were all a
            // scroll away on a phone. A wall of names also reads as a set of
            // categories to file the waypoint under, when all it decides is how
            // this one is drawn.
            ListTile(
              // The colour it will really be drawn in rather than the glyph's
              // own, because this row is claiming to show how it looks.
              leading: Icon(_icon.icon, color: _drawnColour),
              title: Text(_icon.label),
              subtitle: const Text('How this is drawn on the map.'),
              trailing: Icon(
                _showIcons ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () => setState(() => _showIcons = !_showIcons),
            ),
            // Sectioned, because thirty pictograms in one wall is unreadable.
            // The sections are the picker's only job: nothing downstream reads
            // a glyph's group, and a fishing glyph on a stand is a legitimate
            // choice rather than a mistake to be prevented.
            if (_showIcons)
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
                        _IconChoice(
                          icon: icon,
                          selected: icon == _icon,
                          // Picking deliberately leaves the grid open. The
                          // names are not on the glyphs, so the row above is how
                          // you read back what you just chose, and closing on
                          // the first tap would take the grid away before you
                          // could compare it with the one beside it.
                          onTap: () => setState(() => _icon = icon),
                        ),
                    ],
                  ),
                ),
              ],
            _label(theme, 'Colour'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Following the glyph is a real choice and not the same as
                  // picking the colour the glyph happens to carry: this swatch
                  // repaints itself when the glyph above changes, and a
                  // waypoint set this way follows.
                  _Swatch(
                    colour: _icon.colour,
                    label: "The icon's own colour",
                    selected: _colour == null,
                    onTap: () => setState(() => _colour = null),
                  ),
                  for (final colour in WaypointColour.values)
                    _Swatch(
                      colour: colour.value,
                      label: colour.label,
                      selected: _colour == colour,
                      onTap: () => setState(() => _colour = colour),
                    ),
                ],
              ),
            ),
            // Only for lines. A point has no stroke to pattern and no direction
            // to mark, and offering it either would suggest otherwise.
            if (_isLine) ...[
              _label(theme, 'Line'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TrackPreview(
                  colour: _drawnColour,
                  stroke: _stroke,
                  marker: _marker,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final stroke in TrackStroke.values)
                      ChoiceChip(
                        selected: stroke == _stroke,
                        label: Text(stroke.label),
                        onSelected: (_) => setState(() => _stroke = stroke),
                      ),
                  ],
                ),
              ),
              _label(theme, 'Direction'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final marker in TrackMarker.values)
                      ChoiceChip(
                        selected: marker == _marker,
                        // See the category chips: the checkmark would sit on top
                        // of the shape being chosen.
                        showCheckmark: false,
                        avatar: marker.icon == null
                            ? null
                            : Icon(marker.icon, size: 18),
                        label: Text(marker.label),
                        onSelected: (_) => setState(() => _marker = marker),
                      ),
                  ],
                ),
              ),
            ],
            _label(theme, 'Tags'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // FilterChip rather than InputChip and ActionChip, which is
                  // what these were: those two differ only by a small leading
                  // glyph, so on a phone the tags on this waypoint looked much
                  // like the ones merely available, and people saved the wrong
                  // ones. A filled container and a checkmark is Material's own
                  // way of saying selected, and it is what the waypoints list
                  // already uses for its tag filter. The icon chips above skip
                  // the checkmark because it scrims the glyph they exist to
                  // show; a tag has no glyph, so here it is free.
                  for (final tag in _tags)
                    FilterChip(
                      selected: true,
                      label: Text(tag),
                      onSelected: (_) => setState(
                        () => _tags = [..._tags]..remove(tag),
                      ),
                    ),
                  for (final tag in unusedKnownTags)
                    FilterChip(
                      selected: false,
                      label: Text(tag),
                      onSelected: (_) => setState(
                        () => _tags = normaliseTags([..._tags, tag]),
                      ),
                    ),
                  // Still an ActionChip: this makes a tag rather than toggling
                  // one, and adopting an example below is the same kind of act.
                  ActionChip(
                    avatar: const Icon(Icons.label_outline, size: 16),
                    label: const Text('New tag'),
                    onPressed: _addTag,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _showSuggestions = !_showSuggestions),
                icon: Icon(
                  _showSuggestions ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: const Text('Example tags'),
              ),
            ),
            if (_showSuggestions) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Built-in examples, not tags you have made. Take any that '
                  'suit how you organise your spots and ignore the rest.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in unusedSuggestions)
                      ActionChip(
                        avatar: const Icon(Icons.lightbulb_outline, size: 16),
                        label: Text(tag),
                        onPressed: () => setState(
                          () => _tags = normaliseTags([..._tags, tag]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Notes',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
    ),
  );
}

/// A sheet whose [child] scrolls and whose [footer] does not.
///
/// Save used to be the last widget inside the scrolling area, below Notes, so on
/// a phone it sat under the fold and saving meant scrolling past every other
/// control to reach it.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.footer, required this.child});

  final Widget footer;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Flexible rather than Expanded, so a short sheet, such as a waypoint
      // with the glyph grid closed, still sizes itself to its contents instead
      // of stretching to the full height the caller allows.
      Flexible(child: SingleChildScrollView(child: child)),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: footer,
      ),
    ],
  );
}

/// One glyph in the icon grid, with no name beside it.
///
/// Names made the grid four times taller than it needed to be, and with these
/// icons in six titled groups the heading and the glyph together are usually
/// enough to find the one you want. The name is still reachable: the row above
/// the grid names whatever is selected, and a long press names any of them.
/// [WaypointIcon.label] stays in the data either way, which is what a search
/// across icons would match on.
class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final WaypointIcon icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: icon.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          label: icon.label,
          selected: selected,
          button: true,
          child: Container(
            // Still a full-sized touch target: dropping the names was meant to
            // shorten the grid, not to make it harder to hit with cold hands.
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? scheme.secondaryContainer : null,
              border: Border.all(
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            // In the glyph's own colour, because that is what the waypoint will
            // be drawn in unless a colour is chosen below, and a picker that hid
            // that would be asking the user to pick a colour blind.
            child: Center(child: Icon(icon.icon, size: 24, color: icon.colour)),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colour,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color colour;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            // An outline on every swatch rather than only the selected one, so
            // white and black both stay visible against the sheet.
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.black26,
              width: selected ? 3 : 1,
            ),
          ),
          // A white tick disappears on the white and yellow swatches, so the
          // tick takes whichever of black or white the swatch can carry.
          child: selected
              ? Icon(
                  Icons.check,
                  size: 18,
                  color:
                      ThemeData.estimateBrightnessForColor(colour) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                )
              : null,
        ),
      ),
    ),
  );
}
