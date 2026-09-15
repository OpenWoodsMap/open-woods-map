/// What other apps' waypoint files mean, so an import arrives as more than a
/// wall of identical pins.
///
/// Every table here was read off a real export rather than from documentation,
/// and each records which file it came from. That matters because none of these
/// vocabularies is published: a value nobody has seen is left to fall back
/// rather than guessed at, since a wrong glyph is a wrong statement about
/// somebody's waypoint.
///
/// The mapping is deliberately allowed to be lossy, and deliberately not allowed
/// to be silent about it. Where a glyph says less than the source pin did, the
/// original word is kept as a tag, so nothing is thrown away and the list's tag
/// search can still find it.
library;

import 'waypoint_colour.dart';
import 'waypoint_icon.dart';

/// iHunter's pin images, from a `waypoints.gpx` export.
///
/// iHunter writes no `<sym>` and no `<type>` at all, so without this every
/// waypoint in one of its files lands on the default pin. The icon is in a
/// private extension instead:
///
/// ```xml
/// <extensions>
///   <ihunter:pinimage>ihunter_pin_trees</ihunter:pinimage>
///   <ihunter:backgroundimage>ihunter_pin_background_brown</ihunter:backgroundimage>
/// </extensions>
/// ```
///
/// Keyed on the name with the `ihunter_pin_` prefix already stripped, because
/// the same file writes both forms: most values carry the prefix but `camp` and
/// `farmer` arrive bare.
///
/// The tag is non-null only where this app's glyph is less specific than
/// iHunter's pin was. Grouse and turkey both become the feather because there is
/// no upland bird glyph to be had, and a scrape becomes the generic animal sign,
/// so in those three the species or the sign would be lost without the tag.
const iHunterPins = <String, (WaypointIcon, String?)>{
  'camp': (WaypointIcon.camp, null),
  'trees': (WaypointIcon.forest, null),
  'mountain': (WaypointIcon.viewpoint, null),
  'fish': (WaypointIcon.fishing, null),
  'stand': (WaypointIcon.stand, null),
  'truck': (WaypointIcon.parking, null),
  'gate': (WaypointIcon.gate, null),
  'rabbit': (WaypointIcon.rabbit, null),
  'farmer': (WaypointIcon.farm, null),
  // A sighting, which is what iHunter means by it, rather than a rifle's sights.
  'sights': (WaypointIcon.glassing, null),
  'xmark': (WaypointIcon.pin, null),
  // Lossy, so each keeps the word the glyph cannot say.
  'scrape': (WaypointIcon.sign, 'scrape'),
  'grouse': (WaypointIcon.feather, 'grouse'),
  'turkey': (WaypointIcon.feather, 'turkey'),
};

/// What an iHunter `pinimage` resolved to.
///
/// [icon] is null where iHunter named a pin this app has no glyph for. [tag] is
/// the word worth keeping whenever the glyph says less than the pin did, which
/// covers both a lossy match and no match at all.
typedef IHunterPin = ({WaypointIcon? icon, String? tag});

/// What an iHunter `pinimage` names, or null if there was no pin to read.
///
/// A record rather than an icon so the caller can tell "iHunter said nothing we
/// recognise" apart from "iHunter said its own default pin". The two want
/// different treatment: only the first has a word worth keeping.
IHunterPin? iHunterPin(String? pinImage) {
  final key = _stripPrefix(pinImage, 'ihunter_pin_');
  if (key == null) return null;
  if (iHunterPins[key] case (final icon, final tag)) {
    return (icon: icon, tag: tag);
  }
  // A pin from a part of iHunter's set this app has never seen. Choosing a
  // picture for it would be inventing a statement about someone's waypoint, so
  // it takes the default pin and keeps its own word as a tag, where the list's
  // search can still find it.
  return (icon: null, tag: key);
}

/// The colour an iHunter `backgroundimage` names.
///
/// Resolved through [WaypointColour.fromId] rather than a table of its own,
/// because iHunter names its backgrounds by colour and so do we. The export read
/// for this used only brown, blue and green; going through `fromId` means the
/// rest of its palette works too without anyone guessing at values never seen.
WaypointColour? iHunterBackground(String? backgroundImage) {
  final key = _stripPrefix(backgroundImage, 'ihunter_pin_background_');
  return key == null ? null : WaypointColour.fromId(key);
}

/// CalTopo marker symbols, from a full GeoJSON backup.
///
/// Thin on purpose. In the export this was read from, 39 of 41 markers carried
/// the generic `point`, so almost nothing here is recoverable and the useful
/// signal in a CalTopo file is its title and its colour, not its symbol. Only
/// values actually observed are listed; CalTopo's full symbol set is not
/// published and inventing thirty plausible names would put wrong pictures on
/// waypoints on the strength of a guess.
///
/// Anything absent falls through to [WaypointIcon.fromId], which already matches
/// our own ids, Garmin symbol names and labels, so a CalTopo file that happens
/// to use one of those words still resolves.
const calTopoSymbols = <String, WaypointIcon>{
  // CalTopo's default. It means "a marker", not "a kind of place".
  'point': WaypointIcon.pin,
  'atv': WaypointIcon.atvTrail,
};

/// The icon a CalTopo `marker-symbol` names, or null if it names none of ours.
WaypointIcon? calTopoSymbol(String? symbol) {
  final key = symbol?.trim().toLowerCase();
  if (key == null || key.isEmpty) return null;
  return calTopoSymbols[key];
}

String? _stripPrefix(String? value, String prefix) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.startsWith(prefix)
      ? trimmed.substring(prefix.length)
      : trimmed;
}
