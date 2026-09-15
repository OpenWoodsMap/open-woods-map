import 'package:flutter/material.dart';

import 'owm_icons.dart';

/// Which part of the picker a glyph sits under.
///
/// Grouping only, never meaning: an angler is free to mark a stand and a hunter
/// a dock. The sections exist because a flat wall of fifty pictograms is
/// unreadable, not because the app has an opinion about who marks what.
///
/// Declaration order is the order the picker shows the sections in, which is why
/// [WaypointIcon.byGroup] walks this enum rather than the icons.
enum WaypointIconGroup {
  general(label: 'General'),
  wildlife(label: 'Wildlife and sign'),
  hunting(label: 'Hunting'),
  fishing(label: 'Fishing and water'),
  land(label: 'Land and water'),
  travel(label: 'Getting there'),
  hazards(label: 'Hazards'),
  lines(label: 'Lines and routes');

  const WaypointIconGroup({required this.label});

  final String label;
}

/// The glyph a waypoint draws as, in this app's lists and on the map.
///
/// This is a picture and nothing else. It says nothing about what the waypoint
/// *is* — tags do that — which is why there is no rule against putting the fish
/// on a stand or the chair on a portage.
///
/// The one thing here that is not free choice is [garminSym]. Garmin units draw
/// an icon only for symbol names from their own fixed table, so this is the one
/// place a closed vocabulary is unavoidable, and it is why the enum exists at
/// all rather than the icon being a free codepoint.
enum WaypointIcon {
  // Garmin symbol names below are the display names from GPSBabel's
  // garmin_icon_tables.h, which is the reference the GPX ecosystem shares. They
  // are spelled exactly as Garmin spells them because a near miss is silently
  // ignored by the unit and falls back to a default pin. Where Garmin has
  // nothing that means the right thing, garminSym is null and `<sym>` is
  // omitted rather than filled with something misleading: a wrong icon on the
  // unit is worse than a default one.
  //
  // Every glyph added since the icon stopped being a category carries null for
  // the same reason. Guessing at a plausible Garmin name — "Boat Ramp",
  // "Geocache" — would be inventing a fact about someone else's device.
  //
  // The colours on the first twenty are the ones their categories carried when
  // the icon and the category were one field, kept to the exact ARGB value so
  // that a waypoint saved before the split draws in the colour it has always
  // drawn in. A test pins them. Changing one repaints waypoints already on
  // someone's phone, which is a migration in everything but name.
  pin(
    // Stays 'other' because this id is written into the waypoint file and is
    // also the SDF asset's filename. Renaming it would silently un-icon every
    // waypoint already saved and orphan assets/waypoint_icons/other.png.
    id: 'other',
    label: 'Pin',
    icon: Icons.place,
    garminSym: 'Waypoint',
    colour: Color(0xFFB3261E),
  ),
  viewpoint(
    id: 'viewpoint',
    label: 'Viewpoint',
    icon: Icons.landscape,
    garminSym: 'Summit',
    colour: Color(0xFF5E35B1),
  ),
  camp(
    id: 'camp',
    label: 'Camp',
    icon: Icons.cabin,
    garminSym: 'Campground',
    colour: Color(0xFF00695C),
  ),
  tent(
    id: 'tent',
    label: 'Tent',
    icon: Icons.festival,
    garminSym: null,
    // A shade off camp, close enough to read as the same kind of thing at a
    // glance and far enough apart to tell two marks on a lake apart.
    colour: Color(0xFF00796B),
  ),
  // Was Material's kettle grill, which is why the label used to hedge about
  // grills. This draws a fire ring now, so it can say so.
  firepit(
    id: 'firepit',
    label: 'Fire ring',
    icon: OwmIcons.firepit,
    garminSym: null,
    // Ember, not hazard orange: a fire ring is a place you are glad to find,
    // and the two should not read as the same warning.
    colour: Color(0xFFBF360C),
  ),
  water(
    id: 'water',
    label: 'Water source',
    icon: Icons.water_drop,
    garminSym: 'Water Source',
    colour: Color(0xFF0277BD),
  ),
  cache(
    id: 'cache',
    label: 'Cache',
    icon: Icons.inventory_2,
    garminSym: null,
    // Deliberately neutral. A cache is whatever the user left there, and no
    // hue in this set means "supplies" without borrowing someone else's
    // meaning.
    colour: Color(0xFF616161),
  ),
  // A leaf, and now the catch-all rather than the only option: the three below
  // draw the plants Material Icons had nothing for, so this one is for whatever
  // they do not cover.
  foraging(
    id: 'foraging',
    label: 'Foraging',
    icon: Icons.eco,
    garminSym: null,
    // Green, alongside food source, because both mark something growing.
    colour: Color(0xFF33691E),
  ),
  mushroom(
    id: 'mushroom',
    label: 'Mushrooms',
    icon: OwmIcons.mushroom,
    garminSym: null,
    colour: Color(0xFF8B4513),
  ),
  berries(
    id: 'berries',
    label: 'Berries',
    icon: OwmIcons.berries,
    garminSym: null,
    // The one genuinely berry-coloured value in the set, and the only place a
    // pink this deep is used outside the track glyphs.
    colour: Color(0xFF880E4F),
  ),
  nuts(
    id: 'nuts',
    label: 'Nuts or mast',
    icon: OwmIcons.nuts,
    garminSym: null,
    colour: Color(0xFFA0522D),
  ),

  // Species, for marking what was seen rather than what was done. Material Icons
  // has no animal but a paw print, so every one of these is drawn from the
  // vendored artwork.
  //
  // There is no moose, elk or caribou glyph in that artwork either, and none
  // close enough to adapt honestly, so [deer] carries the other cervids and the
  // tag says which. Same for grouse, turkey and partridge, which land on
  // [feather]. A rooster relabelled as a grouse would be the app claiming to
  // know a bird it cannot draw.
  deer(
    id: 'deer',
    label: 'Deer or moose',
    icon: OwmIcons.deer,
    garminSym: null,
    colour: Color(0xFF8D6E63),
    group: WaypointIconGroup.wildlife,
  ),
  bear(
    id: 'bear',
    label: 'Bear',
    icon: OwmIcons.bear,
    garminSym: null,
    colour: Color(0xFF5D4037),
    group: WaypointIconGroup.wildlife,
  ),
  boar(
    id: 'boar',
    label: 'Boar',
    icon: OwmIcons.boar,
    garminSym: null,
    colour: Color(0xFF795548),
    group: WaypointIconGroup.wildlife,
  ),
  wolf(
    id: 'wolf',
    label: 'Wolf or coyote',
    icon: OwmIcons.wolf,
    garminSym: null,
    colour: Color(0xFF78909C),
    group: WaypointIconGroup.wildlife,
  ),
  rabbit(
    id: 'rabbit',
    label: 'Rabbit or hare',
    icon: OwmIcons.rabbit,
    garminSym: null,
    colour: Color(0xFFA1887F),
    group: WaypointIconGroup.wildlife,
  ),
  squirrel(
    id: 'squirrel',
    label: 'Squirrel',
    icon: OwmIcons.squirrel,
    garminSym: null,
    colour: Color(0xFFD84315),
    group: WaypointIconGroup.wildlife,
  ),
  beaver(
    id: 'beaver',
    label: 'Beaver',
    icon: OwmIcons.beaver,
    garminSym: null,
    colour: Color(0xFF7B5E57),
    group: WaypointIconGroup.wildlife,
  ),
  waterfowl(
    id: 'waterfowl',
    label: 'Ducks or geese',
    icon: OwmIcons.waterfowl,
    garminSym: null,
    colour: Color(0xFF546E7A),
    group: WaypointIconGroup.wildlife,
  ),
  feather(
    id: 'feather',
    label: 'Game birds',
    icon: OwmIcons.feather,
    garminSym: null,
    colour: Color(0xFF90A4AE),
    group: WaypointIconGroup.wildlife,
  ),
  // Cloven prints, which is the one thing that tells it apart from [sign]: that
  // one is Material's paw and means sign of any kind.
  tracks(
    id: 'tracks',
    label: 'Hoof tracks',
    icon: OwmIcons.tracks,
    garminSym: null,
    colour: Color(0xFF5A4632),
    group: WaypointIconGroup.wildlife,
  ),

  // A ladder now, which is what a stand looks like from below. Material's
  // nearest was an office chair. The label stays the generic term: it is the
  // word hunters search for, it is what `garminSym` says, and it is the tag an
  // old waypoint migrated to, so all three agreeing is worth more than naming
  // the picture.
  stand(
    id: 'stand',
    label: 'Tree stand',
    icon: OwmIcons.stand,
    garminSym: 'Tree Stand',
    colour: Color(0xFF6A4C1E),
    group: WaypointIconGroup.hunting,
  ),
  towerStand(
    id: 'tower-stand',
    label: 'Tower or box stand',
    icon: OwmIcons.towerStand,
    garminSym: null,
    // Beside the ladder stand, because they are the same errand at a glance and
    // a hunter with both wants to tell them apart without reading.
    colour: Color(0xFF7A5C2E),
    group: WaypointIconGroup.hunting,
  ),
  blind(
    id: 'blind',
    label: 'Blind',
    icon: Icons.night_shelter,
    garminSym: 'Blind',
    colour: Color(0xFF4E342E),
    group: WaypointIconGroup.hunting,
  ),
  // Where you sit and look, not where you sit and wait, which is why it is its
  // own mark rather than a stand.
  glassing(
    id: 'glassing',
    label: 'Glassing spot',
    icon: OwmIcons.glassing,
    garminSym: null,
    colour: Color(0xFF607D8B),
    group: WaypointIconGroup.hunting,
  ),
  camera(
    id: 'camera',
    label: 'Trail camera',
    icon: Icons.photo_camera,
    // Garmin's vocabulary predates trail cameras and has no symbol for one.
    garminSym: null,
    colour: Color(0xFF1565C0),
    group: WaypointIconGroup.hunting,
  ),
  sign(
    id: 'sign',
    label: 'Animal sign',
    icon: Icons.pets,
    garminSym: 'Animal Tracks',
    colour: Color(0xFF6D4C41),
    group: WaypointIconGroup.hunting,
  ),
  blood(
    id: 'blood',
    label: 'Blood trail',
    icon: Icons.bloodtype,
    garminSym: 'Blood Trail',
    colour: Color(0xFF8E0000),
    group: WaypointIconGroup.hunting,
  ),
  // A skull rather than the plain flag Material could offer, which said nothing
  // about what was being marked.
  harvest(
    id: 'harvest',
    label: 'Harvest',
    icon: OwmIcons.harvest,
    // Garmin has no generic "harvest"; Big Game is the closest real symbol and
    // is what a hunting unit shows for a taken animal.
    garminSym: 'Big Game',
    colour: Color(0xFF37474F),
    group: WaypointIconGroup.hunting,
  ),
  food(
    id: 'food',
    label: 'Food source',
    icon: Icons.grass,
    garminSym: 'Food Source',
    colour: Color(0xFF558B2F),
    group: WaypointIconGroup.hunting,
  ),

  fishing(
    id: 'fishing',
    label: 'Fishing spot',
    icon: Icons.phishing,
    garminSym: 'Fishing Area',
    colour: Color(0xFF00838F),
    group: WaypointIconGroup.fishing,
  ),
  // A fish landed, where [fishing] is the spot you went to. Two marks because
  // one is a plan and the other is a result.
  fish(
    id: 'fish',
    label: 'Fish caught',
    icon: OwmIcons.fish,
    garminSym: null,
    colour: Color(0xFF006064),
    group: WaypointIconGroup.fishing,
  ),
  dock(
    id: 'dock',
    label: 'Dock or mooring',
    icon: Icons.anchor,
    garminSym: null,
    // The deep end of water source's blue: a dock is a place on the water.
    colour: Color(0xFF01579B),
    group: WaypointIconGroup.fishing,
  ),
  boatLaunch(
    id: 'boat-launch',
    label: 'Boat launch',
    icon: Icons.directions_boat,
    garminSym: null,
    // Beside fishing's cyan, since a launch is usually how the fishing starts.
    colour: Color(0xFF0097A7),
    group: WaypointIconGroup.fishing,
  ),

  // Features of the ground itself. These describe terrain rather than anything
  // anyone built or did, which is why they are not under Getting there.
  forest(
    id: 'forest',
    label: 'Timber or cover',
    icon: OwmIcons.forest,
    garminSym: null,
    colour: Color(0xFF1B5E20),
    group: WaypointIconGroup.land,
  ),
  swamp(
    id: 'swamp',
    label: 'Swamp or marsh',
    icon: OwmIcons.swamp,
    garminSym: null,
    colour: Color(0xFF6B8E23),
    group: WaypointIconGroup.land,
  ),
  waterfall(
    id: 'waterfall',
    label: 'Waterfall or rapids',
    icon: OwmIcons.waterfall,
    garminSym: null,
    colour: Color(0xFF039BE5),
    group: WaypointIconGroup.land,
  ),
  spring(
    id: 'spring',
    label: 'Spring or well',
    icon: OwmIcons.spring,
    garminSym: null,
    // Darker than the cyan this started as, which was light enough that the
    // white glyph inside a pin of it missed the 3:1 a pictogram needs.
    colour: Color(0xFF00897B),
    group: WaypointIconGroup.land,
  ),
  cave(
    id: 'cave',
    label: 'Cave or overhang',
    icon: OwmIcons.cave,
    garminSym: null,
    colour: Color(0xFF424242),
    group: WaypointIconGroup.land,
  ),
  farm(
    id: 'farm',
    label: 'Farmland',
    icon: OwmIcons.farm,
    garminSym: null,
    // Ochre rather than the lime it started as, which was too light for a white
    // glyph to read against, and warmer than portage's olive so that the two
    // are not one colour with two meanings.
    colour: Color(0xFFA6761D),
    group: WaypointIconGroup.land,
  ),

  parking(
    id: 'parking',
    label: 'Parking or access',
    icon: Icons.local_parking,
    garminSym: 'Parking Area',
    colour: Color(0xFF455A64),
    group: WaypointIconGroup.travel,
  ),
  trailhead(
    id: 'trailhead',
    label: 'Trailhead',
    icon: Icons.hiking,
    garminSym: 'Trail Head',
    colour: Color(0xFF2E7D32),
    group: WaypointIconGroup.travel,
  ),
  signpost(
    id: 'signpost',
    label: 'Signpost or junction',
    icon: Icons.signpost,
    garminSym: null,
    // A shade off trailhead, because a junction is the same errand as a
    // trailhead once you are already walking.
    colour: Color(0xFF388E3C),
    group: WaypointIconGroup.travel,
  ),
  ford(
    id: 'ford',
    label: 'Ford or crossing',
    icon: Icons.water,
    garminSym: null,
    // Water's blue, lighter: a ford is water that is in the way rather than
    // water you came for.
    colour: Color(0xFF0288D1),
    group: WaypointIconGroup.travel,
  ),
  bridge(
    id: 'bridge',
    label: 'Bridge',
    icon: OwmIcons.bridge,
    garminSym: null,
    colour: Color(0xFF757575),
    group: WaypointIconGroup.travel,
  ),
  // Where access stops, which is a thing worth marking whether or not it is
  // locked. [boundary] is the fence itself; this is the way through it.
  gate(
    id: 'gate',
    label: 'Gate',
    icon: OwmIcons.gate,
    garminSym: null,
    colour: Color(0xFF263238),
    group: WaypointIconGroup.travel,
  ),

  hazard(
    id: 'hazard',
    label: 'Hazard',
    icon: Icons.warning,
    garminSym: 'Skull and Crossbones',
    colour: Color(0xFFE65100),
    group: WaypointIconGroup.hazards,
  ),

  // GPX's trkType has no `sym` element at all, so these carry null rather than
  // a guess: nothing would be written for a track anyway, and a point given one
  // of these glyphs is a point, not a line.
  //
  // Their colours sit in hue regions the rest of the set leaves empty — pink,
  // indigo, dark brown, olive and near-black — because a track is a long thin
  // shape competing with roads and rivers on the basemap, and two tracks the
  // same colour are much harder to tell apart than two pins are.
  trail(
    id: 'trail',
    label: 'Trail',
    icon: Icons.route,
    garminSym: null,
    colour: Color(0xFFAD1457),
    group: WaypointIconGroup.lines,
  ),
  route(
    id: 'route',
    label: 'Planned route',
    icon: Icons.alt_route,
    garminSym: null,
    colour: Color(0xFF283593),
    group: WaypointIconGroup.lines,
  ),
  road(
    id: 'road',
    label: 'Access road',
    icon: Icons.directions_car,
    garminSym: null,
    colour: Color(0xFF3E2723),
    group: WaypointIconGroup.lines,
  ),
  atvTrail(
    id: 'atv-trail',
    label: 'ATV trail',
    icon: OwmIcons.atvTrail,
    garminSym: null,
    // Purple, which the other line glyphs leave empty. Two tracks the same
    // colour are much harder to tell apart than two pins are.
    colour: Color(0xFF6A1B9A),
    group: WaypointIconGroup.lines,
  ),
  portage(
    id: 'portage',
    label: 'Portage',
    icon: Icons.kayaking,
    garminSym: null,
    colour: Color(0xFF827717),
    group: WaypointIconGroup.lines,
  ),
  boundary(
    id: 'boundary',
    label: 'Boundary',
    icon: Icons.fence,
    garminSym: null,
    colour: Color(0xFF212121),
    group: WaypointIconGroup.lines,
  );

  const WaypointIcon({
    required this.id,
    required this.label,
    required this.icon,
    required this.garminSym,
    required this.colour,
    this.group = WaypointIconGroup.general,
  });

  /// Stable across releases: it is written into saved files and exports, and it
  /// is the filename of the generated SDF image, so renaming one silently
  /// changes the glyph on every waypoint already saved under it.
  final String id;

  final String label;

  /// Drawn in the app's own lists. The map draws the same glyph as an SDF image
  /// generated from this codepoint by `tools/icons/build_waypoint_icons.py`,
  /// and a test asserts the two have not drifted apart.
  final IconData icon;

  /// The exact Garmin symbol display name, or null where none fits.
  final String? garminSym;

  /// The tint this glyph draws in until the user picks a colour of their own.
  ///
  /// A property of the pictogram, not a classification: it is here so that a
  /// screen of thirty marks is a legible spread of colour instead of thirty
  /// identical pins, and so that a waypoint saved before the icon and the
  /// category were separated keeps the colour it already had.
  ///
  /// It is a default and a hint, never the meaning. Garmin has no waypoint
  /// colour field at all and onX discards colour on import, so colour must
  /// never be the only thing telling two glyphs apart — the pictogram always
  /// differs too, and that is deliberate.
  final Color colour;

  final WaypointIconGroup group;

  /// The MapLibre image name for this glyph's SDF asset.
  String get iconImage => 'owm-wp-$id';

  /// What a waypoint draws as until someone picks something else.
  static const fallback = WaypointIcon.pin;

  /// Every glyph, sectioned for a picker.
  ///
  /// Sections come in [WaypointIconGroup] declaration order and the glyphs
  /// within one in this enum's, so a glyph added to a group lands beside the
  /// ones it belongs with without deciding where its whole section appears.
  static Map<WaypointIconGroup, List<WaypointIcon>> get byGroup {
    final grouped = <WaypointIconGroup, List<WaypointIcon>>{};
    for (final group in WaypointIconGroup.values) {
      final icons = values.where((icon) => icon.group == group).toList();
      if (icons.isNotEmpty) grouped[group] = icons;
    }
    return grouped;
  }

  /// Resolves a stored or imported id, falling back to [fallback].
  ///
  /// Unknown ids are expected rather than exceptional: a file exported by a
  /// later build, or by another app that put something else in `<type>`. Losing
  /// the glyph is acceptable there. Losing the waypoint is not.
  static WaypointIcon fromId(String? id) {
    if (id == null) return fallback;
    final wanted = id.trim().toLowerCase();
    if (wanted.isEmpty) return fallback;
    for (final icon in values) {
      if (icon.id == wanted) return icon;
    }
    // Garmin round trips `<sym>` more reliably than `<type>` through some
    // tools, so a file that lost everything else can still be drawn from its
    // symbol.
    for (final icon in values) {
      if (icon.garminSym?.toLowerCase() == wanted) return icon;
    }
    // KML folder names are the human label, because that is what makes a folder
    // worth having in Google Earth. A file whose ExtendedData was stripped can
    // still be drawn from the folder it came out of.
    for (final icon in values) {
      if (icon.label.toLowerCase() == wanted) return icon;
    }
    return fallback;
  }
}
