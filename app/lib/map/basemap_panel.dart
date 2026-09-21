import 'package:flutter/material.dart';

import 'basemap.dart';

/// The basemap chooser shown in a bottom sheet.
///
/// A widget of its own rather than a closure inside the map shell, so the
/// "is every option actually reachable" case can be tested. It was not: on a
/// short landscape screen the sheet capped near half the height and the last
/// basemap sat below the bottom edge with no way to scroll to it.
class BasemapPanel extends StatelessWidget {
  const BasemapPanel({
    super.key,
    required this.selected,
    required this.onPick,
    required this.onMyMaps,
    this.customCount = 0,
    this.customDrawn = 0,
  });

  final BasemapKind selected;
  final ValueChanged<BasemapKind> onPick;

  /// Opens the My maps panel. This sheet is where people look for "what is the
  /// picture under my data", so it is the door, but only the door: the maps the
  /// user brings are any number of layers with an opacity each, and putting that
  /// in the same list as a one-of-four choice would blur both.
  final VoidCallback onMyMaps;

  final int customCount;
  final int customDrawn;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // Leaves the sheet content-sized when it fits, and scrollable when it does
      // not, instead of letting a fixed cap decide.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Basemap'),
            subtitle: Text(
              'Streets and satellite need network. '
              'Offline works without tiles.',
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final kind in BasemapKind.values)
                  ListTile(
                    leading: Icon(kind.icon),
                    title: Text(kind.label),
                    subtitle: Text(kind.shortHint),
                    selected: kind == selected,
                    onTap: () => onPick(kind),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_outlined),
                  title: const Text('My maps'),
                  subtitle: Text(_customHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onMyMaps,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Says what is drawn rather than only what exists, because a map that is
  /// added but switched off looks from the map exactly like one that is not
  /// there, and that is the confusion worth heading off here.
  String get _customHint => switch ((customCount, customDrawn)) {
        (0, _) => 'Bring your own imagery, over the basemap',
        (final count, 0) =>
          '$count added, none drawn right now',
        (final count, final drawn) when drawn == count =>
          '$count drawn over the basemap',
        (final count, final drawn) => '$drawn of $count drawn',
      };
}
