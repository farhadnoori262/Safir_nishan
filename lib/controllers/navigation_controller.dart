import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:safir_drivers/helpers/voice_guidance_helper.dart';

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
    final maneuver = json['maneuver'] as Map<String, dynamic>? ?? {};
    final location = maneuver['location'] as List<dynamic>? ?? const [0.0, 0.0];

    final double longitude = location.isNotEmpty && location[0] is num
        ? (location[0] as num).toDouble()
        : 0.0;

    final double latitude = location.length > 1 && location[1] is num
        ? (location[1] as num).toDouble()
        : 0.0;

    final String name = json['name']?.toString().trim() ?? '';

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
  static const double _hardSnapCutoffMeters = 90.0;
  static const double _rerouteDistanceMeters = 55.0;
  static const double _announceDistanceMeters = 70.0;
  static const double _stepReachedDistanceMeters = 16.0;
  static const Duration _routeRequestTimeout = Duration(seconds: 10);

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
  List<LatLng> get currentRoutePoints => List.unmodifiable(routePoints);
  List<StepInstruction> get routeSteps => List.unmodifiable(_steps);

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
      // نزدیک به مسیر: کاملاً بچسب به خط
      snappedDriverLocation = routeMatch.point;
      driverRouteBearing = routeMatch.bearing;
    } else if (routeMatch.distance <= _hardSnapCutoffMeters) {
      // فاصله متوسط (نویز GPS شهری): بین نقطه خام و نقطه روی خط ترکیب کن
      // تا جهش ناگهانی فلش رخ نده
      final blendFactor = (routeMatch.distance - _snapToRouteDistanceMeters) /
          (_hardSnapCutoffMeters - _snapToRouteDistanceMeters);

      snappedDriverLocation = LatLng(
        routeMatch.point.latitude +
            ((driverLocation.latitude - routeMatch.point.latitude) * blendFactor),
        routeMatch.point.longitude +
            ((driverLocation.longitude - routeMatch.point.longitude) * blendFactor),
      );
      driverRouteBearing = routeMatch.bearing;
    } else {
      // فاصله زیاد: احتمالاً مسیر واقعاً عوض شده، موقعیت خام را نشان بده
      snappedDriverLocation = driverLocation;
    }

    _updateStepProgress();

    if (distanceFromRoute > _rerouteDistanceMeters && !isRerouting) {
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
      final response = await http.get(url).timeout(_routeRequestTimeout);

      if (response.statusCode != 200) {
        debugPrint('osrm_error_status'.tr(args: [response.statusCode.toString()]));
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
    } on TimeoutException {
      debugPrint('osrm_error_timeout'.tr());
      return null;
    } catch (error) {
      debugPrint('osrm_error_fetch'.tr(args: [error.toString()]));
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
              parsedSteps.add(StepInstruction.fromJson(step));
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

    distanceFromRoute =
