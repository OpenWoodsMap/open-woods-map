import 'package:flutter/material.dart';

import 'overlay_controller.dart';

class LayerPanel extends StatelessWidget {
  const LayerPanel({super.key, required this.controller});

  final OverlayController controller;

  static const labels = {
    'crown_land': 'Crown land parcels',
    'crown_disposition': 'Leased & occupied Crown land',
    'municipal_forest': 'Municipal & county forests',
    'conservation_authority': 'Conservation authority land (permit)',
    'first_nations': 'Reserves (First Nation permission)',
    'parks': 'Provincial parks',
    'conservation_reserve': 'Conservation reserves (hunting permitted)',
    'game_preserve': 'Crown game preserves (no hunting)',
    'federal_closure': 'Wildlife areas & bird sanctuaries (no hunting)',
    'defence_land': 'Defence property (no hunting)',
    'land_use_plan': 'Far North & community land use plans',
    'wmu': 'Wildlife management units',
    'sunday_gun': 'Sunday gun hunting permitted',
    'municipalities': 'Municipalities (bylaws)',
    'fishing_access': 'Fishing access (launches & shore)',
  };

  /// Grouped by the question a layer answers, not by who publishes it. A layer
  /// a later pack adds before it is placed here lands in [otherGroup] rather
  /// than out of the list.
  static const groups = <(String, List<String>)>[
    (
      'Public land',
      [
        'crown_land',
        'crown_disposition',
        'municipal_forest',
        'conservation_authority',
      ],
    ),
    (
      'Parks & protected areas',
      [
        'parks',
        'conservation_reserve',
        'game_preserve',
        'federal_closure',
        'defence_land',
        'first_nations',
        'land_use_plan',
      ],
    ),
    ('Hunting rules & boundaries', ['wmu', 'sunday_gun', 'municipalities']),
    ('Fishing', ['fishing_access']),
  ];

  static const otherGroup = 'Other';

  static const _indent = EdgeInsets.only(left: 20);

  /// [available] split into [groups], in the order given, dropping groups the
  /// pack has nothing for.
  static List<(String, List<String>)> grouped(List<String> available) {
    final placed = {for (final (_, ids) in groups) ...ids};
    return [
      for (final (title, ids) in groups)
        if (ids.where(available.contains).toList() case final present
            when present.isNotEmpty)
          (title, present),
      if (available.where((id) => !placed.contains(id)).toList()
          case final rest when rest.isNotEmpty)
        (otherGroup, rest),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ConstrainedBox(
          // The layer list has outgrown a short sheet, and on a landscape
          // tablet it is taller than the screen. Cap the sheet and scroll the
          // list rather than letting the last few layers fall off the bottom
          // where nothing can reach them.
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Map layers',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (controller.toggleableLayerIds.isNotEmpty)
                          controller.allHidden
                              ? TextButton.icon(
                                  onPressed: controller.showLayers,
                                  icon: const Icon(Icons.layers),
                                  label: const Text('Show layers'),
                                )
                              : TextButton.icon(
                                  onPressed: controller.hideAll,
                                  icon: const Icon(Icons.layers_clear),
                                  label: const Text('Hide all'),
                                ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.allHidden
                          ? 'Hidden layers still answer when you tap the map.'
                          : 'Tap a colour to change it.',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  // Shrink-wrapped so a province with few layers still gets a
                  // sheet sized to its content instead of a fixed tall one.
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (controller.availableLayerIds.isEmpty)
                      const Text(
                        'No province pack is installed, so there are no '
                        'layers to draw. Download one from Offline packs.',
                      ),
                    for (final (title, ids)
                        in grouped(controller.availableLayerIds)) ...[
                      _GroupHeader(
                        title: title,
                        ids: ids
                            .where((id) => !controller.carriesNoFeatures(id))
                            .toList(),
                        controller: controller,
                      ),
                      for (final id in ids)
                        controller.carriesNoFeatures(id)
                            ? _UnavailableLayer(label: labels[id] ?? id)
                            : CheckboxListTile(
                                dense: true,
                                contentPadding: _indent,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(labels[id] ?? id),
                                value: controller.visibility[id] ?? false,
                                onChanged: (value) =>
                                    controller.setVisible(id, value ?? false),
                                secondary: _Swatch(
                                  color: controller.colorFor(id),
                                  customised: controller.isCustomColor(id),
                                  onTap: () => _pickColor(context, id),
                                ),
                              ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, String id) async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        title: labels[id] ?? id,
        current: controller.colorFor(id),
        defaultColor: OverlayController.defaultColorFor(id),
        customised: controller.isCustomColor(id),
      ),
    );
    if (selected == null) return;
    // An empty string is the dialog's way of saying "back to default", which is
    // distinct from null meaning the user dismissed without choosing.
    await controller.setColor(id, selected.isEmpty ? null : selected);
  }
}

/// A group's title, with a checkbox for the whole group when it has more than
/// one layer to switch. Part on reads as mixed, and a tap on mixed turns the
/// rest on: wanting the group is the likelier reason to reach for it.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.ids,
    required this.controller,
  });

  final String title;
  final List<String> ids;
  final OverlayController controller;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.6,
        );
    final heading = Text(title.toUpperCase(), style: style);
    if (ids.length < 2) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: heading,
      );
    }
    final on = ids.where((id) => controller.visibility[id] == true).length;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        tristate: true,
        title: heading,
        value: on == ids.length ? true : (on == 0 ? false : null),
        onChanged: (_) => controller.setVisibleAll(ids, on < ids.length),
      ),
    );
  }
}

/// A layer the pack declares but has no features for.
///
/// Shown rather than hidden, because the pack says this province is meant to
/// have the layer and silence would read as "there are none here". Disabled
/// rather than toggleable, because there is nothing for a toggle to reveal.
class _UnavailableLayer extends StatelessWidget {
  const _UnavailableLayer({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).disabledColor;
    return ListTile(
      dense: true,
      enabled: false,
      contentPadding: LayerPanel._indent,
      leading: Icon(Icons.remove_circle_outline, size: 20, color: muted),
      title: Text(label, style: TextStyle(color: muted)),
      subtitle: Text(
        'No data in this pack yet, which is not the same as none existing.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.customised,
    required this.onTap,
  });

  final String color;
  final bool customised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: customised ? 'Custom colour' : 'Default colour',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: parseHexColor(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: customised
                  ? const Icon(Icons.edit, size: 12, color: Colors.black54)
                  : null,
            ),
          ),
        ),
      );
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog({
    required this.title,
    required this.current,
    required this.defaultColor,
    required this.customised,
  });

  final String title;
  final String current;
  final String defaultColor;
  final bool customised;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: OverlayController.palette.map((hex) {
              final isCurrent =
                  hex.toUpperCase() == current.toUpperCase();
              return InkWell(
                onTap: () => Navigator.pop(context, hex),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: parseHexColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent
                          ? Colors.black87
                          : Colors.black.withValues(alpha: 0.3),
                      width: isCurrent ? 3 : 1,
                    ),
                  ),
                  child: isCurrent
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          if (customised)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Reset to default'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      );
}

/// Parses `#RRGGBB` as used in the layer styles and MapLibre paint properties.
Color parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '').trim();
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null || cleaned.length != 6) return const Color(0xFF2E7D32);
  return Color(0xFF000000 | value);
}
