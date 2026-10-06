/// The words a shared location goes out in.
///
/// Plain text, because the place this gets used is a text message from the
/// bush: SMS needs a cell signal but no data, and every phone can read it. The
/// coordinates lead so the message is useful with no app at all, read aloud to
/// a dispatcher if it comes to that. The link comes last, which is also what
/// lets `parseCoordinate` read the whole message back when it is pasted into
/// search, since the query it extracts runs to the end of the text.
library;

import 'package:share_plus/share_plus.dart';

String _pair(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

/// Google Maps rather than OpenStreetMap because it is the map app the person
/// receiving this is most likely to have, and the link opens in it directly.
/// It is a link, not an API call: nothing is fetched and no key is involved.
String _link(double latitude, double longitude) =>
    'https://maps.google.com/?q=${latitude.toStringAsFixed(5)},'
    '${longitude.toStringAsFixed(5)}';

/// How long ago a fix was taken, in the words someone would say it.
String fixAge(DateTime taken, DateTime now) {
  final age = now.difference(taken);
  if (age.inSeconds < 60) return 'just now';
  if (age.inMinutes < 60) {
    return '${age.inMinutes} minute${age.inMinutes == 1 ? '' : 's'} ago';
  }
  if (age.inHours < 24) {
    return '${age.inHours} hour${age.inHours == 1 ? '' : 's'} ago';
  }
  final day = taken.toLocal();
  return 'on ${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

/// Where the sender is, with how good and how old the fix was.
///
/// Both always, unlike a saved waypoint's accuracy note, which only speaks up
/// past 20 m. The person reading this may walk to the spot or send someone to
/// it, and five decimal places alone claim a metre the phone never promised.
/// The age matters most when the fix is not fresh: a last known position from
/// half an hour ago is still worth sending, but only if it says so.
String myLocationText({
  required double latitude,
  required double longitude,
  required double accuracyMetres,
  required DateTime taken,
  required DateTime now,
}) {
  final age = fixAge(taken, now);
  final accuracy = accuracyMetres.isFinite && accuracyMetres > 0
      ? 'Accurate to about ${accuracyMetres.round()} m, from a GPS fix $age.'
      : 'From a GPS fix $age; the phone gave no accuracy for it.';
  final moved = now.difference(taken).inMinutes >= 2
      ? ' I may have moved since.'
      : '';
  return 'My location: ${_pair(latitude, longitude)}\n'
      '$accuracy$moved\n'
      '${_link(latitude, longitude)}';
}

/// A spot tapped on the map. Says outright that it is not the sender's
/// position, because "45.1, -77.2" from someone in the woods reads as "I am
/// here" unless something says otherwise.
String spotText({required double latitude, required double longitude}) =>
    'A spot on the map, not where I am: ${_pair(latitude, longitude)}\n'
    '${_link(latitude, longitude)}';

/// A saved waypoint, by name. Notes stay behind: they are the user's own
/// remarks, and a share sheet is a bad place to discover they went too.
String waypointText({
  required String name,
  required double latitude,
  required double longitude,
}) =>
    '$name: ${_pair(latitude, longitude)}\n${_link(latitude, longitude)}';

/// Hands [text] to the system share sheet.
Future<void> shareText(String text) =>
    SharePlus.instance.share(ShareParams(text: text));
