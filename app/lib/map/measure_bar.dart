import 'package:flutter/material.dart';

import 'measure.dart';

/// The bar shown while a distance is being measured.
///
/// Laid out like the recording and follow bars, and for the same reason: one big
/// number readable at arm's length, one quiet sentence under it saying what the
/// number covers or what to tap next. A mode the map is in gets a bar at the top,
/// consistently, so there is never a state the map is in that it does not admit
/// to — measuring changes what a tap does, so it has to be visible.
class MeasureBar extends StatelessWidget {
  const MeasureBar({
    super.key,
    required this.line,
    required this.onUndo,
    required this.onClear,
    required this.onDone,
  });

  final MeasureLine line;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onSurface;

    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, color: onContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Measuring',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Both disabled rather than hidden while the line is empty, so
                // the row does not reflow under a thumb that is already moving
                // toward Done.
                IconButton(
                  tooltip: 'Undo last point',
                  icon: const Icon(Icons.undo),
                  color: onContainer,
                  onPressed: line.isEmpty ? null : onUndo,
                ),
                IconButton(
                  tooltip: 'Clear the line',
                  icon: const Icon(Icons.clear_all),
                  color: onContainer,
                  onPressed: line.isEmpty ? null : onClear,
                ),
                IconButton(
                  tooltip: 'Done measuring',
                  icon: const Icon(Icons.close),
                  color: onContainer,
                  onPressed: onDone,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.headline,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line.detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
