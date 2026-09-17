/// When a backup file was last produced, and what was in it.
///
/// The honest limit of this, which the wording on screen has to respect: the app
/// knows it handed a file to the share sheet. It does not know the user kept it.
/// A backup sent to a chat and never opened again counts here exactly the same
/// as one saved to a synced folder. So this can say "you have not made one in a
/// while", which is true and useful, and must never say "your waypoints are
/// safe", which it has no way to know.
library;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupRecord extends ChangeNotifier {
  static const _atKey = 'backup.last_at';
  static const _countKey = 'backup.last_count';

  /// Long enough that an ordinary season does not nag, short enough that
  /// somebody who set the app up last spring is told before this autumn.
  static const old = Duration(days: 45);

  DateTime? _at;
  int _count = 0;

  /// When the last backup was made, or null if there has never been one.
  DateTime? get at => _at;

  /// How many items that backup held.
  int get count => _count;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _at = DateTime.tryParse(prefs.getString(_atKey) ?? '');
    _count = prefs.getInt(_countKey) ?? 0;
    notifyListeners();
  }

  Future<void> record({required DateTime when, required int items}) async {
    _at = when;
    _count = items;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_atKey, when.toUtc().toIso8601String());
    await prefs.setInt(_countKey, items);
  }

  /// Whether this is worth colouring as a warning rather than stating flatly.
  ///
  /// Only the two cases where somebody genuinely stands to lose everything:
  /// they have waypoints and have never made a backup, or the last one is old
  /// enough to predate a season. Having added a waypoint since the last backup
  /// is true of almost everybody almost always, and a warning that is always
  /// on is one nobody reads.
  bool needsAttention(int currentItems) {
    if (currentItems == 0) return false;
    final at = _at;
    return at == null || clock.now().difference(at) >= old;
  }

  /// One line about where things stand, in plain words.
  String summary(int currentItems) {
    final at = _at;
    if (at == null) {
      return currentItems == 0
          ? 'Nothing saved yet, so there is nothing to back up.'
          : 'You have never made a backup.';
    }
    final days = clock.now().difference(at).inDays;
    final when = switch (days) {
      0 => 'today',
      1 => 'yesterday',
      < 31 => '$days days ago',
      < 62 => 'about a month ago',
      _ => '${days ~/ 30} months ago',
    };
    final drift = currentItems - _count;
    return switch (drift) {
      0 => 'Last backup $when, and nothing has changed since.',
      // Said as a count rather than "out of date", because the number is what
      // tells somebody whether it matters to them.
      > 0 => 'Last backup $when. You have added $drift since then.',
      _ => 'Last backup $when. You have ${-drift} fewer than it holds.',
    };
  }
}
