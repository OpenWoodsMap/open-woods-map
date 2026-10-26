/// What a fishing access point can say about itself.
library;

import '../data/models.dart';

/// "Boat launch", "Dock or pier" or "Shore access", in the layer's own words.
String fishingAccessKind(LandFeature feature, LoadedLayer? layer) {
  final labels = layer?.metadata['kind_labels'];
  final kind = feature.properties['kind']?.toString();
  final label = labels is Map ? labels[kind] : null;
  return label?.toString() ?? 'Fishing access';
}

/// The kind and the site's name, or the kind alone: 1,359 of the province's
/// sites have no name, and inventing one from the nearest lake would be a
/// name the province never gave it.
String fishingAccessTitle(LandFeature feature, LoadedLayer? layer) {
  final kind = fishingAccessKind(feature, layer);
  final name = feature.name?.trim();
  return name == null || name.isEmpty ? kind : '$kind · $name';
}

/// What the province recorded about the site, as short phrases.
///
/// Only what was recorded. The pack drops "Unknown" rather than carrying it, so
/// a missing fact here means nobody said, which the card's footnote states once
/// instead of every line saying it again.
List<String> fishingAccessFacts(LandFeature feature) {
  final properties = feature.properties;
  // The province defines the material as what the boat launch is made of, so
  // only a launch has a ramp to describe.
  final surfaceOf =
      properties['kind'] == 'boat_launch' ? 'ramp' : 'surface';
  return [
    if (properties['parking'] case final bool parking)
      parking ? 'Parking' : 'No parking',
    if (properties['fee'] case final bool fee) fee ? 'Fee to use' : 'No fee',
    if (properties['surface'] case final String surface)
      switch (surface) {
        'concrete' => 'Concrete $surfaceOf',
        'gravel' => 'Gravel $surfaceOf',
        'natural' => 'Natural $surfaceOf',
        _ => 'Other $surfaceOf',
      },
    if (properties['accessible'] case final bool accessible)
      accessible ? 'Wheelchair accessible' : 'Not wheelchair accessible',
    if (properties['owner'] case final String owner)
      switch (owner) {
        'private' => 'Privately owned',
        'municipal' => 'Municipal site',
        'provincial' => 'Provincial site',
        'federal' => 'Federal site',
        _ => 'Owner recorded as $owner',
      },
  ];
}

/// When somebody last confirmed the site exists, as the province recorded it.
/// Most sites carry no date, and the card says so rather than implying a
/// launch was checked last season.
String fishingAccessVerified(LandFeature feature) =>
    switch (feature.properties['verified']) {
      final String day when day.isNotEmpty => 'Last confirmed visited $day',
      _ => 'No visit on record',
    };

/// The site's own web page, where the province recorded one.
Uri? fishingAccessInfoUrl(LandFeature feature) {
  final raw = feature.properties['info_url']?.toString();
  return raw == null || raw.isEmpty ? null : Uri.tryParse(raw);
}
