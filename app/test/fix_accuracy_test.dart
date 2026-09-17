import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/fix_accuracy.dart';

void main() {
  group('what a waypoint says about the fix it came from', () {
    // The ordinary case, and the reason there is a threshold at all. A phone under
    // open sky or light canopy is doing what a phone does, and a note on every
    // waypoint saying so is a note nobody reads.
    test('a good fix is not remarked on', () {
      expect(accuracyNote(3), isEmpty);
      expect(accuracyNote(12), isEmpty);
      expect(accuracyNote(accuracyWorthStating), isEmpty);
    });

    test('a rough fix says how rough, in plain words', () {
      expect(
        accuracyNote(38),
        'Saved from a GPS fix accurate to about 38 m.',
      );
    });

    // Rounded because the number is the device's own estimate of its error.
    // Reporting it to the centimetre would dress a guess up as a measurement,
    // which is the overclaiming the note exists to prevent.
    test('the figure is rounded rather than passed through', () {
      expect(accuracyNote(41.7), contains('about 42 m'));
      expect(accuracyNote(41.2), contains('about 41 m'));
      expect(accuracyNote(41.7), isNot(contains('41.7')));
    });

    // Geolocator reports accuracy as a double, and a platform that does not know
    // can hand back a non-finite one. "about NaN m" in somebody's notes is worse
    // than silence, and it would be stored and exported.
    test('a figure the platform could not supply is left unsaid', () {
      expect(accuracyNote(double.nan), isEmpty);
      expect(accuracyNote(double.infinity), isEmpty);
    });

    // Not the 50 m at which track recording drops a fix. A track is a line one
    // wild fix visibly ruins; a waypoint asked for by hand is never refused over
    // accuracy, because a spot known to be rough beats no spot at all.
    test('the threshold sits well below the one tracks reject at', () {
      expect(accuracyWorthStating, lessThan(50));
      expect(accuracyNote(49), isNotEmpty);
    });
  });
}
