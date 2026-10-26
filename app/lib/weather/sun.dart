import 'dart:math' as math;

/// Sunrise and sunset for one calendar date at one point, as UTC instants.
class SunTimes {
  const SunTimes({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;

  /// Same half hour either side as [DayForecast.legalStart], so the offline
  /// answer and the forecast's agree.
  DateTime get legalStart => sunrise.subtract(const Duration(minutes: 30));
  DateTime get legalEnd => sunset.add(const Duration(minutes: 30));
}

/// Works sunrise and sunset out on the phone, so legal light needs no
/// connection and covers any date rather than the forecast's seven days.
///
/// The NOAA-derived sunrise equation: the sun's centre 0.833° below a flat
/// horizon, which allows for refraction and the sun's radius. It is good to
/// about a minute at Ontario and Quebec latitudes. It knows nothing of hills,
/// so a ridge to the east makes the sun reach you later than this says.
///
/// [date] is read as a calendar date only. Returns null where the sun stays
/// up or stays down all day, which never happens in either province but does
/// further north.
SunTimes? sunTimesOn(DateTime date, double latitude, double longitude) {
  const rad = math.pi / 180;
  final midnight = DateTime.utc(date.year, date.month, date.day);
  final julianDate = 2440587.5 + midnight.millisecondsSinceEpoch / 86400000;
  final n = (julianDate - 2451545.0 + 0.0008).ceilToDouble();
  final meanNoon = n - longitude / 360;
  final anomaly = (357.5291 + 0.98560028 * meanNoon) % 360;
  final m = anomaly * rad;
  final centre =
      1.9148 * math.sin(m) +
      0.0200 * math.sin(2 * m) +
      0.0003 * math.sin(3 * m);
  final eclipticLongitude = ((anomaly + centre + 180 + 102.9372) % 360) * rad;
  final transit =
      2451545.0 +
      meanNoon +
      0.0053 * math.sin(m) -
      0.0069 * math.sin(2 * eclipticLongitude);
  final declination = math.asin(
    math.sin(eclipticLongitude) * math.sin(23.4397 * rad),
  );
  final phi = latitude * rad;
  final cosHourAngle =
      (math.sin(-0.833 * rad) - math.sin(phi) * math.sin(declination)) /
      (math.cos(phi) * math.cos(declination));
  if (cosHourAngle.abs() > 1) return null;
  final halfDay = math.acos(cosHourAngle) / rad / 360;

  DateTime instant(double julian) => DateTime.fromMillisecondsSinceEpoch(
    ((julian - 2440587.5) * 86400000).round(),
    isUtc: true,
  );

  return SunTimes(
    sunrise: instant(transit - halfDay),
    sunset: instant(transit + halfDay),
  );
}
