/// The small card a tap on bare ground leaves behind.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import 'land_info.dart';
import 'land_info_sheet.dart'
    show featureTitle, huntingVerdict, verdictSoundsPermissive;

/// What a tapped spot is called, and what is worrying about it.
class SpotSummary {
  const SpotSummary(
    this.headline, {
    this.status,
    this.statusColour,
    this.detail,
    this.closed = false,
  });

  /// No province pack, so there is nothing to say about the ground at all. Not
  /// the same sentence as nothing being on record, which is an answer from a
  /// source rather than the absence of one.
  static const noData = SpotSummary('No province data for this spot');

  /// What the ground is called, named exactly as the full card names it.
  final String headline;

  /// The full card's own verdict, and its colour, where that verdict is not a
  /// permissive one. Null where a source says yes, or says nothing.
  final String? status;
  final Color? statusColour;

  /// Context that is true but is not an answer about the land, such as the
  /// wildlife management unit the spot falls in.
  final String? detail;

  /// True where a source refuses this ground outright.
  final bool closed;
}

/// What the card says about [info], in the full card's own words.
///
/// Two rules decide everything here.
///
/// A WMU never leads. It is the only member of the land-use list that is not a
/// landholding, and on unmapped private ground it is often the only hit, so
/// leading with it answered "whose land is this" with a hunting district — read
/// on a suburban street as though the street were open country. It moves to
/// [SpotSummary.detail], where it is worth having: seasons are set by unit.
///
/// The verdict travels only when it is not a yes. A closure or a condition has to
/// survive into this card, because a glance at a park's name would otherwise read
/// as permission on ground the regulation opens only part of. A permission does
/// not travel, because the sentence granting it is only honest beside the basis,
/// the quoted regulation and the coverage caveats, and those stay on the full
/// card. So this card can raise a doubt and never settle one.
SpotSummary spotSummary(LandInfo info, Map<String, LoadedLayer> layers) {
  final unit = info.wmuId == null ? null : 'WMU ${info.wmuId}';
  final leading = info.closures.firstOrNull ??
      info.landUse.firstWhereOrNull((feature) => feature.layerId != 'wmu');
  if (leading == null) {
    return SpotSummary('Nothing on record here', detail: unit);
  }
  final verdict = huntingVerdict(leading.huntingAllowed, leading.basis);
  final cautious = verdictSoundsPermissive(verdict) ? null : verdict;
  return SpotSummary(
    featureTitle(leading, layers[leading.layerId]),
    status: cautious?.$1,
    statusColour: cautious?.$2,
    closed: leading.huntingAllowed == false,
    detail: unit,
  );
}

/// What a tap on the map says, without taking the map away.
///
/// A tap used to open the full Land Info sheet outright. That is the right answer
/// when someone asked the question and the wrong one when they were panning and
/// caught the map with a thumb: a modal sheet over the whole screen had to be
/// dismissed before the map could be moved again. This is drawn over the map
/// rather than over a barrier, so pinching, rotating and panning carry on
/// underneath it, and the full card is one deliberate tap away.
class SpotCard extends StatelessWidget {
  const SpotCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.summary,
    required this.onLandInfo,
    required this.onSaveWaypoint,
    required this.onDismiss,
  });

  final double latitude;
  final double longitude;
  final SpotSummary summary;

  /// Null where there is no province pack to read, which disables the button
  /// rather than hiding it: the row keeps its shape, and the reason is already
  /// on screen in the banner that offers the download.
  final VoidCallback? onLandInfo;
  final VoidCallback onSaveWaypoint;
  final VoidCallback onDismiss;

  String get _coordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onSurface;
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  summary.closed ? Icons.block : Icons.place_outlined,
                  size: 20,
                  color: summary.closed ? theme.colorScheme.error : onContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: onContainer,
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
              ],
            ),
            // Under the name rather than in place of it, because which park or
            // preserve this is decides who the user has to ask.
            if (summary.status case final status?)
              Padding(
                padding: const EdgeInsets.only(left: 28, right: 8, bottom: 2),
                child: Text(
                  status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: summary.statusColour,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Long-pressable rather than a fourth button: copying a coordinate is
            // something a few people need badly and most never do, and the full
            // card has a labelled button for it.
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 2),
              child: GestureDetector(
                onLongPress: () async {
                  await Clipboard.setData(ClipboardData(text: _coordinates));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coordinates copied')),
                  );
                },
                child: Text(
                  switch (summary.detail) {
                    final unit? => '$unit  ·  $_coordinates',
                    null => _coordinates,
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onContainer.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 20),
                FilledButton.icon(
                  onPressed: onLandInfo,
                  icon: const Icon(Icons.travel_explore, size: 18),
                  label: const Text('Land info'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onSaveWaypoint,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Waypoint'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
