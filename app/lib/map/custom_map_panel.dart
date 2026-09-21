import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'custom_map.dart';
import 'custom_map_store.dart';

/// Picks a map file, or returns null when the user backed out.
///
/// Injectable so the panel can be widget-tested: a file picker is a platform
/// dialog, and the parts of this worth testing are what the panel says when the
/// file is refused.
typedef CustomMapPicker = Future<({String name, Uint8List bytes})?> Function();

/// The user's own maps: imported files and tile URLs.
///
/// A panel of its own rather than a section of the basemap sheet, because these
/// are not a one-of-N choice. A borrowed map covers part of the ground at best —
/// one park, one management unit — so it layers over a basemap rather than
/// replacing it, and several can be on at once with the basemap still doing the
/// work outside their edges.
class CustomMapPanel extends StatefulWidget {
  const CustomMapPanel({
    super.key,
    required this.store,
    required this.onShow,
    this.picker,
  });

  final CustomMapStore store;

  /// Frames the map on a layer's coverage.
  ///
  /// The first question about an imported map is always whether it landed on the
  /// right ground, and the second is where it went if it did not. Both are
  /// answered by going there, and neither is answered by a row in a list.
  final void Function(GeoBox extent) onShow;

  final CustomMapPicker? picker;

  @override
  State<CustomMapPanel> createState() => _CustomMapPanelState();
}

class _CustomMapPanelState extends State<CustomMapPanel> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My maps', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    const Text(
                      'Maps you bring yourself, drawn over the basemap and '
                      'under the land layers. Where two cover the same ground, '
                      'the one higher in this list wins.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    if (widget.store.maps.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Nothing added yet. An imported map file works with '
                          'no signal; a tile URL needs one.',
                        ),
                      ),
                    // Newest first, so a map you just added is at the top of the
                    // list and on top of the map, which is where adding a layer
                    // anywhere else puts it.
                    for (final map in widget.store.maps.reversed)
                      _MapRow(
                        map: map,
                        store: widget.store,
                        onShow: widget.onShow,
                        onRemove: () => _remove(map),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Import a map file'),
                        onPressed: _busy || !widget.store.canImportFiles
                            ? null
                            : _import,
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('Add a tile URL'),
                        onPressed: _busy ? null : _addTiles,
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(CustomMap map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${map.name}?'),
        content: Text(
          map is FileMap
              ? 'The images are deleted from this phone. The file you imported '
                  'from is untouched, so you can add it again.'
              : 'The address is forgotten. Nothing else is affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.store.remove(map.id);
  }

  Future<void> _import() async {
    final pick = widget.picker ?? _pickKmz;
    setState(() => _busy = true);
    try {
      final chosen = await pick();
      if (chosen == null) return;
      final result = await widget.store.importArchive(
        chosen.bytes,
        fileName: chosen.name,
      );
      if (!mounted) return;
      // Framed straight away rather than waiting to be asked. An import that
      // says "done" and changes nothing on screen is indistinguishable from one
      // that put the map on the wrong continent.
      final extent = result.map.extent;
      if (extent != null) widget.onShow(extent);
      await _tell(
        'Added ${result.map.name}',
        result.isComplete
            ? 'Drawn from ${result.kept} '
                '${result.kept == 1 ? 'image' : 'images'}.'
            : 'Drawn from ${result.kept} of the ${result.asked} images it lists. '
                'The rest were not inside the file, so parts of it will be '
                'missing.',
      );
    } on CustomMapUnreadable catch (error) {
      await _tell('That file could not be used', error.message);
    } catch (error) {
      await _tell('That file could not be read', '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTiles() async {
    final added = await showDialog<_TileEntry>(
      context: context,
      builder: (context) => const _TileUrlDialog(),
    );
    if (added == null) return;
    try {
      await widget.store.addTiles(
        name: added.name,
        template: added.url,
        credit: added.credit,
      );
    } on CustomMapUnreadable catch (error) {
      await _tell('That address could not be used', error.message);
    }
  }

  /// A dialog rather than a snackbar. These messages explain which part of a
  /// file the app could not take, which does not fit in a line, and a snackbar
  /// raised from inside a bottom sheet draws behind it anyway.
  Future<void> _tell(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

Future<({String name, Uint8List bytes})?> _pickKmz() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['kmz'],
    withData: true,
  );
  final file = result?.files.single;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (name: file.name, bytes: bytes);
}

class _MapRow extends StatelessWidget {
  const _MapRow({
    required this.map,
    required this.store,
    required this.onShow,
    required this.onRemove,
  });

  final CustomMap map;
  final CustomMapStore store;
  final void Function(GeoBox extent) onShow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final extent = map.extent;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: map.visible,
            onChanged: (value) => store.setVisible(map.id, value ?? false),
            title: Text(map.name),
            subtitle: Text(
              // Both halves matter and neither is decoration. The credit is
              // somebody's work, and whether it needs a connection decides
              // whether it is there when it is needed.
              [
                if (map.credit.isNotEmpty) map.credit,
                switch (map) {
                  FileMap map =>
                    '${map.overlays.length} images on this phone · works offline',
                  TileMap _ => 'Tiles from the web · needs network',
                },
              ].join('\n'),
              style: const TextStyle(fontSize: 11),
            ),
            isThreeLine: map.credit.isNotEmpty,
            secondary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (extent != null)
                  IconButton(
                    tooltip: 'Go to it',
                    icon: const Icon(Icons.my_location, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      onShow(extent);
                    },
                  ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
          if (map.visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.opacity, size: 16, color: Colors.black54),
                  Expanded(
                    child: Slider(
                      // Not down to zero: a map faded to nothing is
                      // indistinguishable from one that failed to load, and the
                      // checkbox above already means off.
                      min: 0.2,
                      max: 1,
                      divisions: 8,
                      value: map.opacity.clamp(0.2, 1),
                      label: '${(map.opacity * 100).round()}%',
                      onChanged: (value) => store.setOpacity(map.id, value),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TileEntry {
  const _TileEntry({required this.name, required this.url, required this.credit});

  final String name;
  final String url;
  final String credit;
}

class _TileUrlDialog extends StatefulWidget {
  const _TileUrlDialog();

  @override
  State<_TileUrlDialog> createState() => _TileUrlDialogState();
}

class _TileUrlDialogState extends State<_TileUrlDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _credit = TextEditingController();

  /// Checked as they type rather than on submit, so the message about {z}/{x}/{y}
  /// arrives while the URL is still in front of them.
  String? get _complaint =>
      _url.text.trim().isEmpty ? null : checkTileUrl(_url.text).complaint;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _credit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaint = _complaint;
    return AlertDialog(
      title: const Text('Add a tile URL'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'What to call it in the list',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              autocorrect: false,
              // A keyboard that offers to fix "MapServer" to "Map server" turns
              // a good URL into one that passes every check and fetches nothing.
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Tile URL',
                hintText: 'https://example.com/tiles/{z}/{x}/{y}.png',
                errorText: complaint,
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _credit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Credit',
                hintText: 'Who made it',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tiles are fetched as you pan, so this one needs a connection. '
              'Saving an offline area does not include it.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: complaint != null || _url.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _TileEntry(
                      name: _name.text,
                      url: _url.text,
                      credit: _credit.text,
                    ),
                  ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
