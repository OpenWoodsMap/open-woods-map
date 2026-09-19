import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:open_woods_map/map/walking_location.dart';

void main() {
  group('recording a walk on Android', () {
    final settings = walkingLocationSettings(TargetPlatform.android);

    // The whole bug. Without a foreground service Android stops delivering
    // location to a backgrounded app, and a phone in a pocket is a backgrounded
    // app, so a recorded walk came out as straight lines between the moments the
    // screen happened to be awake.
    test('asks for a foreground service', () {
      expect(settings, isA<AndroidSettings>());
      expect(
        (settings as AndroidSettings).foregroundNotificationConfig,
        isNotNull,
      );
    });

    // The half that is easy to leave out, and the service alone does not fix it:
    // without a wake lock the system still sleeps and delivers the fixes in a
    // clump when it wakes, which is the same missing walk arriving later.
    test('holds a wake lock, so fixes arrive as they happen', () {
      final config =
          (settings as AndroidSettings).foregroundNotificationConfig!;
      expect(config.enableWakeLock, isTrue);
    });

    // Holding the GPS costs battery, and this notice is the disclosure. Being
    // undismissable is the point: it should last as long as the drain does.
    test('says what it is doing and what it costs, undismissably', () {
      final config =
          (settings as AndroidSettings).foregroundNotificationConfig!;
      expect(config.setOngoing, isTrue);
      expect(config.notificationTitle, isNotEmpty);
      expect(config.notificationText.toLowerCase(), contains('battery'));
    });

    test('still filters out fixes from standing still', () {
      expect(settings.distanceFilter, walkingDistanceFilterMetres);
      expect(settings.accuracy, LocationAccuracy.high);
    });
  });

  // Asking for background updates on iOS without UIBackgroundModes in Info.plist
  // fails at runtime, and no iOS build has ever been compiled here. Plain settings
  // are the honest answer until somebody can actually run one.
  test('other platforms get plain settings rather than an untested guess', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      final settings = walkingLocationSettings(platform);
      expect(settings, isNot(isA<AndroidSettings>()));
      expect(settings.distanceFilter, walkingDistanceFilterMetres);
    }
  });
}
