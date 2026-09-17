/// What to say about how rough a GPS fix was, when saving a waypoint from one.
///
/// Its own file because it is the one judgement in "save a waypoint where I am"
/// that is not plumbing: a threshold and a sentence, both of which decide whether
/// somebody later trusts a coordinate more than the phone ever did. The map shell
/// cannot be widget-tested against a native MapLibre view, so anything worth
/// pinning down has to live outside it.
library;

/// Beyond this many metres, how rough the fix was is worth writing down.
///
/// A phone manages 3-5 m under open sky and 10-20 m under canopy, so anything
/// inside this is the ordinary case, and stamping "± 4 m" on every waypoint would
/// be noise nobody reads. Worse than it means the fix is doing worse than tree
/// cover explains, and the five decimal places stored beside it would otherwise
/// imply a precision the phone never claimed.
///
/// Deliberately lower than the 50 m at which track recording rejects a fix
/// outright. That is a different question. A track is a line whose shape one wild
/// fix ruins, so it drops them; a waypoint asked for by hand is never refused over
/// accuracy, because somebody pressing the button under heavy canopy may have no
/// better fix available all day, and a marked spot known to be rough beats no
/// marked spot.
const accuracyWorthStating = 20.0;

/// One plain sentence, or nothing at all.
///
/// Goes into the waypoint's note rather than a new field on the model, so it
/// travels through GPX, KML, GeoJSON and backup as something a person reads, and
/// stays editable. It is a remark about one reading, not a property of the place,
/// and the person who was standing there may well know better than the phone did.
///
/// "About" and a whole number on purpose. The figure is the device's own estimate
/// of its error, so reporting it to the metre would dress up a guess as a
/// measurement — the same overclaiming this exists to prevent.
String accuracyNote(double metres) {
  if (!metres.isFinite || metres <= accuracyWorthStating) return '';
  return 'Saved from a GPS fix accurate to about ${metres.round()} m.';
}
