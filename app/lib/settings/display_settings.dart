import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a waypoint is drawn as on the map.
///
/// Called a style rather than a "background", which is how the option was first
/// described, because what changes is the shape of the whole marker and not
/// just what sits behind it: the pin takes the waypoint's colour and the glyph
/// gives it up, so calling it a background would hide half of what the setting
/// does. Naming the shapes also leaves room for another one later without
/// rewording a checkbox that would by then be lying about being a boolean.
enum WaypointMarkerStyle {
  iconOnly(
    id: 'icon',
    label: 'Icon only',
    blurb: 'The pictogram alone, in the waypoint’s colour.',
  ),
  pin(
    id: 'pin',
    label: 'Icon in a pin',
    blurb:
        'A map pin in the waypoint’s colour with the pictogram inside it. '
        'Bigger and easier to pick out; the pin’s point marks the spot.',
  );

  const WaypointMarkerStyle({
    required this.id,
    required this.label,
    required this.blurb,
  });

  /// Stored in preferences, so it has to stay stable even if [label] is
  /// reworded.
  final String id;
  final String label;
  final String blurb;

  /// The pin is the default because its point marks the coordinate, where a
  /// centred glyph only sits near it, and because it holds its shape against a
  /// busy tenure fill. Editing this constant restyles the map for everybody who
  /// never opened Settings, including anyone who chose the old default back when
  /// it was the default and so has nothing written down. That is the deliberate
  /// price of the rule below: only a non-default choice is stored, so that the
  /// default stays free to improve.
  static const fallback = WaypointMarkerStyle.pin;

  static WaypointMarkerStyle fromId(String? id) => values.firstWhere(
        (style) => style.id == id,
        orElse: () => fallback,
      );
}

/// How large waypoint markers are drawn, as a multiplier on the sizes the map
/// has always used.
///
/// Named steps rather than a slider. The thing being chosen is whether a mark
/// can be found on a phone held at arm's length in daylight, which is a
/// judgement about legibility and not a continuous quantity; adjacent values of
/// a slider are indistinguishable, so it would offer a hundred choices where
/// there are four. The steps are spaced far enough apart to tell one from the
/// next, and a stored id survives a change of numbers in a way a raw double
/// does not.
enum WaypointMarkerSize {
  small(id: 'small', label: 'Small', multiplier: 0.8),
  standard(id: 'standard', label: 'Standard', multiplier: 1.0),
  large(id: 'large', label: 'Large', multiplier: 1.3),
  extraLarge(id: 'extra-large', label: 'Extra large', multiplier: 1.6);

  const WaypointMarkerSize({
    required this.id,
    required this.label,
    required this.multiplier,
  });

  /// Stored in preferences, so it has to stay stable even if [label] or
  /// [multiplier] is retuned.
  final String id;
  final String label;

  /// Applied to every marker size the map draws, so the proportions between a
  /// glyph, its pin and the arrows along a track stay as they were chosen.
  final double multiplier;

  static const fallback = WaypointMarkerSize.standard;

  static WaypointMarkerSize fromId(String? id) => values.firstWhere(
        (size) => size.id == id,
        orElse: () => fallback,
      );
}

/// Display choices that belong to the whole map rather than to one waypoint.
///
/// A [ChangeNotifier] because the map has to redraw the moment one changes: the
/// settings page sits over the map the user is complaining about, and making
/// them leave and come back to see the effect would make the choice impossible
/// to judge.
class DisplaySettings extends ChangeNotifier {
  DisplaySettings({
    WaypointMarkerStyle? markerStyle,
    WaypointMarkerSize? markerSize,
    bool lockNorth = lockNorthFallback,
  })  : _markerStyle = markerStyle ?? WaypointMarkerStyle.fallback,
        _markerSize = markerSize ?? WaypointMarkerSize.fallback,
        _lockNorth = lockNorth;

  /// Rotation stays on unless asked otherwise, because turning the map to match
  /// what is in front of you is how most people read one, and a build that
  /// silently took the gesture away would be a regression for everybody who
  /// never opens Settings.
  static const bool lockNorthFallback = false;

  /// Only a non-default choice is written, and the key is removed when the user
  /// goes back to the default. Same reason the overlay controller stores only
  /// the layers that are switched off: a preference written by this build must
  /// not pin a later build's default, so somebody who never touched the setting
  /// follows the app rather than being frozen on whatever was default the day
  /// they installed it.
  static const _markerStyleKey = 'waypoint.marker_style';
  static const _markerSizeKey = 'waypoint.marker_size';
  static const _lockNorthKey = 'map.lock_north';

  WaypointMarkerStyle _markerStyle;
  WaypointMarkerSize _markerSize;
  bool _lockNorth;

  WaypointMarkerStyle get markerStyle => _markerStyle;
  WaypointMarkerSize get markerSize => _markerSize;

  /// Whether the map is pinned with north at the top and rotation disallowed.
  bool get lockNorth => _lockNorth;

  /// Must be awaited before the map draws its waypoint layers, because they are
  /// built from these values and loading afterwards would draw the markers once
  /// at the default size and then again at the saved one.
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // An id this build does not recognise falls back rather than throwing. It
    // is the expected shape of a downgrade, and a display setting is never
    // worth failing a launch over.
    _markerStyle = WaypointMarkerStyle.fromId(prefs.getString(_markerStyleKey));
    _markerSize = WaypointMarkerSize.fromId(prefs.getString(_markerSizeKey));
    _lockNorth = prefs.getBool(_lockNorthKey) ?? lockNorthFallback;
    notifyListeners();
  }

  Future<void> setMarkerStyle(WaypointMarkerStyle style) async {
    if (style == _markerStyle) return;
    _markerStyle = style;
    notifyListeners();
    await _store(_markerStyleKey, style.id, style == WaypointMarkerStyle.fallback);
  }

  Future<void> setMarkerSize(WaypointMarkerSize size) async {
    if (size == _markerSize) return;
    _markerSize = size;
    notifyListeners();
    await _store(_markerSizeKey, size.id, size == WaypointMarkerSize.fallback);
  }

  Future<void> setLockNorth(bool value) async {
    if (value == _lockNorth) return;
    _lockNorth = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (value == lockNorthFallback) {
      await prefs.remove(_lockNorthKey);
    } else {
      await prefs.setBool(_lockNorthKey, value);
    }
  }

  Future<void> _store(String key, String id, bool isDefault) async {
    final prefs = await SharedPreferences.getInstance();
    if (isDefault) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }
}
