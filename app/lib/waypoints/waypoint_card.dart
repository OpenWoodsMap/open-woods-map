import 'package:flutter/material.dart';

import '../tracks/track_math.dart';
import '../tracks/track_preview.dart';
import 'waypoint_store.dart';

/// What the card asks the map to do once it closes.
sealed class WaypointCardRequest {
  const WaypointCardRequest();
}

final class EditFromCard extends WaypointCardRequest {
  const EditFromCard(this.waypoint);

  final Waypoint waypoint;
}

final class FollowFromCard extends WaypointCardRequest {
  const FollowFromCard(this.track, {required this.reversed});

  final Waypoint track;
  final bool reversed;
}

final class DeleteFromCard extends WaypointCardRequest {
  const DeleteFromCard(this.waypoint);

  final Waypoint waypoint;
}

/// Ask for Land Info at the spot that was tapped rather than about the track.
///
/// Exists because a track's line and markers are a wide target, so making a tap
/// on one open the track would otherwise take Land Info away from every strip of
/// ground the user has walked — which is the ground they are most likely to be
/// asking about.
final class LandInfoFromCard extends WaypointCardRequest {
  const LandInfoFromCard();
}

/// Take it off the map. It stays saved, and the list is where it comes back.
final class HideFromCard extends WaypointCardRequest {
  const HideFromCard(this.waypoint);

  final Waypoint waypoint;
}

/// Open the card for something else the same tap touched.
final class SwitchFromCard extends WaypointCardRequest {
  const SwitchFromCard(this.waypoint);

  final Waypoint waypoint;
}

/// What one of the user's own waypoints or tracks says when tapped on the map.
///
/// A tap used to do nothing at all on a waypoint, and on a track it opened Land
/// Info as though the user had tapped bare ground. Everything they might want to
/// do to a track was five taps away in the list.
///
/// [alsoHere] is whatever else the tap touched. The card opens on the likeliest
/// target rather than asking first, because a tap on one waypoint is far more
/// common than a tap on a stack, and a question every time would tax the common
/// case to serve the rare one. What it did not pick stays one tap away.
Future<WaypointCardRequest?> showWaypointCard(
  BuildContext context,
  Waypoint waypoint, {
  List<Waypoint> alsoHere = const [],
}) => showModalBottomSheet<WaypointCardRequest>(
  context: context,
  showDragHandle: true,
  // A stack of imported pins can be longer than half a screen.
  isScrollControlled: alsoHere.length > 3,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      child: _WaypointCard(waypoint: waypoint, alsoHere: alsoHere),
    ),
  ),
);

class _WaypointCard extends StatelessWidget {
  const _WaypointCard({required this.waypoint, required this.alsoHere});

  final Waypoint waypoint;
  final List<Waypoint> alsoHere;

  bool get _isTrack => waypoint.isTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(waypoint.icon.icon, color: waypoint.displayColour),
          title: Text(waypoint.name),
          // Where it is, or how far it goes. The icon's label used to lead this
          // line, back when it was a category and was the nearest thing to a
          // description; it is a picture now, and naming the picture would say
          // nothing the glyph beside it has not already said. What the waypoint
          // is, if the user said, is in the tags below.
          subtitle: Text(
            _isTrack
                ? describeTrack(waypoint.track)
                : '${waypoint.latitude.toStringAsFixed(5)}, '
                      '${waypoint.longitude.toStringAsFixed(5)}',
          ),
        ),
        // The look, shown rather than named, so the card is the same answer as
        // the line the user just tapped.
        if (_isTrack)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TrackPreview(
              colour: waypoint.displayColour,
              stroke: waypoint.stroke,
              marker: waypoint.marker,
            ),
          ),
        if (waypoint.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(waypoint.notes),
          ),
        if (waypoint.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              waypoint.tags.map((tag) => '#$tag').join(' '),
              style: theme.textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (_isTrack) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    FollowFromCard(waypoint, reversed: false),
                  ),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Follow'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    FollowFromCard(waypoint, reversed: true),
                  ),
                  icon: const Icon(Icons.u_turn_left),
                  label: const Text('Reverse'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, EditFromCard(waypoint)),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, const LandInfoFromCard()),
                icon: const Icon(Icons.travel_explore),
                label: const Text('Land info'),
              ),
              // "Hide", not "Hide from map": the card is on the map, and the
              // message the map raises says where it went.
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, HideFromCard(waypoint)),
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Hide'),
              ),
              // Deleting used to be kept off this card, on the reasoning that undo
              // lived in the list and a map tap was too short a distance for
              // something irreversible. Half of that was wrong: the person tapping
              // is looking straight at the thing they mean, which is a better
              // target than a name in a list of ninety. The other half is answered
              // by the map raising the same UNDO the list does, rather than by
              // making them go and find the row.
              //
              // Last in the row and the only button in the error colour, so it is
              // not a neighbour of Edit that a wide thumb finds by accident.
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, DeleteFromCard(waypoint)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
        ),
        if (alsoHere.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Also here',
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final other in alsoHere)
            ListTile(
              dense: true,
              // The same glyph the list gives it, so a track reads as a line
              // and not as a pin that is nowhere on the map.
              leading: Icon(
                other.isTrack ? Icons.polyline : other.icon.icon,
                color: other.displayColour,
              ),
              title: Text(other.name),
              subtitle: Text(other.isTrack ? 'Track' : 'Waypoint'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, SwitchFromCard(other)),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
