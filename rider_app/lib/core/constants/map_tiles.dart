import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Single source of truth for the basemap used by every map in this app.
///
/// CARTO stopped serving its `basemaps.cartocdn.com` raster tiles to
/// unauthenticated clients: the endpoint still returns 200 OK, but every tile
/// is stamped "API KEY REQUIRED", which is why maps rendered as a grey grid
/// covered in watermarks. We render the OpenStreetMap standard tiles instead,
/// which need no key.
///
/// To move to a keyed provider later (MapTiler, Stadia, Thunderforest, a
/// CARTO account, ...) change only this file — every map screen goes through
/// [MapTiles.base].
class MapTiles {
  const MapTiles._();

  static const String urlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Identifies the app to the tile server. The OSM tile usage policy rejects
  /// clients that do not send a real, resolvable application id.
  static const String userAgentPackageName = 'com.ordogo.rider_app';

  /// OSM renders its standard layer up to z19; past that we upscale z19 tiles
  /// instead of requesting tiles the server does not have (which would render
  /// as blank squares when the user zooms right in).
  static const int maxNativeZoom = 19;
  static const double maxZoom = 20;

  /// The basemap layer. Use this in place of a hand-written [TileLayer].
  static TileLayer base() => TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: userAgentPackageName,
        maxNativeZoom: maxNativeZoom,
        maxZoom: maxZoom,
      );

  /// Attribution required by the OpenStreetMap tile usage policy. Renders as a
  /// small "i" badge that expands on tap.
  static Widget attribution({
    AttributionAlignment alignment = AttributionAlignment.bottomLeft,
  }) =>
      RichAttributionWidget(
        alignment: alignment,
        showFlutterMapAttribution: false,
        attributions: const [
          TextSourceAttribution('OpenStreetMap contributors'),
        ],
      );
}
