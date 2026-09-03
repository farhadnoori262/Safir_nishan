import 'dart:convert';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../helpers/voice_guidance_helper.dart';

class StepInstruction {
  final String instruction;
  final String streetName;
  final String modifier;
  final LatLng location;
  final double distance;

  const StepInstruction({
    required this.instruction,
    required this.streetName,
    required this.modifier,
    required this.location,
    required this.distance,
  });

  factory StepInstruction.fromJson(Map<String, dynamic> json) {
    final maneuver =
        json['maneuver'] as Map<String, dynamic>? ?? {};

    final location =
        maneuver['location'] as List<dynamic>? ?? const [0.0, 0.0];

    final longitude = location.isNotEmpty && location[0] is num
        ? (location[0] as num).toDouble()
        : 0.0;

    final latitude = location.length > 1 && location[1] is num
        ? (location[1] as num).toDouble()
        : 0.0;

    final name = json['name']?.toString().trim() ?? '';

    return StepInstruction(
      instruction: maneuver['type']?.toString() ?? 'straight',
      streetName: name,
      modifier: maneuver['modifier']?.toString() ?? 'straight',
      location: LatLng(latitude, longitude),
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NavigationController extends ChangeNotifier {
  static const double _snapToRouteDistanceMeters = 40.0;
  static const double _rerouteDistanceMeters = 55.0;
  static const double _announceDistanceMeters = 70.0;
  static const double _stepReachedDistanceMeters = 16.0;

  int routeVersion = 0;

  LatLng? activeDestination;
  LatLng? snappedDriverLocation;
  LatLng? rawDriverLocation;

  bool isRerouting = false;
  bool isNavigating = false;

  bool _isVoiceEnabled = true;
  bool _isDisposed = false;

  double distanceFromRoute = 0.0;
  double distanceToNextStep = 0.0;
  double driverRouteBearing = 0.0;

  final List<StepInstruction> _steps = [];
  final List<LatLng> routePoints = [];
  final Set<int> _spokenSteps = {};

  int _currentStepIndex = 0;
  int _lastMatchedSegmentIndex = 0;

  String _activeLangCode = 'fa';
  String currentStreet = '';
  String currentModifier = 'straight';
  String _currentInstruction = '';
  IconData _currentTurnIcon = Icons.straight_rounded;

  bool get isVoiceEnabled => _isVoiceEnabled;

  int get distanceToNextTurn => distanceToNextStep.ceil();

  String get navigationInstruction {
    if (_currentInstruction.isNotEmpty) {
      return _currentInstruction;
    }

    if (currentStreet.isNotEmpty) {
      return currentStreet;
    }

    return _instructionFromModifier(currentModifier);
  }

  IconData get currentTurnIcon => _currentTurnIcon;

  List<LatLng> get currentRoutePoints =>
      List.unmodifiable(routePoints);

  List<StepInstruction> get routeSteps =>
      List.unmodifiable(_steps);

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;

    if (!_isVoiceEnabled) {
      VoiceGuidanceHelper.stop();
    }

    _safeNotifyListeners();
  }

  void speakInstruction(String text) {
    if (!_isVoiceEnabled) return;

    VoiceGuidanceHelper.speakStep(
      'straight',
      text,
      0,
      _activeLangCode,
    );
  }

  void updateInstruction({
    required String instruction,
    required int distance,
    required IconData icon,
  }) {
    _currentInstruction = instruction;
    distanceToNextStep = distance.toDouble();
    _currentTurnIcon = icon;
    _safeNotifyListeners();
  }

  Future<List<LatLng>> startNavigation(
    LatLng start,
    LatLng destination,
    String langCode,
  ) async {
    isNavigating = true;
    isRerouting = false;

    _activeLangCode = langCode;
    activeDestination = destination;
    rawDriverLocation = start;
    snappedDriverLocation = start;

    _clearRouteState();

    _safeNotifyListeners();

    final route = await _fetchRoute(
      start: start,
      destination: destination,
    );

    if (!isNavigating || route == null) {
      return [];
    }

    _applyRoute(route);

    if (routePoints.length > 1) {
      driverRouteBearing = _bearingBetween(
        routePoints.first,
        routePoints[1],
      );
    }

    _speakStartInstruction();

    _safeNotifyListeners();

    return List.unmodifiable(routePoints);
  }

  void updateDriverPosition(
    LatLng driverLocation, {
    String? langCode,
  }) {
    if (!isNavigating || routePoints.length < 2) {
      return;
    }

    if (langCode != null && langCode.isNotEmpty) {
      _activeLangCode = langCode;
    }

    rawDriverLocation = driverLocation;

    final routeMatch = _findClosestPointOnRoute(driverLocation);

    distanceFromRoute = routeMatch.distance;
    _lastMatchedSegmentIndex = routeMatch.segmentIndex;

    if (routeMatch.distance <= _snapToRouteDistanceMeters) {
      snappedDriverLocation = routeMatch.point;
      driverRouteBearing = routeMatch.bearing;
    } else {
      snappedDriverLocation = driverLocation;
    }

    _updateStepProgress();

    if (distanceFromRoute > _rerouteDistanceMeters &&
        !isRerouting) {
      _rerouteFromCurrentLocation(driverLocation);
    }

    _safeNotifyListeners();
  }

  Future<Map<String, dynamic>?> _fetchRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&steps=true&geometries=geojson',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint(
          'osrm_error_status'.tr(
            args: [response.statusCode.toString()],
          ),
        );
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final routes = decoded['routes'];

      if (routes is! List || routes.isEmpty) {
        return null;
      }

      final route = routes.first;

      if (route is! Map<String, dynamic>) {
        return null;
      }

      return route;
    } catch (error) {
      debugPrint(
        'osrm_error_fetch'.tr(
          args: [error.toString()],
        ),
      );

      return null;
    }
  }

  void _applyRoute(Map<String, dynamic> route) {
    final geometry = route['geometry'];

    if (geometry is! Map<String, dynamic>) {
      return;
    }

    final coordinates = geometry['coordinates'];

    if (coordinates is! List) {
      return;
    }

    final parsedPoints = <LatLng>[];

    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) {
        continue;
      }

      final longitude = coordinate[0];
      final latitude = coordinate[1];

      if (longitude is! num || latitude is! num) {
        continue;
      }

      parsedPoints.add(
        LatLng(
          latitude.toDouble(),
          longitude.toDouble(),
        ),
      );
    }

    if (parsedPoints.length < 2) {
      return;
    }

    routePoints
      ..clear()
      ..addAll(parsedPoints);

    final parsedSteps = <StepInstruction>[];

    final legs = route['legs'];

    if (legs is List && legs.isNotEmpty) {
      final firstLeg = legs.first;

      if (firstLeg is Map<String, dynamic>) {
        final steps = firstLeg['steps'];

        if (steps is List) {
          for (final step in steps) {
            if (step is Map<String, dynamic>) {
              parsedSteps.add(
                StepInstruction.fromJson(step),
              );
            }
          }
        }
      }
    }

    _steps
      ..clear()
      ..addAll(parsedSteps);

    _currentStepIndex = 0;
    _lastMatchedSegmentIndex = 0;
    _spokenSteps.clear();

    distanceFromRoute = 0.0;
    distanceToNextStep = 0.0;

    if (_steps.isNotEmpty) {
      _updateCurrentStepInfo(notify: false);
    } else {
      currentStreet = '';
      currentModifier = 'straight';
      _currentInstruction = 'مستقیم بروید';
      _currentTurnIcon = Icons.straight_rounded;
    }

    routeVersion++;
  }

  void _updateStepProgress() {
    final currentLocation = snappedDriverLocation;

    if (currentLocation == null ||
        _steps.isEmpty ||
        _currentStepIndex >= _steps.length) {
      return;
    }

    var step = _steps[_currentStepIndex];

    distanceToNextStep = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      step.location.latitude,
      step.location.longitude,
    );

    if (distanceToNextStep <= _announceDistanceMeters &&
        !_spokenSteps.contains(_currentStepIndex)) {
      _spokenSteps.add(_currentStepIndex);

      if (_isVoiceEnabled) {
        VoiceGuidanceHelper.speakStep(
          step.modifier,
          step.streetName,
          distanceToNextStep.round(),
          _activeLangCode,
        );
      }
    }

    if (distanceToNextStep <= _stepReachedDistanceMeters &&
        _currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _updateCurrentStepInfo(notify: false);

      step = _steps[_currentStepIndex];

      distanceToNextStep = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        step.location.latitude,
        step.location.longitude,
      );
    }
  }

  Future<void> _rerouteFromCurrentLocation(LatLng from) async {
    final destination = activeDestination;

    if (destination == null || isRerouting || !isNavigating) {
      return;
    }

    isRerouting = true;
    _safeNotifyListeners();

    final route = await _fetchRoute(
      start: from,
      destination: destination,
    );

    if (route != null && isNavigating) {
      _applyRoute(route);

      if (routePoints.length > 1) {
        driverRouteBearing = _bearingBetween(
          routePoints.first,
          routePoints[1],
        );
      }
    }

    isRerouting = false;
    _safeNotifyListeners();
  }

  _RouteMatch _findClosestPointOnRoute(LatLng location) {
    var closestPoint = routePoints.first;
    var closestDistance = double.infinity;
    var closestSegmentIndex = 0;
    var closestBearing = 0.0;

    final startIndex = math.max(
      0,
      _lastMatchedSegmentIndex - 25,
    );

    final endIndex = math.min(
      routePoints.length - 2,
      _lastMatchedSegmentIndex + 100,
    );

    for (var index = startIndex;
        index <= endIndex;
        index++) {
      final segmentStart = routePoints[index];
      final segmentEnd = routePoints[index + 1];

      final projectedPoint = _projectPointOnSegment(
        location,
        segmentStart,
        segmentEnd,
      );

      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        projectedPoint.latitude,
        projectedPoint.longitude,
      );

      if (distance < closestDistance) {
        closestDistance = distance;
        closestPoint = projectedPoint;
        closestSegmentIndex = index;
        closestBearing = _bearingBetween(
          segmentStart,
          segmentEnd,
        );
      }
    }

    return _RouteMatch(
      point: closestPoint,
      distance: closestDistance,
      segmentIndex: closestSegmentIndex,
      bearing: closestBearing,
    );
  }

  LatLng _projectPointOnSegment(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    final latitudeRadians =
        point.latitude * math.pi / 180.0;

    const metersPerLatitudeDegree = 111132.0;

    final metersPerLongitudeDegree =
        111320.0 * math.cos(latitudeRadians);

    final pointX =
        point.longitude * metersPerLongitudeDegree;
    final pointY =
        point.latitude * metersPerLatitudeDegree;

    final startX =
        segmentStart.longitude * metersPerLongitudeDegree;
    final startY =
        segmentStart.latitude * metersPerLatitudeDegree;

    final endX =
        segmentEnd.longitude * metersPerLongitudeDegree;
    final endY =
        segmentEnd.latitude * metersPerLatitudeDegree;

    final deltaX = endX - startX;
    final deltaY = endY - startY;

    final lengthSquared =
        (deltaX * deltaX) + (deltaY * deltaY);

    if (lengthSquared == 0) {
      return segmentStart;
    }

    var projection = (
          ((pointX - startX) * deltaX) +
          ((pointY - startY) * deltaY)
        ) /
        lengthSquared;

    projection = projection.clamp(0.0, 1.0).toDouble();

    final projectedX = startX + (projection * deltaX);
    final projectedY = startY + (projection * deltaY);

    return LatLng(
      projectedY / metersPerLatitudeDegree,
      projectedX / metersPerLongitudeDegree,
    );
  }

  double _bearingBetween(
    LatLng start,
    LatLng end,
  ) {
    final startLatitude =
        start.latitude * math.pi / 180.0;

    final endLatitude =
        end.latitude * math.pi / 180.0;

    final longitudeDifference =
        (end.longitude - start.longitude) *
            math.pi /
            180.0;

    final y = math.sin(longitudeDifference) *
        math.cos(endLatitude);

    final x =
        (math.cos(startLatitude) *
            math.sin(endLatitude)) -
        (math.sin(startLatitude) *
            math.cos(endLatitude) *
            math.cos(longitudeDifference));

    final bearing = math.atan2(y, x) * 180.0 / math.pi;

    return (bearing + 360.0) % 360.0;
  }

  void _updateCurrentStepInfo({
    bool notify = true,
  }) {
    if (_steps.isEmpty ||
        _currentStepIndex >= _steps.length) {
      return;
    }

    final step = _steps[_currentStepIndex];

    currentStreet = step.streetName;
    currentModifier = step.modifier;

    _currentInstruction = step.streetName.isNotEmpty
        ? step.streetName
        : _instructionFromModifier(step.modifier);

    _currentTurnIcon = _iconFromModifier(step.modifier);

    if (notify) {
      _safeNotifyListeners();
    }
  }

  String _instructionFromModifier(String modifier) {
    switch (modifier) {
      case 'right':
      case 'slight right':
      case 'sharp right':
        return 'به راست بپیچید';

      case 'left':
      case 'slight left':
      case 'sharp left':
        return 'به چپ بپیچید';

      case 'uturn':
        return 'دور بزنید';

      default:
        return 'مستقیم بروید';
    }
  }

  IconData _iconFromModifier(String modifier) {
    switch (modifier) {
      case 'right':
      case 'slight right':
      case 'sharp right':
        return Icons.turn_right_rounded;

      case 'left':
      case 'slight left':
      case 'sharp left':
        return Icons.turn_left_rounded;

      case 'uturn':
        return Icons.u_turn_left_rounded;

      default:
        return Icons.straight_rounded;
    }
  }

  void _speakStartInstruction() {
    if (!_isVoiceEnabled || _steps.isEmpty) return;

    final firstStep = _steps.first;

    VoiceGuidanceHelper.speakStep(
      firstStep.modifier,
      firstStep.streetName,
      0,
      _activeLangCode,
    );
  }

  void _clearRouteState() {
    _steps.clear();
    routePoints.clear();
    _spokenSteps.clear();

    _currentStepIndex = 0;
    _lastMatchedSegmentIndex = 0;

    distanceFromRoute = 0.0;
    distanceToNextStep = 0.0;
    driverRouteBearing = 0.0;

    currentStreet = '';
    currentModifier = 'straight';
    _currentInstruction = '';
    _currentTurnIcon = Icons.straight_rounded;
  }

  void stopNavigation() {
    isNavigating = false;
    isRerouting = false;

    activeDestination = null;
    rawDriverLocation = null;
    snappedDriverLocation = null;

    _clearRouteState();

    VoiceGuidanceHelper.stop();
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    VoiceGuidanceHelper.stop();
    super.dispose();
  }
}

class _RouteMatch {
  final LatLng point;
  final double distance;
  final int segmentIndex;
  final double bearing;

  const _RouteMatch({
    required this.point,
    required this.distance,
    required this.segmentIndex,
    required this.bearing,
  });
}
