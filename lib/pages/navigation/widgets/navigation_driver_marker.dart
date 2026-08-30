import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class NavigationDriverMarker {
  NavigationDriverMarker._();

  static const String driverIconName = 'safir-driver-arrow';

  static Future<void> addDriverArrowImage(
    MapLibreMapController controller,
  ) async {
    final imageBytes = await rootBundle.load(
      'assets/images/navigation_arrow.png',
    );

    await controller.addImage(
      driverIconName,
      imageBytes.buffer.asUint8List(),
    );
  }

  static LatLng getOffsetTarget(
    LatLng driverLocation,
    double bearing,
    double distanceInMeters,
  ) {
    const earthRadius = 6371000.0;

    final bearingRadians = bearing * math.pi / 180.0;
    final latitudeRadians = driverLocation.latitude * math.pi / 180.0;
    final longitudeRadians = driverLocation.longitude * math.pi / 180.0;
    final angularDistance = distanceInMeters / earthRadius;

    final targetLatitudeRadians = math.asin(
      (math.sin(latitudeRadians) * math.cos(angularDistance)) +
          (math.cos(latitudeRadians) *
              math.sin(angularDistance) *
              math.cos(bearingRadians)),
    );

    final targetLongitudeRadians = longitudeRadians +
        math.atan2(
          math.sin(bearingRadians) *
              math.sin(angularDistance) *
              math.cos(latitudeRadians),
          math.cos(angularDistance) -
              (math.sin(latitudeRadians) * math.sin(targetLatitudeRadians)),
        );

    return LatLng(
      targetLatitudeRadians * 180.0 / math.pi,
      targetLongitudeRadians * 180.0 / math.pi,
    );
  }

  static Future<Symbol> updateMarker({
    required MapLibreMapController controller,
    required Symbol? currentSymbol,
    required LatLng location,
    required double heading,
  }) async {
    const optionsBase = SymbolOptions(
      iconImage: driverIconName,
      iconSize: 0.76,
      iconAnchor: 'top',
    );

    final options = SymbolOptions(
      geometry: location,
      iconImage: optionsBase.iconImage,
      iconSize: optionsBase.iconSize,
      iconAnchor: optionsBase.iconAnchor,
      iconRotate: heading,
    );

    final symbol = currentSymbol == null
        ? await controller.addSymbol(options)
        : await controller.updateSymbol(currentSymbol, options);

    await controller.setSymbolIconAllowOverlap(true);
    await controller.setSymbolIconIgnorePlacement(true);

    return symbol;
  }
}
