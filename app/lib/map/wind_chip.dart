import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../weather/weather.dart';

/// One wind reading, held so the map can show it without the weather card open.
///
/// A plain value rather than the whole [WeatherReport] it came out of, because
/// the chip needs four numbers and the report is a week of forecast. Keeping the
/// reading also keeps the moment it was taken, which is the difference between a
/// wind the user can act on and a wind from before they walked over the ridge.
class WindReading {
  const WindReading({
    required this.directionFrom,
    required this.speedKmh,
    required this.gustsKmh,
    required this.takenAt,
  });

  /// Where the wind is coming *from*, in degrees clockwise from true north.
  ///
  /// The meteorological convention, and the one Open-Meteo reports. Named for
  /// the direction it is rather than left as `direction`, because the sign error
  /// of reading it as "blowing toward" is invisible in code and puts a hunter
  /// downwind of the thing they are hunting.
  final int directionFrom;

  final double speedKmh;
  final double gustsKmh;

  /// Device clock when this was fetched, for saying how old it is.
  final DateTime takenAt;

  /// Where the air is going, which is the way the arrow points.
  int get directionTo => (directionFrom + 180) % 360;

  /// How far to turn an upward-pointing arrow so it follows the air across the
  /// map, in radians clockwise.
  ///
  /// [mapBearing] is MapLibre's camera bearing: the compass direction that is up
  /// the screen. Both it and the wind are measured from true north, so their
  /// difference is the whole calculation and no magnetic declination comes into
  /// it — which is why this arrow can be trusted where the parked heading arrow
  /// could not. Get the sign wrong and it points confidently the wrong way with
  /// nothing on screen to give it away, which is why it is a function with a test
  /// rather than an expression inside a widget.
  double screenRadians(double mapBearing) =>
      (directionTo - mapBearing) * math.pi / 180;

  /// Below this the reported direction is noise dressed as a bearing.
  ///
  /// The model always returns a direction, including for air that is barely
  /// moving, and an arrow is a confident claim about which way. Under 2 km/h
  /// leaves are still and scent pools rather than travels, so the chip says calm
  /// and draws no arrow instead of pointing somewhere it cannot support.
  bool get isCalm => speedKmh < 2;

  Duration get age => clock.now().difference(takenAt);

  String get headline => isCalm
      ? 'Calm'
      : 'From ${windCompass(directionFrom)} · ${speedKmh.round()} km/h';

  /// The small print, and there is some worth reading.
  ///
  /// "Toward" is here to settle what the arrow means: an arrow beside the words
  /// "from NW" can be read either way round, and this is the half of the chip
  /// that says which. The forecast caveat is not hedging either — Open-Meteo
  /// reports modelled wind ten metres up over a grid cell kilometres across, and
  /// under canopy the wind on the ground can sit still or run the other way. It
  /// is the right number to plan a morning with and the wrong one to bet a stalk
  /// on without checking, and the chip has to say which of those it is.
  String get detail {
    if (isCalm) return 'No steady direction · forecast, 10 m up';
    return [
      'Toward ${windCompass(directionTo)}',
      if (gustsKmh >= speedKmh + 10) 'gusts ${gustsKmh.round()}',
      'forecast, 10 m up',
      if (age.inMinutes >= 20) 'read ${age.inMinutes} min ago',
    ].join(' · ');
  }
}

/// The wind readout the map shows in its bottom corner.
///
/// Small on purpose. It answers one glanceable question and the full picture is
/// a tab away in Land Info, so it takes a corner rather than a panel. Tapping it
/// refreshes, which is what somebody who has read the age wants next; the cross
/// puts it away.
class WindChip extends StatelessWidget {
  const WindChip({
    super.key,
    required this.reading,
    required this.mapBearing,
    required this.refreshing,
    required this.onRefresh,
    required this.onDismiss,
  });

  /// Null while the first reading is still being fetched.
  ///
  /// The chip appears empty-handed rather than waiting to exist, because getting
  /// here takes a GPS fix and a network round trip. Showing nothing until both
  /// land meant the menu item looked broken for as long as fifteen seconds — the
  /// state this parameter exists to make visible.
  final WindReading? reading;

  /// Which way the map itself is turned, so the arrow can point at the ground
  /// rather than at the screen.
  ///
  /// Without this the arrow silently lies whenever the map is rotated, and the
  /// map rotates on a two-finger twist unless north is locked. Geographic
  /// bearings are relative to true north and so is MapLibre's camera bearing, so
  /// the difference is all that is needed and no magnetic declination comes into
  /// it — which is why this arrow can be trusted where the parked heading arrow
  /// could not.
  final double mapBearing;

  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFFFFBF0);
    final wind = reading;
    return Material(
      color: const Color(0xE61B4332),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: refreshing ? null : onRefresh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: refreshing
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ink,
                        ),
                      )
                    : wind == null || wind.isCalm
                        // A ring rather than an arrow, because there is no
                        // direction to draw and a faint arrow would still be read
                        // as one.
                        ? const Icon(Icons.circle_outlined,
                            size: 18, color: Color(0xFF76FF03))
                        : Transform.rotate(
                            // Icons.navigation points up the screen, which is
                            // whichever bearing the camera is facing.
                            angle: wind.screenRadians(mapBearing),
                            child: const Icon(Icons.navigation,
                                size: 20, color: Color(0xFF76FF03)),
                          ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wind?.headline ?? 'Reading the wind',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    Text(
                      // Both halves named, because either can be the slow one:
                      // the fix takes seconds under canopy and the forecast needs
                      // a connection at all.
                      wind?.detail ?? 'Waiting on a fix, then the forecast',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: ink.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Nothing to put away until there is something in it, and the
              // request resolves either way within its own time limit.
              if (wind != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: ink,
                  tooltip: 'Hide wind',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
