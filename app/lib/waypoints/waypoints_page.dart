import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../backup/backup_page.dart';
import '../backup/backup_record.dart';
import '../backup/snapshot_store.dart';
import '../tracks/track_math.dart';
import '../settings/visibility_settings.dart';
import '../ui/messages.dart';
import 'import_export.dart';
import 'tag_style.dart';
import 'undo.dart';
import 'waypoint_colour.dart';
import 'waypoint_editor.dart';
import 'waypoint_icon.dart';
import 'waypoint_store.dart';

/// What the list is asking the map to do as it closes.
///
/// The page used to pop a bare [Waypoint], which could only ever mean "show me
/// this". Following needs a direction as well, and a sealed result makes the
/// map's switch exhaustive so a third request later cannot be silently ignored.
sealed class WaypointsRequest {
  const WaypointsRequest();
}

class RevealWaypoint extends WaypointsRequest {
  const RevealWaypoint(this.waypoint);
  final Waypoint waypoint;
}

class FollowTrack extends WaypointsRequest {
  const FollowTrack(this.track, {required this.reversed});
  final Waypoint track;
  final bool reversed;
}

class WaypointsPage extends StatefulWidget {
  const WaypointsPage({
    super.key,
    required this.store,
    required this.suggestedLocation,
    required this.visibility,
  });

  final WaypointStore store;
  final LatLng suggestedLocation;
  final VisibilitySettings visibility;

  @override
  State<WaypointsPage> createState() => _WaypointsPageState();
}

/// A header row in the grouped list. A null [tag] is the untagged section.
class _Section {
  const _Section(this.tag, this.count);
  final String? tag;
  final int count;
}

class _WaypointsPageState extends State<WaypointsPage> {
  final _transfer = WaypointImportExport();
  final _tagStyles = TagStyleStore();
  final _backups = BackupRecord();
  var _loading = true;

  /// The tags being filtered on. Empty means everything.
  ///
  /// The filter doubles as the export selection, which is how "export a subset"
  /// works without a second selection mode to learn: what you can see is what
  /// leaves. Several tags at once, because one tag was never how anyone
  /// describes what they are looking for.
  final _selected = <String>{};

  /// Whether a waypoint has to carry every selected tag or just one of them.
  ///
  /// Both are useful — "ridge and opening day" narrows, "ridge or creek" widens
  /// — so both are offered, and the chip that switches them says which one is
  /// in force rather than being a setting to remember.
  var _matchAll = false;

  /// What is being searched for, trimmed and lowered once here rather than on
  /// every comparison. Empty means no search.
  var _query = '';
  final _search = TextEditingController();

  /// Whether the tag chips beyond [_tagChipLimit] are on show.
  var _showAllTags = false;

  /// How many tag chips appear before the rest go behind one more chip.
  ///
  /// A wrap of every tag someone has is the honest layout, and with a dozen tags
  /// it is also most of the screen, on a page whose job is the list underneath.
  /// Six is about two rows of ordinary tag names.
  static const _tagChipLimit = 6;

  @override
  void initState() {
    super.initState();
    widget.visibility.addListener(_onVisibilityChanged);
    // Styling loads alongside the waypoints and is allowed to fail quietly.
    // Nothing here depends on it: a tag with no style draws a plain label.
    Future.wait([
      widget.store.load(),
      _tagStyles.load(),
      _backups.load(),
    ]).then((_) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (widget.store.unreadableFilePath case final path?) {
        _warnUnreadable(path);
      }
    });
  }

  @override
  void dispose() {
    widget.visibility.removeListener(_onVisibilityChanged);
    _search.dispose();
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (mounted) setState(() {});
  }

  /// Whether anything at all is keeping rows out of the list.
  ///
  /// Not the same question as whether tags are picked, which is what decides
  /// how the list is sectioned. A search alone hides rows without changing what
  /// the sections are.
  bool get _filtered => _selected.isNotEmpty || _query.isNotEmpty;

  bool _matches(Waypoint item) => _matchesQuery(item) && _matchesTags(item);

  bool _matchesTags(Waypoint item) {
    if (_selected.isEmpty) return true;
    return _matchAll
        ? _selected.every(item.tags.contains)
        : _selected.any(item.tags.contains);
  }

  /// Its name, its tags, or the name of its glyph.
  ///
  /// Those are the three things someone remembers about a mark they are looking
  /// for, and the icon's name is searchable precisely because the picker stopped
  /// printing it beside every glyph. Notes are deliberately out: they are the
  /// longest text here and nothing in a row says which field matched, so a hit
  /// buried in a paragraph would look like a result arriving for no reason.
  bool _matchesQuery(Waypoint item) {
    if (_query.isEmpty) return true;
    return item.name.toLowerCase().contains(_query) ||
        item.icon.label.toLowerCase().contains(_query) ||
        item.tags.any((tag) => tag.toLowerCase().contains(_query));
  }

  void _clearFilters() => setState(() {
    _selected.clear();
    _query = '';
    _search.clear();
  });

  /// Each matching waypoint once, which is what export and every count of "how
  /// many are there" has to be built from.
  List<Waypoint> get _visible =>
      widget.store.items.where(_matches).toList();

  /// Headers interleaved with waypoints: one section per tag, then untagged.
  ///
  /// A waypoint with three tags appears in three sections. That is what a tag
  /// is, and it is why [_visible] and not this is the answer to how many
  /// waypoints there are.
  ///
  /// Which tags get a section depends on whether a filter is on. With nothing
  /// filtered, every tag in use does, because the list is then the whole of what
  /// the user has. With a filter on, only the tags being filtered on do: asking
  /// for the ridge and being shown a `north` section nobody asked for is noise,
  /// and it made the `ridge` chip say 2 while the `ridge` section said 1. Now
  /// the chip and the section agree, and two tags picked under "any of these"
  /// give exactly the two sections that were asked for.
  ///
  /// Sections are alphabetical because tags have no inherent order and looking
  /// one up by eye is the only thing the order has to support. Untagged is last
  /// rather than first or alphabetical: it is the section nobody is looking for,
  /// and it exists so that a waypoint with no tags cannot silently vanish out
  /// of the list.
  List<Object> get _rows {
    final items = _visible
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    // Picked tags, not merely "something is filtering": a search narrows which
    // items are here without saying anything about which tags to section by, and
    // keying this off the wider question left a search showing untagged only.
    final tags = _selected.isNotEmpty
        ? (_selected.toList()..sort())
        : (<String>{for (final item in items) ...item.tags}.toList()..sort());
    final rows = <Object>[];
    for (final tag in tags) {
      final inTag = items.where((item) => item.tags.contains(tag)).toList();
      // A selected tag can match nothing at all under "any of these", and a
      // header reading "creek · 0" over nothing is not a section.
      if (inTag.isEmpty) continue;
      rows.add(_Section(tag, inTag.length));
      rows.addAll(inTag);
    }
    final untagged = items.where((item) => item.tags.isEmpty).toList();
    if (untagged.isNotEmpty) {
      rows.add(_Section(null, untagged.length));
      rows.addAll(untagged);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        // Named for both, because both have always been in here. A recorded walk
        // is saved to this list and drawn from it, and someone looking for one
        // scans for the word track — which appeared nowhere in the page that
        // held it.
        title: const Text('Waypoints & tracks'),
        actions: [
          PopupMenuButton<WaypointFormat>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            enabled: visible.isNotEmpty,
            onSelected: (format) => _transfer.share(visible, format),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  _filtered
                      ? 'Exports the ${visible.length} shown'
                      : 'Exports all ${visible.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: WaypointFormat.gpx,
                child: Text('GPX — Garmin, CalTopo, onX'),
              ),
              const PopupMenuItem(
                value: WaypointFormat.kml,
                child: Text('KML — Google Earth, folders per icon'),
              ),
              const PopupMenuItem(
                value: WaypointFormat.geoJson,
                child: Text('GeoJSON — keeps everything, for backup'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Import GPX, KML, or GeoJSON',
            icon: const Icon(Icons.file_open),
            onPressed: _import,
          ),
          // Behind an overflow rather than an icon of its own. Everything else up
          // here is reversible or additive; this is the only button on the screen
          // that can remove a season's work in one tap, and it should not sit at
          // thumb height next to the one that shares the file.
          PopupMenuButton<String>(
            // Not 'More': each row has one of those, and a tooltip that appears
            // twice on a screen is one a test cannot tell apart either.
            tooltip: 'Actions for the whole list',
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _openBackups,
                // The state of things is on the menu item rather than only on
                // the screen behind it, because somebody who has never made a
                // backup is exactly the person who never opens the backup
                // screen. Said as a fact, and coloured only in the case where
                // there is genuinely everything to lose.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Backup & restore…'),
                    const SizedBox(height: 2),
                    Text(
                      _backups.summary(widget.store.items.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _backups.needsAttention(widget.store.items.length)
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: visible.isNotEmpty,
                onTap: _deleteShown,
                child: Text(
                  _filtered
                      ? 'Delete the ${visible.length} shown…'
                      : 'Delete all ${visible.length}…',
                ),
              ),
            ],
          ),
        ],
      ),
      // Not "Add here". This saves the camera centre of a map that is not even on
      // screen, and "here" reads as where the person is standing — which the map
      // now has its own button for. Two actions a hundred metres apart should not
      // share a word.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add at map centre'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.store.items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nothing saved yet.\nAdd a waypoint at the last identified '
                  'point or the current map center, or record a track from '
                  'the map.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                _filterBar(),
                if (visible.isEmpty)
                  Expanded(child: _nothingMatches())
                else ...[
                  _tally(visible, rows.whereType<Waypoint>().length),
                  Expanded(child: _list(rows)),
                ],
              ],
            ),
    );
  }

  /// An empty list with a filter on, saying which filter and how to leave.
  ///
  /// The one screen in this app where an empty list can read as lost data, so it
  /// names the thing doing the hiding and states the count still saved. "Nothing
  /// matches this filter" did neither, and with a search added there would be two
  /// possible culprits and no way to tell which.
  Widget _nothingMatches() {
    final held = describeItems(widget.store.items);
    final tags = (_selected.toList()..sort()).join(', ');
    // What was typed, not the lowered form matching runs on: quoting someone's
    // search back at them in a case they did not use reads as a transcription
    // error in the app.
    final typed = _search.text.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              switch ((_query.isNotEmpty, _selected.isNotEmpty)) {
                (true, true) =>
                  'Nothing matching "$typed" carries '
                      '${_matchAll ? 'all of' : 'any of'} $tags.',
                (true, false) => 'Nothing matches "$typed".',
                _ =>
                  'Nothing carries ${_matchAll ? 'all of' : 'any of'} $tags.',
              },
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Still saved: $held.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Show everything'),
            ),
          ],
        ),
      ),
    );
  }

  /// How much is in here, said plainly and by kind.
  ///
  /// Load-bearing rather than decoration. The section counts deliberately add
  /// up to more than the number of items, so without a stated total the list
  /// implies it holds more than it does — and how much you have is the one
  /// figure nobody should have to work out.
  Widget _tally(List<Waypoint> shown, int rows) {
    final counted = _filtered
        ? '${shown.length} of ${describeItems(widget.store.items)} shown'
        : describeItems(shown);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        rows > shown.length
            ? '$counted · $rows rows below, because an item appears under '
                  '${_selected.isNotEmpty ? 'each of the tags you picked' : 'each of its tags'}'
            : counted,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  /// The search field and the tag chips.
  ///
  /// The chips used to be one horizontally scrolling row, which put every tag
  /// past the third off the side of the screen with nothing to say they were
  /// there. They wrap now, so the only thing off screen is what the more chip
  /// counts, and the search above them is the other half of the answer: with
  /// enough tags, typing part of one is faster than reading a wall of them.
  Widget _filterBar() {
    final counts = widget.store.tagCounts;
    final all = counts.keys.toList()..sort();
    // A search narrows the chips as well as the list, because "find the tag I
    // want to filter on" is most of what the old row made hard. A tag already
    // picked stays regardless: taking it away would leave a filter in force with
    // nothing on screen to switch it off.
    final matching = _query.isEmpty
        ? all
        : all
              .where(
                (tag) =>
                    tag.toLowerCase().contains(_query) ||
                    _selected.contains(tag),
              )
              .toList();
    final overflowing = !_showAllTags && matching.length > _tagChipLimit;
    // Selected tags are never among the hidden, for the same reason.
    final shown = overflowing
        ? [
            ...matching.take(_tagChipLimit),
            ...matching.skip(_tagChipLimit).where(_selected.contains),
          ]
        : matching;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              // Says what it looks at, so that a hit on a tag or a glyph name is
              // an answer rather than a surprise, and so the one field it does
              // not read is discoverable as an absence.
              hintText: 'Search names, tags and icons',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _query = '';
                        _search.clear();
                      }),
                    ),
            ),
            onChanged: (text) =>
                setState(() => _query = text.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('All ${widget.store.items.length}'),
                selected: !_filtered,
                // Clears the search too. It is the chip that means "show me
                // everything", and leaving a search running under it would make
                // it lie.
                onSelected: (_) => _clearFilters(),
              ),
              // Shown whether or not it currently changes anything, because a
              // filter whose rule is invisible until it bites is worse than a
              // chip that sometimes says something obvious.
              if (all.isNotEmpty)
                ActionChip(
                  avatar: Icon(
                    _matchAll ? Icons.join_inner : Icons.join_left,
                    size: 16,
                  ),
                  label: Text(
                    _matchAll ? 'All of these tags' : 'Any of these tags',
                  ),
                  tooltip: _matchAll
                      ? 'Matching every selected tag. Tap to match any.'
                      : 'Matching any selected tag. Tap to match all.',
                  onPressed: () => setState(() => _matchAll = !_matchAll),
                ),
              for (final tag in shown) _tagChip(tag, counts[tag]!),
              if (overflowing)
                ActionChip(
                  avatar: const Icon(Icons.more_horiz, size: 16),
                  label: Text('${matching.length - _tagChipLimit} more'),
                  onPressed: () => setState(() => _showAllTags = true),
                )
              else if (_showAllTags && matching.length > _tagChipLimit)
                ActionChip(
                  avatar: const Icon(Icons.expand_less, size: 16),
                  label: const Text('Fewer'),
                  onPressed: () => setState(() => _showAllTags = false),
                ),
              if (_query.isNotEmpty && matching.isEmpty && all.isNotEmpty)
                // Otherwise a search matching only names reads as though the
                // tags had gone missing.
                Chip(
                  avatar: const Icon(Icons.label_off_outlined, size: 16),
                  label: const Text('No tag matches this search'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// A tag's own chip, wearing the tag's own styling.
  ///
  /// This and the section header are the only two places tag styling appears.
  /// It describes the tag, so it belongs where the tag is the thing on screen;
  /// a waypoint can carry several tags, and a row or a map symbol drawn from one
  /// of them would be picking a winner with nothing to pick on.
  Widget _tagChip(String tag, int count) {
    final style = _tagStyles.styleFor(tag);
    return FilterChip(
      avatar: Icon(
        style.icon?.icon ?? Icons.label_outline,
        size: 16,
        color: style.colour?.value,
      ),
      label: Text('$tag $count'),
      selected: _selected.contains(tag),
      onSelected: (on) => setState(() {
        if (on) {
          _selected.add(tag);
        } else {
          _selected.remove(tag);
        }
      }),
    );
  }

  Widget _list(List<Object> rows) => ListView.builder(
    // Room to scroll the last row out from under the add button, which otherwise
    // sits on top of its overflow menu — so the one item you could never rename,
    // delete or hide was whichever one happened to be last.
    padding: const EdgeInsets.only(bottom: 88),
    itemCount: rows.length,
    itemBuilder: (context, index) => switch (rows[index]) {
      _Section(:final tag, :final count) => _header(tag, count),
      final Waypoint waypoint => _row(waypoint),
      _ => const SizedBox.shrink(),
    },
  );

  Widget _header(String? tag, int count) {
    final style = tag == null ? const TagStyle() : _tagStyles.styleFor(tag);
    final tagHidden = tag != null && widget.visibility.isTagHidden(tag);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          Icon(
            style.icon?.icon ?? (tag == null ? Icons.label_off_outlined : Icons.label_outline),
            size: 18,
            color: style.colour?.value,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${tag ?? 'Untagged'} · $count',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (tag != null)
            IconButton(
              tooltip: tagHidden
                  ? 'Show "$tag" on map'
                  : 'Hide "$tag" from map',
              icon: Icon(
                tagHidden ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.visibility.setTagHidden(
                tag,
                hidden: !tagHidden,
              ),
            ),
          // Untagged gets the delete and nothing else. Styling and untagging
          // both need a tag to act on; deleting does not, and leaving it out was
          // what made an imported file impossible to clear.
          PopupMenuButton<String>(
            tooltip: tag == null
                ? 'Actions for untagged'
                : 'Actions for $tag',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (choice) => switch (choice) {
              'style' => _styleTag(tag!),
              'untag' => _removeTag(tag!),
              _ => tag == null ? _deleteUntagged() : _deleteTagged(tag),
            },
            itemBuilder: (context) => [
              if (tag != null) ...[
                const PopupMenuItem(
                  value: 'style',
                  child: Text('Style this tag…'),
                ),
                const PopupMenuDivider(),
                // Worded apart on purpose. The old single "Delete all {label}"
                // was unambiguous only while a waypoint could be in one group:
                // now that it can be in several, "delete these" and "take this
                // tag off these" are different enough that the wording has to
                // carry the difference on its own.
                PopupMenuItem(
                  value: 'untag',
                  child: Text('Remove "$tag" from these $count, keep them'),
                ),
              ],
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete these '
                  '${describeItems(tag == null ? _untaggedShown : _inSection(tag))}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Three visual states for a row's eye icon. The distinction matters because
  /// a tag-hidden item cannot be shown by toggling its own eye — the tag has to
  /// be unhidden first — and looking "shown" while invisible on the map reads
  /// as a bug.
  ({bool individuallyHidden, List<String> hidingTags}) _itemVisibility(
    Waypoint waypoint,
  ) => (
    individuallyHidden: widget.visibility.isItemHidden(waypoint.id),
    hidingTags: widget.visibility.hidingTagsFor(waypoint.tags),
  );

  Widget _row(Waypoint waypoint) {
    final isTrack = waypoint.isTrack;
    final vis = _itemVisibility(waypoint);
    // How far and how long, not how many fixes: the point count is an artefact
    // of the recording interval and tells the user nothing about the walk.
    final where = isTrack
        ? describeTrack(waypoint.track)
        : '${waypoint.latitude.toStringAsFixed(5)}, '
              '${waypoint.longitude.toStringAsFixed(5)}';
    // A tag that is keeping this item off the map is marked in the tag list
    // rather than announced on a line of its own. The row already lists its
    // tags, and naming one twice inside five lines reads as a glitch.
    final hidingTags =
        vis.individuallyHidden ? const <String>[] : vis.hidingTags;
    final tags = waypoint.tags.isEmpty
        ? ''
        : '\n${waypoint.tags.map((tag) => hidingTags.contains(tag) ? '#$tag (hidden)' : '#$tag').join(' ')}';
    // When a tag is hiding this item but the item itself was never toggled,
    // say so on the row rather than leaving the user to work out why the map
    // disagrees with the list.
    final hiddenByTagNote =
        hidingTags.isEmpty ? '' : 'Not drawn on the map\n';
    final subtitle = waypoint.notes.isEmpty
        ? '$hiddenByTagNote$where$tags'
        : '$hiddenByTagNote$where\n${waypoint.notes}$tags';
    return ListTile(
      // The waypoint's own glyph and its own colour, never the section's. The
      // same item appears under every tag it carries, and it has to be
      // recognisable as one item in all of them and, for a point, as the same
      // symbol the map draws.
      leading: Icon(
        // A track is drawn as a line here because that is all the map draws for
        // one — there is no symbol layer for tracks, so any glyph in this slot
        // was a picture of something that appears nowhere, and the only thing
        // telling a recorded walk apart from a point was the subtitle. This is
        // not conditional on whether the user picked a glyph, because the model
        // cannot tell: the default and the pin are the same value. The colour is
        // still theirs, and unlike the glyph the map really does draw the line in
        // it.
        waypoint.isTrack ? Icons.polyline : waypoint.icon.icon,
        color: waypoint.displayColour,
      ),
      title: Text(waypoint.name),
      subtitle: Text(subtitle),
      isThreeLine: waypoint.notes.isNotEmpty || waypoint.tags.isNotEmpty ||
          hiddenByTagNote.isNotEmpty,
      // The whole row, because a coordinate pair in a list is useless until you
      // can see where it is, so that is what tapping one should do. The explicit
      // button stays because nothing else on this row hints that it is tappable.
      onTap: () => _reveal(waypoint),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _eyeButton(waypoint, vis),
          IconButton(
            tooltip: 'Show on map',
            icon: const Icon(Icons.travel_explore),
            onPressed: () => _reveal(waypoint),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (choice) => switch (choice) {
              'edit' => _edit(waypoint),
              'follow' => _follow(waypoint, reversed: false),
              'reverse' => _follow(waypoint, reversed: true),
              _ => _delete(waypoint),
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              // Both directions are offered outright rather than behind a
              // prompt after starting: which way you are walking it is the whole
              // decision, and it is known before you set off.
              if (isTrack) ...[
                const PopupMenuItem(value: 'follow', child: Text('Follow')),
                const PopupMenuItem(
                  value: 'reverse',
                  child: Text('Follow in reverse'),
                ),
              ],
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  /// The eye icon for one row, in one of three states.
  ///
  /// Individually hidden: the user toggled this item off, and tapping again
  /// toggles it back. Hidden by tag: the item's own toggle was never touched
  /// but a tag is making it invisible; the eye is amber and tapping it offers
  /// to unhide the responsible tag rather than silently doing nothing. Shown:
  /// tapping hides the item individually.
  Widget _eyeButton(
    Waypoint waypoint,
    ({bool individuallyHidden, List<String> hidingTags}) vis,
  ) {
    if (vis.individuallyHidden) {
      return IconButton(
        // Not "Show on map": that is the button beside this one, and it flies
        // the camera instead. Two neighbours with one label and two jobs.
        tooltip: 'Draw on map again',
        icon: const Icon(Icons.visibility_off, size: 20),
        visualDensity: VisualDensity.compact,
        onPressed: () => widget.visibility.setItemHidden(
          waypoint.id,
          hidden: false,
        ),
      );
    }
    if (vis.hidingTags.isNotEmpty) {
      return IconButton(
        tooltip: 'Hidden by ${vis.hidingTags.map((t) => '#$t').join(', ')}',
        // A crossed-out tag rather than a differently tinted eye. This state has
        // to be told apart from "you hid this one" at a glance in sunlight, and
        // the theme's tertiary slot in this green scheme is a muted blue-teal
        // measured at rgb(61,99,115) against rgb(64,73,67) for a plain icon —
        // no distinction at all on a phone held at arm's length outdoors. The
        // shape says which of the two it is without relying on colour, and the
        // glyph is also the truth: the item's own eye was never touched.
        icon: const Icon(
          Icons.label_off,
          size: 20,
          color: Color(0xFF8D6E00),
        ),
        visualDensity: VisualDensity.compact,
        onPressed: () => _offerUnhideTag(waypoint, vis.hidingTags),
      );
    }
    return IconButton(
      tooltip: 'Hide from map',
      icon: const Icon(Icons.visibility, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: () => widget.visibility.setItemHidden(
        waypoint.id,
        hidden: true,
      ),
    );
  }

  void _offerUnhideTag(Waypoint waypoint, List<String> tags) {
    final label = tags.length == 1
        ? '#${tags.first}'
        : '${tags.length} tags';
    showMessage(
      context,
      'Hidden on the map because $label '
      '${tags.length == 1 ? "is" : "are"} hidden.',
      actionLabel: tags.length == 1 ? 'UNHIDE TAG' : 'UNHIDE TAGS',
      onAction: () async {
        for (final tag in tags) {
          await widget.visibility.setTagHidden(tag, hidden: false);
        }
      },
    );
  }

  /// Hands the waypoint back to the map, which owns the camera.
  void _reveal(Waypoint waypoint) =>
      Navigator.pop(context, RevealWaypoint(waypoint));

  /// Closes the list and asks the map to start following, since the map is where
  /// following happens and staying on this page to watch it would be useless.
  void _follow(Waypoint track, {required bool reversed}) =>
      Navigator.pop(context, FollowTrack(track, reversed: reversed));

  /// An empty list here would otherwise read as "you never saved anything".
  void _warnUnreadable(String path) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your waypoint file could not be read'),
      content: Text(
        'This list is empty because the saved file could not be parsed, not '
        'because it was empty. Nothing has been deleted: the file was moved to '
        '$path so that saving new waypoints cannot overwrite it.\n\n'
        'If you were running a newer build of the app, going back to it should '
        'read the file again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Future<void> _edit(Waypoint waypoint) async {
    final edited = await showWaypointEditor(
      context,
      existing: waypoint,
      knownTags: widget.store.tagsInUse,
      isNew: false,
    );
    if (edited == null) return;
    await widget.store.update(edited);
    if (mounted) setState(_pruneFilter);
  }

  /// Opens the backup screen, and takes the list back from it if it changed.
  ///
  /// Reached from the overflow rather than given a button of its own: it is the
  /// screen you want twice a year, sitting beside the other whole-list actions
  /// rather than competing with the ones used every time.
  Future<void> _openBackups() async {
    // A snackbar outlives the route that raised it, so a delete's UNDO followed
    // this screen and sat directly under the snapshot Restore buttons: two ways
    // back side by side, one of them silently expiring. Worse than the clutter,
    // it stayed tappable after a restore had replaced the whole list, which
    // would have put a waypoint back into a list it was never deleted from.
    // Leaving the list therefore ends the offers made about it.
    ScaffoldMessenger.of(context).clearSnackBars();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BackupPage(
          store: widget.store,
          tagStyles: _tagStyles,
          // The app hands the store a snapshot store of its own. Anything that
          // built a bare store — a test — still gets a screen that backs up and
          // restores; it simply has no history to show, which is the truth.
          snapshots: widget.store.snapshots ?? SnapshotStore(),
          record: _backups,
        ),
      ),
    );
    if (changed == true && mounted) setState(_pruneFilter);
  }

  /// Gives a tag an icon and a colour, or takes them away again.
  Future<void> _styleTag(String tag) async {
    final chosen = await showDialog<TagStyle>(
      context: context,
      builder: (context) => _TagStyleDialog(
        tag: tag,
        existing: _tagStyles.styleFor(tag),
      ),
    );
    if (chosen == null) return;
    await _tagStyles.setStyle(tag, chosen);
    if (mounted) setState(() {});
  }

  /// Deletes with an undo, because the button sits beside a tappable row and
  /// there is nowhere else a waypoint can be recovered from once it is gone.
  Future<void> _delete(Waypoint waypoint) async {
    // The order things were in, not the state to go back to: see undo.dart.
    final before = widget.store.items.toList();
    await widget.store.delete(waypoint.id);
    if (!mounted) return;
    setState(_pruneFilter);
    showMessage(
      context,
      'Deleted ${waypoint.name}.',
      actionLabel: 'UNDO',
      onAction: () async {
        await widget.store.replaceAll(
          restoreDeleted(
            current: widget.store.items,
            before: before,
            removed: [waypoint],
          ),
        );
        if (mounted) setState(() {});
      },
    );
  }

  /// The waypoints under one tag's header: the shown ones, which with a filter
  /// on can be fewer than carry the tag.
  ///
  /// Both bulk actions are scoped to this rather than to every carrier of the
  /// tag, because the header they are offered from states this number and the
  /// menu items say "these".
  List<Waypoint> _inSection(String tag) =>
      _visible.where((item) => item.tags.contains(tag)).toList();

  /// The untagged section's contents, on the same "shown, not held" footing as
  /// [_inSection].
  List<Waypoint> get _untaggedShown =>
      _visible.where((item) => item.tags.isEmpty).toList();

  /// Says so when the filter is hiding items that carry the tag and will
  /// therefore be left alone. Empty the rest of the time, which is most of it.
  String _scopeNote(String tag, Set<String> acting) {
    final untouched = widget.store.items
        .where((item) => item.tags.contains(tag) && !acting.contains(item.id))
        .toList();
    if (untouched.isEmpty) return '';
    return '\n\n${describeItems(untouched)} carrying "$tag" '
        '${untouched.length == 1 ? 'is' : 'are'} hidden by the filter and will '
        'not be touched.';
  }

  /// Takes a tag off a group of items without deleting any of them.
  ///
  /// Confirmed as well as undoable, like the delete below, because it silently
  /// changes many items at once — but worded so that nobody reaches for this
  /// expecting them to go, or for the delete expecting them to stay.
  Future<void> _removeTag(String tag) async {
    final section = _inSection(tag);
    final ids = section.map((item) => item.id).toSet();
    final confirmed = await _confirm(
      title: 'Remove "$tag" from ${describeItems(section)}?',
      body:
          'They stay exactly as they are. They lose this one tag, so any that '
          'had no other tag will move to the Untagged section.'
          '${_scopeNote(tag, ids)}',
      action: 'Remove the tag',
    );
    if (confirmed != true) return;
    // Where the tag sat in each item, so undo puts it back in place rather than
    // appending it, without reverting anything else about those items.
    final positions = {
      for (final item in section) item.id: item.tags.indexOf(tag),
    };
    await widget.store.removeTagFrom(tag, ids);
    if (!mounted) return;
    setState(_pruneFilter);
    showMessage(
      context,
      'Removed "$tag" from ${describeItems(section)}. Nothing was deleted.',
      actionLabel: 'UNDO',
      onAction: () async {
        await widget.store.replaceAll(
          restoreTag(
            current: widget.store.items,
            tag: tag,
            positions: positions,
          ),
        );
        if (mounted) setState(() {});
      },
    );
  }

  /// Deletes every item carrying a tag. Asks first, then still offers undo.
  Future<void> _deleteTagged(String tag) => _deleteMany(
    _inSection(tag),
    title: (items) => 'Delete $items tagged "$tag"?',
    body:
        'This deletes the items themselves, including any that also carry '
        'other tags, so they will go from those sections too.',
    extra: (ids) => _scopeNote(tag, ids),
  );

  /// Deletes the untagged items, which is the group an import lands in.
  ///
  /// This section used to be the one place with no bulk action, on the grounds
  /// that "delete everything with no tags" put the most destructive sweep on the
  /// list's least considered group. Importing inverted that: a CalTopo or
  /// iHunter file arrives as dozens of untagged items at once, so untagged went
  /// from the leftovers nobody thinks about to the pile most likely to need
  /// clearing — and it was the only pile that could not be cleared.
  ///
  /// Styling and untagging still have no meaning here: there is no tag to give a
  /// colour to, and none to take off.
  Future<void> _deleteUntagged() => _deleteMany(
    _untaggedShown,
    title: (items) => 'Delete $items with no tags?',
    body:
        'Only items carrying no tags at all. Anything with even one tag stays, '
        'whichever section it is showing in.',
  );

  /// Deletes everything the list is currently showing.
  ///
  /// Scoped to [_visible] because that is already what export means, and the two
  /// sitting in the same menu saying different things about the word "shown"
  /// would be worse than either. It is the one action that reaches items with no
  /// tag and no search term in common, which is why it exists at all.
  Future<void> _deleteShown() => _deleteMany(
    _visible,
    // Unfiltered, this is the whole list, and it must not be able to read as
    // anything smaller. A count alone does not do that: 92 of 92 looks the same
    // as 92 of 400 to someone who has not counted.
    title: (items) => _filtered
        ? 'Delete the $items shown?'
        : 'Delete everything? All $items.',
    body: _filtered
        ? 'Just what the filter and search are showing. Everything they are '
              'hiding stays.'
        : 'Nothing is filtered, so this is the entire list, tagged and '
              'untagged alike. Nothing will be left.',
  );

  /// Confirms, deletes, and offers one undo.
  ///
  /// Both a dialog and an undo, not one or the other: the confirmation is
  /// because this removes work that took a season to collect, and the undo is
  /// because a confirmation dialog is something people dismiss on reflex.
  ///
  /// [title] is given the phrase for the count so that every caller says "3
  /// waypoints and 1 track" the same way, and none of them can say "1 items".
  Future<void> _deleteMany(
    List<Waypoint> items, {
    required String Function(String items) title,
    required String body,
    String Function(Set<String> ids)? extra,
  }) async {
    if (items.isEmpty) return;
    final ids = items.map((item) => item.id).toSet();
    final confirmed = await _confirm(
      title: title(describeItems(items)),
      body:
          '$body You will get one chance to undo it.'
          '${extra?.call(ids) ?? ''}',
      action: 'Delete them',
    );
    if (confirmed != true) return;
    // The order things were in, not the state to go back to: see undo.dart.
    final before = widget.store.items.toList();
    final removed = await widget.store.deleteWhere(
      (item) => ids.contains(item.id),
    );
    if (!mounted) return;
    setState(_pruneFilter);
    showMessage(
      context,
      'Deleted ${describeItems(removed)}.',
      actionLabel: 'UNDO',
      onAction: () async {
        await widget.store.replaceAll(
          restoreDeleted(
            current: widget.store.items,
            before: before,
            removed: removed,
          ),
        );
        if (mounted) setState(() {});
      },
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );

  /// Drops filters for tags nothing carries any more.
  ///
  /// Otherwise the list is left filtered to a tag that no longer exists, showing
  /// "nothing matches this filter" over a list that has waypoints in it.
  void _pruneFilter() {
    final alive = widget.store.tagCounts.keys.toSet();
    _selected.removeWhere((tag) => !alive.contains(tag));
  }

  Future<void> _add() async {
    final location = widget.suggestedLocation;
    final draft = Waypoint(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Waypoint',
      latitude: location.latitude,
      longitude: location.longitude,
      notes: '',
      createdAt: DateTime.now(),
      // Carried over only when exactly one tag is being filtered on: adding
      // three waypoints along one ridge should not mean typing "ridge" three
      // times, but a waypoint born with four tags because four chips were lit
      // is a guess at what the user meant.
      tags: _selected.length == 1 ? [_selected.single] : const [],
    );
    final saved = await showWaypointEditor(
      context,
      existing: draft,
      knownTags: widget.store.tagsInUse,
      isNew: true,
    );
    if (saved == null) return;
    await widget.store.add(saved);
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    try {
      final imported = await _transfer.pickAndImport();
      if (imported == null) return;
      // Importing the same file twice used to double everything. Only our own
      // GeoJSON carries an id through an export, so this catches re-importing a
      // backup, which is the case that actually happens.
      final held = widget.store.items.map((item) => item.id).toSet();
      final fresh = imported
          .where((item) => !held.contains(item.id))
          .toList();
      await widget.store.replaceAll([...widget.store.items, ...fresh]);
      if (!mounted) return;
      setState(() {});
      final skipped = imported.length - fresh.length;
      showMessage(
        context,
        skipped == 0
            ? 'Imported ${describeItems(fresh)}.'
            : 'Imported ${describeItems(fresh)}, skipped $skipped already here.',
      );
    } catch (error) {
      if (!mounted) return;
      showMessage(context, 'Import failed: $error');
    }
  }
}

/// Picks the icon and colour for a tag.
///
/// Says out loud what the styling does and does not do, because "give this tag
/// a colour" is a sentence most people would expect to colour the waypoints
/// carrying it, and it deliberately does not.
class _TagStyleDialog extends StatefulWidget {
  const _TagStyleDialog({required this.tag, required this.existing});

  final String tag;
  final TagStyle existing;

  @override
  State<_TagStyleDialog> createState() => _TagStyleDialogState();
}

class _TagStyleDialogState extends State<_TagStyleDialog> {
  late WaypointIcon? _icon = widget.existing.icon;
  late WaypointColour? _colour = widget.existing.colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Style "${widget.tag}"'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shown on this tag\'s chip and on its section heading. It does '
                'not change how the waypoints themselves are drawn — a waypoint '
                'can carry several tags, so it keeps its own icon and colour.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('Colour', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _NoneChip(
                    label: 'No colour',
                    selected: _colour == null,
                    onTap: () => setState(() => _colour = null),
                  ),
                  for (final colour in WaypointColour.values)
                    _ColourDot(
                      colour: colour,
                      selected: _colour == colour,
                      onTap: () => setState(() => _colour = colour),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Icon', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _NoneChip(
                    label: 'No icon',
                    selected: _icon == null,
                    onTap: () => setState(() => _icon = null),
                  ),
                  // Glyph only, with the name in the tooltip and the semantics
                  // label: thirty labelled chips would be a longer dialog than
                  // the screen, and here the glyph is all that will be shown.
                  for (final icon in WaypointIcon.values)
                    IconButton(
                      tooltip: icon.label,
                      isSelected: _icon == icon,
                      icon: Icon(icon.icon, semanticLabel: icon.label),
                      onPressed: () => setState(() => _icon = icon),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            TagStyle(icon: _icon, colour: _colour),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _NoneChip extends StatelessWidget {
  const _NoneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _ColourDot extends StatelessWidget {
  const _ColourDot({
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final WaypointColour colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: colour.label,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Semantics(
        label: colour.label,
        selected: selected,
        button: true,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colour.value,
            shape: BoxShape.circle,
            // An outline on every dot rather than only the selected one, so
            // white and black both stay visible against the dialog.
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.black26,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 16,
                  color:
                      ThemeData.estimateBrightnessForColor(colour.value) ==
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
