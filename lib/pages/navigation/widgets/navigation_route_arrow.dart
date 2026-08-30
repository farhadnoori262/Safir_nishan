import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../controllers/navigation_controller.dart';
import '../navigation_map_painters.dart';

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

  static TurnDirection _getTurnDirection(String modifier) {
    switch (modifier) {
      case 'left':
      case 'slight left':
      case 'sharp left':
        return TurnDirection.left;
      case 'right':
      case 'slight right':
      case 'sharp right':
        return TurnDirection.right;
      case 'uturn':
        return TurnDirection.uTurn;
      default:
        return TurnDirection.straight;
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

    final startIndex = closestIndex;
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
          iconAnchor: 'center',
          iconPitchAlignment: 'map',
          iconRotationAlignment: 'map',
        ),
      );

      turnSymbols.add(turnSymbol);

      final streetName = step.streetName.isNotEmpty
          ? step.streetName
          : step.instruction;

      if (streetName.isEmpty) continue;

      // ساخت تابلوی کپسولی پویا با اسم خیابان + آیکون جهت
      final bannerImageKey = 'safir-banner-${step.location.latitude}-${step.location.longitude}';
      final direction = _getTurnDirection(step.modifier);

      await NavigationMapPainters.addCanvasImage(
        controller,
        bannerImageKey,
        (canvas, size) => NavigationMapPainters.drawStepBanner(
          canvas,
          size,
          streetName: streetName,
          direction: direction,
        ),
        width: 320,
        height: 110,
      );

      final streetLabel = await controller.addSymbol(
        SymbolOptions(
          geometry: step.location,
          iconImage: bannerImageKey,
          iconSize: 0.85,
          iconAnchor: 'bottom', // نقطه اتکای پایه تابلو
          iconPitchAlignment: 'viewport', // همواره رو به دوربین باقی بماند
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
