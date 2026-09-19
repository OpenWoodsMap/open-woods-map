/// The location settings a walk is recorded and followed with.
///
/// Its own file so the one thing standing between a recorded walk and a row of
/// straight lines can be asserted in a test. The map shell cannot be
/// widget-tested against a native MapLibre view, and a regression here is silent:
/// the app runs, the recording bar counts up, and the damage only appears
/// afterwards in a track that cuts through bush the walker went around.
library;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Standing still otherwise piles up fixes at one spot, which inflates a recorded
/// track's point count and its length with pure noise.
const walkingDistanceFilterMetres = 5;

/// Settings that survive the screen going off.
///
/// Android stops delivering location to a backgrounded app, and a phone in a
/// pocket with the screen off is a backgrounded app. Without the foreground
/// service below, the only fixes that landed were from the moments somebody woke
/// the screen to check on the recording — joined up afterwards as though they had
/// walked those straight lines through the bush. The recording never said anything
/// was missing, which is what made it worth fixing rather than documenting.
///
/// [ForegroundNotificationConfig.enableWakeLock] is the half that is easy to leave
/// out, and the service alone does not fix it. Geolocator's own note on the flag:
/// without it "the system can still sleep and all location events will be received
/// at once when the system wakes up again" — for a track, the same missing walk,
/// arriving later in a clump.
///
/// The battery cost is real, and the notification is how it is disclosed rather
/// than discovered. `setOngoing` keeps it undismissable for as long as the GPS is
/// held, so the notice lasts as long as the drain.
///
/// Android gets the service and every other platform gets plain settings. iOS
/// needs `UIBackgroundModes` in Info.plist before
/// `AppleSettings.allowBackgroundLocationUpdates` may be asked for, and asking
/// without it fails at runtime. No iOS build has ever been compiled here, so
/// guessing at that configuration would ship a plausible-looking claim nobody has
/// tested. See docs/ios.md.
LocationSettings walkingLocationSettings(TargetPlatform platform) {
  if (platform != TargetPlatform.android) {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: walkingDistanceFilterMetres,
    );
  }
  return AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: walkingDistanceFilterMetres,
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationTitle: 'OpenWoodsMap has the GPS on',
      // Names the cost as well as the activity. The alternative is somebody
      // finding an unexplained battery drain behind a notification that says only
      // which app is responsible.
      notificationText:
          'Following your position so a track keeps recording with the screen '
          'off. This uses battery.',
      notificationChannelName: 'Recording and following',
      enableWakeLock: true,
      setOngoing: true,
    ),
  );
}
