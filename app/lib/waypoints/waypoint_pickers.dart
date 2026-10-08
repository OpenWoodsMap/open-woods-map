/// The icon and colour choices shared by the waypoint editor and bulk edit.
library;

import 'package:flutter/material.dart';

import 'waypoint_icon.dart';

/// One glyph in the icon grid, with no name beside it.
///
/// Names made the grid four times taller than it needed to be, and with these
/// icons in six titled groups the heading and the glyph together are usually
/// enough to find the one you want. The name is still reachable: the row above
/// the grid names whatever is selected, and a long press names any of them.
/// [WaypointIcon.label] stays in the data either way, which is what a search
/// across icons would match on.
class IconChoice extends StatelessWidget {
  const IconChoice({
    super.key,
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

class ColourSwatch extends StatelessWidget {
  const ColourSwatch({
    super.key,
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
