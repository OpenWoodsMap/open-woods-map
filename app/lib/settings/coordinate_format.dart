import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app writes a coordinate for a person to read.
///
/// Only display. Exports, shares and map links stay in decimal degrees, which
/// is what every other tool reads, and the search box reads all four whatever
/// this is set to.
enum CoordinateFormat {
  decimal(id: 'decimal', label: 'Decimal degrees'),
  degreesMinutes(id: 'dm', label: 'Degrees and minutes'),
  degreesMinutesSeconds(id: 'dms', label: 'Degrees, minutes, seconds'),
  utm(id: 'utm', label: 'UTM');

  const CoordinateFormat({required this.id, required this.label});

  /// Stored in preferences, so it has to stay stable even if [label] is
  /// reworded.
  final String id;
  final String label;

  static const fallback = CoordinateFormat.decimal;

  static CoordinateFormat fromId(String? id) =>
      values.firstWhere((format) => format.id == id, orElse: () => fallback);

  /// [decimals] applies to decimal degrees only, so a card that has always
  /// shown six places keeps them.
  String format(
    double latitude,
    double longitude, {
    int decimals = 5,
  }) => switch (this) {
    decimal =>
      '${latitude.toStringAsFixed(decimals)}, '
          '${longitude.toStringAsFixed(decimals)}',
    degreesMinutes => '${_dm(latitude, 'N', 'S')}, ${_dm(longitude, 'E', 'W')}',
    degreesMinutesSeconds =>
      '${_dms(latitude, 'N', 'S')}, ${_dms(longitude, 'E', 'W')}',
    utm => utmGridReference(latitude, longitude),
  };
}

/// Three decimals of a minute is under two metres, finer than a phone fix.
String _dm(double value, String positive, String negative) {
  final thousandths = (value.abs() * 60000).round();
  final degrees = thousandths ~/ 60000;
  final minutes = (thousandths % 60000) / 1000;
  return '$degrees° ${minutes.toStringAsFixed(3)}′ '
      '${value < 0 ? negative : positive}';
}

/// Rounded as a whole before splitting, so 59.96″ carries into the next minute
/// rather than printing as 60.0″.
String _dms(double value, String positive, String negative) {
  final tenths = (value.abs() * 36000).round();
  final degrees = tenths ~/ 36000;
  final minutes = (tenths % 36000) ~/ 600;
  final seconds = (tenths % 600) / 10;
  return '$degrees° $minutes′ ${seconds.toStringAsFixed(1)}″ '
      '${value < 0 ? negative : positive}';
}

/// MGRS latitude bands from 80°S, eight degrees each, I and O left out. X
/// stretches to 84°N.
const _bands = 'CDEFGHJKLMNPQRSTUVWX';

/// A UTM grid reference to the metre, in the shape the search box reads back:
/// zone and band, then easting and northing.
///
/// Zones are the plain six-degree ones. The Norway and Svalbard exceptions
/// are far from anywhere this app has data.
String utmGridReference(double latitude, double longitude) {
  final zone = (((longitude + 180) / 6).floor() % 60) + 1;
  final band =
      _bands[((latitude.clamp(-80.0, 83.999) + 80) / 8).floor().clamp(0, 19)];
  final (easting, northing) = utmFromLatLon(latitude, longitude, zone);
  return '$zone$band ${easting.round()} E ${northing.round()} N';
}

/// Forward transverse Mercator on WGS84, the counterpart of the inverse in
/// `coordinate_parser.dart`, and checked against the same PROJ values.
(double, double) utmFromLatLon(double latitude, double longitude, int zone) {
  const a = 6378137.0;
  const f = 1 / 298.257223563;
  const k0 = 0.9996;
  const e2 = 2 * f - f * f;
  const e4 = e2 * e2;
  const e6 = e4 * e2;
  const ePrime2 = e2 / (1 - e2);

  final phi = latitude * math.pi / 180;
  final centralMeridian = ((zone - 1) * 6 - 180 + 3) * math.pi / 180;
  final sinPhi = math.sin(phi);
  final cosPhi = math.cos(phi);
  final tanPhi = math.tan(phi);

  final n = a / math.sqrt(1 - e2 * sinPhi * sinPhi);
  final t = tanPhi * tanPhi;
  final c = ePrime2 * cosPhi * cosPhi;
  final aa = (longitude * math.pi / 180 - centralMeridian) * cosPhi;
  final m =
      a *
      ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi -
          (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi) +
          (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi) -
          (35 * e6 / 3072) * math.sin(6 * phi));

  final easting =
      500000 +
      k0 *
          n *
          (aa +
              (1 - t + c) * math.pow(aa, 3) / 6 +
              (5 - 18 * t + t * t + 72 * c - 58 * ePrime2) *
                  math.pow(aa, 5) /
                  120);
  var northing =
      k0 *
      (m +
          n *
              tanPhi *
              (aa * aa / 2 +
                  (5 - t + 9 * c + 4 * c * c) * math.pow(aa, 4) / 24 +
                  (61 - 58 * t + t * t + 600 * c - 330 * ePrime2) *
                      math.pow(aa, 6) /
                      720));
  if (latitude < 0) northing += 10000000;
  return (easting, northing);
}

/// The chosen format, for every screen above the map.
///
/// Above the [MaterialApp]'s navigator rather than in the map's
/// [DisplaySettings], because waypoint lists, editors and search are pushed
/// routes that the map shell does not build.
class CoordinateFormatScope
    extends InheritedNotifier<ValueNotifier<CoordinateFormat>> {
  const CoordinateFormatScope({
    super.key,
    required ValueNotifier<CoordinateFormat> super.notifier,
    required super.child,
  });

  static const _key = 'display.coordinate_format';

  /// Decimal where there is no scope, as in most widget tests.
  static CoordinateFormat of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CoordinateFormatScope>()
          ?.notifier
          ?.value ??
      CoordinateFormat.fallback;

  static ValueNotifier<CoordinateFormat>? notifierOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CoordinateFormatScope>()
          ?.notifier;

  static Future<CoordinateFormat> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return CoordinateFormat.fromId(prefs.getString(_key));
    } on Exception {
      return CoordinateFormat.fallback;
    }
  }

  /// Only a non-default choice is written, as in [DisplaySettings].
  static Future<void> store(CoordinateFormat format) async {
    final prefs = await SharedPreferences.getInstance();
    if (format == CoordinateFormat.fallback) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, format.id);
    }
  }
}
