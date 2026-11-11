import '../data/gazetteer.dart';

/// Names for the stretches of bush a basemap leaves blank, drawn from the
/// place-name index the pack already carries for search.
///
/// CGNDB stores one point per name, usually somewhere near the middle of the
/// feature. A label there says what the ground is called, never how far the
/// name reaches, which is why nothing here draws an outline.

/// Landforms, in CGNDB's own `Generic Term` spelling, which is English in the
/// Quebec export too. `Pass` and `Passage` are left out because both provinces
/// file water channels under them, and `Rock` because most are rocks in lakes.
const terrainLabelTypes = {
  'Hill',
  'Hills',
  'Sand Hills',
  'Foothills',
  'Mountain',
  'Mountains',
  'Mount',
  'Mounts',
  'Peak',
  'Range',
  'Ridge',
  'Ridges',
  'Bluff',
  'Bluffs',
  'Cliff',
  'Cliffs',
  'Escarpment',
  'Butte',
  'Buttes',
  'Lookout',
  'Plateau',
  'Plateaus',
  'Valley',
  'Ravine',
  'Gorge',
  'Gorges',
  'Canyon',
  'Crater',
  'Esker',
  'Eskers',
  'Moraine',
  'Moraines',
  'Drumlins',
};

const wetlandLabelTypes = {
  'Marsh',
  'Marshes',
  'Swamp',
  'Bog',
  'Muskeg',
  'Wetland',
  'Wetlands',
};

/// The labels as GeoJSON points, each tagged `terrain` or `wetland` so one
/// layer can colour the two apart.
Map<String, dynamic> placeLabelCollection(GazetteerIndex index) => {
  'type': 'FeatureCollection',
  'features': [
    for (final place in index.placesOfType({
      ...terrainLabelTypes,
      ...wetlandLabelTypes,
    }))
      {
        'type': 'Feature',
        'properties': {
          'name': place.name,
          'kind':
              wetlandLabelTypes.contains(place.featureType)
                  ? 'wetland'
                  : 'terrain',
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [place.longitude, place.latitude],
        },
      },
  ],
};
