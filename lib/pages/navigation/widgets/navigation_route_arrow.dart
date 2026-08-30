import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../controllers/navigation_controller.dart';

class NavigationRouteArrow {
  NavigationRouteArrow._();

  static const String leftTurnIconName = 'safir-turn-left';
  static const String rightTurnIconName = 'safir-turn-right';
  static const String straightIconName = 'safir-turn-straight';
  static const String uTurnIconName = 'safir-turn-uturn';

  static String getTurnIconName(String modifier) {
    switch (modifier) {
      case 'left':
      case 'slight left':
      case 'sharp left':
        return leftTurnIconName;

      case 'right':
      case 'slight right':
      case 'sharp right':
        return rightTurnIconName;

      case 'uturn':
        return uTurnIconName;

      default:
        return straightIconName;
    }
  }

  static double getRouteBearingAt(
    LatLng location,
    List<LatLng> points,
  ) {
    if (points.length < 2) return 0.0;

    var closestIndex = 0;
    var closestDistance = double.infinity;

    for (var index = 0; index < points.length; index++) {
      final point = points[index];

      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        point.latitude,
        point.longitude,
      );

      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }

    final startIndex = closestIndex > 0 ? closestIndex - 1 : closestIndex;
    final endIndex = closestIndex < points.length - 1
        ? closestIndex + 1
        : closestIndex;

    return _bearingBetween(
      points[startIndex],
      points[endIndex],
    );
  }

  static Future<void> drawDecorations({
    required MapLibreMapController controller,
    required NavigationController navigationController,
    required List<Symbol> turnSymbols,
  }) async {
    final routePoints = navigationController.currentRoutePoints;

    if (routePoints.length < 2) return;

    for (var index = 0;
        index < navigationController.routeSteps.length;
        index++) {
      final step = navigationController.routeSteps[index];

      if (step.distance < 18) continue;
      if (index == 0 && step.modifier == 'straight') continue;

      final turnSymbol = await controller.addSymbol(
        SymbolOptions(
          geometry: step.location,
          iconImage: getTurnIconName(step.modifier),
          iconSize: 0.52,
          iconRotate: getRouteBearingAt(
            step.location,
            routePoints,
          ),
        ),
      );

      turnSymbols.add(turnSymbol);

      final streetName = step.streetName.isNotEmpty
          ? step.streetName
          : step.instruction;

      if (streetName.isEmpty) continue;

      final streetLabel = await controller.addSymbol(
        SymbolOptions(
          geometry: step.location,
          textField: streetName,
          textSize: 12.5,
          textColor: '#FFFFFF',
          textHaloColor: '#07553D',
          textHaloWidth: 2.5,
          textOffset: const ui.Offset(0, -2.6),
        ),
      );

      turnSymbols.add(streetLabel);
    }

    await controller.setSymbolIconAllowOverlap(true);
    await controller.setSymbolIconIgnorePlacement(true);
  }

  static double _bearingBetween(
    LatLng start,
    LatLng end,
  ) {
    if (start.latitude == end.latitude && start.longitude == end.longitude) {
      return 0.0;
    }

    final startLatitude = start.latitude * math.pi / 180.0;
    final endLatitude = end.latitude * math.pi / 180.0;
    final longitudeDifference =
        (end.longitude - start.longitude) * math.pi / 180.0;

    final y = math.sin(longitudeDifference) * math.cos(endLatitude);
    final x = (math.cos(startLatitude) * math.sin(endLatitude)) -
        (math.sin(startLatitude) *
            math.cos(endLatitude) *
            math.cos(longitudeDifference));

    final bearing = math.atan2(y, x) * 180.0 / math.pi;

    return (bearing + 360.0) % 360.0;
  }
}
