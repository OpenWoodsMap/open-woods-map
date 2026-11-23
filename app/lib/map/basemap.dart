import 'package:flutter/material.dart';

enum BasemapKind {
  offline,
  streets,
  satellite,
  hybrid,
}

extension BasemapKindX on BasemapKind {
  String get label => switch (this) {
        BasemapKind.offline => 'Offline (simple)',
        BasemapKind.streets => 'Streets',
        BasemapKind.satellite => 'Satellite',
        BasemapKind.hybrid => 'Hybrid',
      };

  String get shortHint => switch (this) {
        BasemapKind.offline => 'Plain background · always works offline',
        BasemapKind.streets => 'Roads, trails & water · OpenFreeMap',
        BasemapKind.satellite => 'ON/QC aerial photos · Sentinel-2 elsewhere',
        BasemapKind.hybrid =>
          'Aerial photos with roads, water & place names · OpenFreeMap',
      };

  IconData get icon => switch (this) {
        BasemapKind.offline => Icons.map_outlined,
        BasemapKind.streets => Icons.signpost_outlined,
        BasemapKind.satellite => Icons.satellite_alt,
        // Not a layers glyph: the Layers button sits beside this one in the
        // app bar, and two stacked-squares icons side by side read as the same
        // button twice.
        BasemapKind.hybrid => Icons.satellite_outlined,
      };

  /// All basemaps now ship bundled style JSON so saved offline areas include
  /// the terrain DEM source on Streets as well as Satellite and Hybrid.
  String? get remoteStyleUrl => null;

  String? get assetStylePath => switch (this) {
        BasemapKind.offline => 'assets/styles/offline.json',
        BasemapKind.streets => 'assets/styles/streets.json',
        BasemapKind.satellite => 'assets/styles/satellite.json',
        BasemapKind.hybrid => 'assets/styles/hybrid.json',
      };

  /// Whether an area of this basemap can be saved for offline use.
  ///
  /// The offline basemap draws a flat background and has nothing to fetch.
  bool get supportsOfflineAreas => this != BasemapKind.offline;
}
