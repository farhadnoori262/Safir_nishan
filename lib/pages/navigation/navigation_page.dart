import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../controllers/navigation_controller.dart';
import '../../models/place_search_result.dart';
import '../../pages/auth/register_screen.dart';
import '../../services/place_search_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/navigation/destination_search_sheet.dart';
import 'navigation_map_painters.dart';

class NavigationPage extends StatefulWidget {
  final LatLng? currentLocation;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final bool isDriverTrip;

  const NavigationPage({
    super.key,
    this.currentLocation,
    this.pickupLocation,
    this.dropoffLocation,
    this.isDriverTrip = false,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage>
    with SingleTickerProviderStateMixin {
  static const String _driverIconName = 'safir-driver-arrow';
  static const String _destinationIconName = 'safir-destination-pin';
  static const String _currentLocationIconName =
      'safir-current-location-pulse';
  static const String _leftTurnIconName = 'safir-turn-left';
  static const String _rightTurnIconName = 'safir-turn-right';
  static const String _straightIconName = 'safir-turn-straight';
  static const String _uTurnIconName = 'safir-turn-uturn';

  static const LatLng _fallbackLocation = LatLng(34.5553, 69.2075);

  MapLibreMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  Symbol? _driverSymbol;
  Symbol? _currentLocationSymbol;
  Symbol? _destinationSymbol;

  final List<Symbol> _turnSymbols = [];
  final List<Line> _turnLines = [];

  PlaceSearchResult? _selectedPlace;
  LatLng? _selectedDestination;
  LatLng? _currentLocation;
  double _currentAccuracy = 20.0;

  late final AnimationController _pulseController;

  bool _mapStyleReady = false;
  bool _iconsAdded = false;
  bool _navigationStarted = false;
  bool _controllerListenerAdded = false;
  bool _cameraFollowing = false;
  bool _isUpdatingMap = false;
  bool _isProgrammaticCameraMove = false;
  bool _isLoadingLocation = true;

  int _lastRouteVersion = 0;

  /// 🌙 متد هوشمند تشخیص حالت تاریک نقشه بر اساس ساعت دستگاه
  String get _currentMapStyle {
    final hour = DateTime.now().hour;
    final isNight = hour >= 19 || hour < 6;

    if (isNight) {
      // استایل تاریک استاندارد شب
      return 'https://tiles.stadiamaps.com/styles/alidade_smooth_dark.json';
    } else {
      // استایل اختصاصی و رنگی خودتان برای روز
      return 'assets/map/style.json';
    }
  }

  LatLng get _startLocation =>
      widget.pickupLocation ??
      _currentLocation ??
      widget.currentLocation ??
      _fallbackLocation;

  @override
  void initState() {
    super.initState();

    _currentLocation = widget.currentLocation;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController.addListener(_updateCurrentLocationPulse);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoadingLocation) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    });

    _startLocationTracking();
  }

  void _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;

    await controller.updateMyLocationTrackingMode(
      MyLocationTrackingMode.tracking,
    );
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;

    _mapStyleReady = true;

    final navigationController =
        Provider.of<NavigationController>(context, listen: false);

    if (!_controllerListenerAdded) {
      navigationController.addListener(_navigationControllerChanged);
      _controllerListenerAdded = true;
    }

    await _addMapImages();
    await _showCurrentLocationMarker(moveCamera: false);

    if (_selectedDestination != null) {
      await _showSelectedDestinationMarker(moveCamera: false);
    }

    _checkAndStartDriverTrip();
  }

  Future<void> _checkAndStartDriverTrip() async {
    if (!widget.isDriverTrip || widget.dropoffLocation == null) {
      return;
    }

    if (_navigationStarted) {
      return;
    }

    setState(() {
      _selectedDestination = widget.dropoffLocation;
      _selectedPlace = PlaceSearchResult(
        title: 'passenger_destination'.tr(),
        address: 'smart_navigation_safir'.tr(),
        latitude: widget.dropoffLocation!.latitude,
        longitude: widget.dropoffLocation!.longitude,
      );
    });

    await _showSelectedDestinationMarker(moveCamera: true);
    await _startNavigation();
  }

  Future<void> _startLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('enable_location_service'.tr());
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('location_permission_denied'.tr());
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            16.5,
          ),
        );
      }

      await _handleLocationUpdate(position);

      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }

      await _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).listen((position) async {
        await _handleLocationUpdate(position);
      });
    } catch (_) {
      _showMessage('cannot_get_current_location'.tr());
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _handleLocationUpdate(Position position) async {
    if (!mounted || _isUpdatingMap) return;

    _isUpdatingMap = true;

    try {
      final rawLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentLocation = rawLocation;
          _currentAccuracy = position.accuracy;
        });
      }

      final navigationController =
          Provider.of<NavigationController>(context, listen: false);

      if (_navigationStarted && navigationController.isNavigating) {
        navigationController.updateDriverPosition(
          rawLocation,
          langCode: context.locale.languageCode,
        );

        final driverLocation =
            navigationController.snappedDriverLocation ?? rawLocation;

        await _updateDriverMarker(
          driverLocation,
          heading: navigationController.driverRouteBearing,
          moveCamera: _cameraFollowing,
        );
      } else {
        await _showCurrentLocationMarker(moveCamera: false);
      }
    } finally {
      _isUpdatingMap = false;
    }
  }

  void _updateCurrentLocationPulse() {
    if (!_navigationStarted) {
      _showCurrentLocationMarker(moveCamera: false);
    }
  }
  
  Future<void> _addDriverArrowImage() async {
  if (_mapController == null) return;

  final ByteData imageBytes = await rootBundle.load(
    'assets/images/navigation_arrow.png',
  );

  await _mapController!.addImage(
    _driverIconName,
    imageBytes.buffer.asUint8List(),
  );
}

  Future<void> _addMapImages() async {
    if (_mapController == null || _iconsAdded) return;

    await _addDriverArrowImage();

    await NavigationMapPainters.addCanvasImage(
      _mapController!,
      _currentLocationIconName,
      (canvas, size) => NavigationMapPainters.drawCurrentLocationPulse(
        canvas,
        size,
        _pulseController.value,
        _currentAccuracy,
      ),
      width: 180,
      height: 180,
    );

    await NavigationMapPainters.addCanvasImage(
      _mapController!,
      _destinationIconName,
      NavigationMapPainters.drawDestinationPin,
      width: 100,
      height: 124,
    );
    await NavigationMapPainters.addCanvasImage(
  _mapController!,
  _leftTurnIconName,
  (canvas, size) => NavigationMapPainters.drawTurnArrow(
    canvas,
    size,
    direction: TurnDirection.left,
  ),
  width: 96,
  height: 96,
);

await NavigationMapPainters.addCanvasImage(
  _mapController!,
  _rightTurnIconName,
  (canvas, size) => NavigationMapPainters.drawTurnArrow(
    canvas,
    size,
    direction: TurnDirection.right,
  ),
  width: 96,
  height: 96,
);

await NavigationMapPainters.addCanvasImage(
  _mapController!,
  _straightIconName,
  (canvas, size) => NavigationMapPainters.drawTurnArrow(
    canvas,
    size,
    direction: TurnDirection.straight,
  ),
  width: 96,
  height: 96,
);

await NavigationMapPainters.addCanvasImage(
  _mapController!,
  _uTurnIconName,
  (canvas, size) => NavigationMapPainters.drawTurnArrow(
    canvas,
    size,
    direction: TurnDirection.uTurn,
  ),
  width: 96,
  height: 96,
);

    _iconsAdded = true;
  }

  Future<void> _onPlaceSelected(
    PlaceSearchResult place,
  ) async {
    if (!mounted) return;

    setState(() {
      _selectedPlace = place;
      _selectedDestination = LatLng(
        place.latitude,
        place.longitude,
      );
    });

    await _showSelectedDestinationMarker(moveCamera: true);
  }

  Future<void> _selectDestinationFromMap(
    LatLng coordinates,
  ) async {
    final temporaryPlace = PlaceSearchResult(
      title: 'getting_address'.tr(),
      address: 'please_wait'.tr(),
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );

    await _onPlaceSelected(temporaryPlace);

    final placeSearchService = PlaceSearchService();

    final realPlace = await placeSearchService.reverseGeocode(
      coordinates.latitude,
      coordinates.longitude,
      languageCode: context.locale.languageCode,
    );

    if (!mounted || realPlace == null) {
      if (mounted) {
        _showMessage('address_not_found'.tr());
      }
      return;
    }

    await _onPlaceSelected(realPlace);
  }

  Future<void> _showSelectedDestinationMarker({
    required bool moveCamera,
  }) async {
    if (!_mapStyleReady ||
        !_iconsAdded ||
        _mapController == null ||
        _selectedDestination == null) {
      return;
    }

    final options = SymbolOptions(
      geometry: _selectedDestination!,
      iconImage: _destinationIconName,
      iconSize: 0.70,
    );

    if (_destinationSymbol == null) {
      _destinationSymbol = await _mapController!.addSymbol(options);
    } else {
      await _mapController!.updateSymbol(
        _destinationSymbol!,
        options,
      );
    }

    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);

    if (!moveCamera) return;

    _isProgrammaticCameraMove = true;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _selectedDestination!,
            zoom: 16.5,
          ),
        ),
        duration: const Duration(milliseconds: 550),
      );
    } finally {
      Future.delayed(
        const Duration(milliseconds: 700),
        () {
          if (mounted) {
            _isProgrammaticCameraMove = false;
          }
        },
      );
    }
  }

  Future<void> _showCurrentLocationMarker({
    required bool moveCamera,
  }) async {
    if (!_mapStyleReady ||
        !_iconsAdded ||
        _mapController == null ||
        _currentLocation == null ||
        _navigationStarted) {
      return;
    }

    final options = SymbolOptions(
      geometry: _currentLocation!,
      iconImage: _currentLocationIconName,
      iconSize: 0.72,
    );

    if (_currentLocationSymbol == null) {
      _currentLocationSymbol =
          await _mapController!.addSymbol(options);
    } else {
      await _mapController!.updateSymbol(
        _currentLocationSymbol!,
        options,
      );
    }

    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);

    if (!moveCamera) return;

    await _moveCameraToLocation(
      _currentLocation!,
      zoom: 16.5,
      tilt: 35.0,
    );
  }

  Future<void> _confirmDestination() async {
    if (_selectedDestination == null) {
      _showMessage('select_destination_first'.tr());
      return;
    }

    if (_navigationStarted) return;

    await _startNavigation();
  }

  Future<void> _startNavigation() async {
    if (!_mapStyleReady ||
        _mapController == null ||
        _selectedDestination == null ||
        _navigationStarted) {
      return;
    }

    setState(() {
      _navigationStarted = true;
      _cameraFollowing = true;
    });

    final navigationController =
        Provider.of<NavigationController>(context, listen: false);

    final routePoints = await navigationController.startNavigation(
      _startLocation,
      _selectedDestination!,
      context.locale.languageCode,
    );

    if (!mounted || _mapController == null || routePoints.isEmpty) {
      if (mounted) {
        setState(() {
          _navigationStarted = false;
          _cameraFollowing = false;
        });
      }

      _showMessage('route_not_found_check_internet'.tr());
      return;
    }

    _lastRouteVersion = navigationController.routeVersion;

    if (_currentLocationSymbol != null) {
      await _mapController!.removeSymbol(_currentLocationSymbol!);
      _currentLocationSymbol = null;
    }

    await _drawRoute(routePoints);
    await _drawRouteDecorations(navigationController);

    await _updateDriverMarker(
      navigationController.snappedDriverLocation ?? _startLocation,
      heading: navigationController.driverRouteBearing,
      moveCamera: true,
    );
  }

  Future<void> _drawRoute(List<LatLng> points) async {
  if (_mapController == null || points.length < 2) return;

  await _mapController!.clearLines();

  // حاشیهٔ تیره برای جدا شدن مسیر از خیابان‌ها
  await _mapController!.addLine(
    LineOptions(
      geometry: points,
      lineColor: '#07553D',
      lineWidth: 18.0,
      lineOpacity: 0.96,
    ),
  );

  // مسیر اصلی سبز و واضح
  await _mapController!.addLine(
    LineOptions(
      geometry: points,
      lineColor: '#19B879',
      lineWidth: 11.0,
      lineOpacity: 1.0,
    ),
  );
  }

  Future<void> _drawRouteDecorations(
    NavigationController navigationController,
  ) async {
    if (_mapController == null || _selectedDestination == null) {
      return;
    }

    await _clearRouteDecorations(keepDestination: true);

    if (_destinationSymbol == null) {
      _destinationSymbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: _selectedDestination!,
          iconImage: _destinationIconName,
          iconSize: 0.70,
        ),
      );
    }

    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);

    final routePoints = navigationController.currentRoutePoints;

    for (var index = 0;
        index < navigationController.routeSteps.length;
        index++) {
      final step = navigationController.routeSteps[index];

      if (step.distance < 18) continue;
      if (index == 0 && step.modifier == 'straight') continue;

      final stepSegment = _extractManeuverSegment(step.location, routePoints);

      final symbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: step.location,
          iconImage: _turnIconName(step.modifier),
          iconSize: 0.44,
          iconRotate: _routeBearingAt(
            step.location,
            routePoints,
          ),
        ),
      );

      _turnSymbols.add(symbol);

      final streetName = step.streetName.isNotEmpty
          ? step.streetName
          : step.instruction;

      if (streetName.isNotEmpty) {
        final labelSymbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: step.location,
            textField: streetName,
            textSize: 12.0,
            textColor: '#FFFFFF',
            textHaloColor: '#145A41',
            textHaloWidth: 2.0,
            textOffset: const Offset(0, -2.0),
          ),
        );

        _turnSymbols.add(labelSymbol);
      }
    }
  }

  List<LatLng> _extractManeuverSegment(LatLng turnPoint, List<LatLng> points) {
    if (points.length < 2) return [];

    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < points.length; i++) {
      final dist = Geolocator.distanceBetween(
        turnPoint.latitude,
        turnPoint.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    final int startIndex = math.max(0, closestIndex - 2);
    final int endIndex = math.min(points.length - 1, closestIndex + 2);

    return points.sublist(startIndex, endIndex + 1);
  }

  String _turnIconName(String modifier) {
    switch (modifier) {
      case 'left':
      case 'slight left':
      case 'sharp left':
        return _leftTurnIconName;

      case 'right':
      case 'slight right':
      case 'sharp right':
        return _rightTurnIconName;

      case 'uturn':
        return _uTurnIconName;

      default:
        return _straightIconName;
    }
  }

  double _routeBearingAt(
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

    final previousIndex =
        closestIndex > 0 ? closestIndex - 1 : closestIndex;

    final nextIndex = closestIndex < points.length - 1
        ? closestIndex + 1
        : closestIndex;

    final start = points[previousIndex];
    final end = points[nextIndex];

    final startLatitude = start.latitude * math.pi / 180.0;
    final endLatitude = end.latitude * math.pi / 180.0;

    final longitudeDifference =
        (end.longitude - start.longitude) * math.pi / 180.0;

    final y = math.sin(longitudeDifference) * math.cos(endLatitude);

    final x =
        (math.cos(startLatitude) * math.sin(endLatitude)) -
            (math.sin(startLatitude) *
                math.cos(endLatitude) *
                math.cos(longitudeDifference));

    final heading = math.atan2(y, x) * 180.0 / math.pi;

    return (heading + 360.0) % 360.0;
  }

  Future<void> _clearRouteDecorations({
    bool keepDestination = false,
  }) async {
    if (_mapController == null) return;

    for (final symbol in _turnSymbols) {
      await _mapController!.removeSymbol(symbol);
    }
    _turnSymbols.clear();

    for (final line in _turnLines) {
      await _mapController!.removeLine(line);
    }
    _turnLines.clear();

    if (!keepDestination && _destinationSymbol != null) {
      await _mapController!.removeSymbol(_destinationSymbol!);
      _destinationSymbol = null;
    }
  }

  void _navigationControllerChanged() {
    if (!mounted ||
        !_mapStyleReady ||
        _mapController == null ||
        !_navigationStarted) {
      return;
    }

    final navigationController =
        Provider.of<NavigationController>(context, listen: false);

    if (navigationController.routeVersion == _lastRouteVersion ||
        navigationController.currentRoutePoints.isEmpty) {
      return;
    }

    _lastRouteVersion = navigationController.routeVersion;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _mapController == null) return;

      await _drawRoute(navigationController.currentRoutePoints);
      await _drawRouteDecorations(navigationController);
    });
  }

  LatLng _getOffsetTarget(LatLng driverLoc, double bearing, double distanceInMeters) {
    const double earthRadius = 6371000.0;
    final double radBearing = bearing * (math.pi / 180.0);
    final double latRad = driverLoc.latitude * (math.pi / 180.0);
    final double lngRad = driverLoc.longitude * (math.pi / 180.0);

    final double angularDistance = distanceInMeters / earthRadius;

    final double targetLatRad = math.asin(
      math.sin(latRad) * math.cos(angularDistance) +
          math.cos(latRad) * math.sin(angularDistance) * math.cos(radBearing),
    );

    final double targetLngRad = lngRad +
        math.atan2(
          math.sin(radBearing) * math.sin(angularDistance) * math.cos(latRad),
          math.cos(angularDistance) - math.sin(latRad) * math.sin(targetLatRad),
        );

    return LatLng(
      targetLatRad * (180.0 / math.pi),
      targetLngRad * (180.0 / math.pi),
    );
  }

  Future<void> _updateDriverMarker(
    LatLng location, {
    required double heading,
    required bool moveCamera,
  }) async {
    if (!_mapStyleReady || !_iconsAdded || _mapController == null) {
      return;
    }

    final options = SymbolOptions(
      geometry: location,
      iconImage: _driverIconName,
      iconSize: 0.58,
      iconRotate: heading,
    );

    if (_driverSymbol == null) {
      _driverSymbol = await _mapController!.addSymbol(options);
    } else {
      await _mapController!.updateSymbol(
        _driverSymbol!,
        options,
      );
    }

    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);

    if (!moveCamera) return;

    await _moveCameraToDriver(
      location,
      heading: heading,
    );
  }

  Future<void> _moveCameraToDriver(
    LatLng location, {
    required double heading,
  }) async {
    if (_mapController == null) return;

    _isProgrammaticCameraMove = true;

    try {
      final LatLng offsetTarget = _getOffsetTarget(location, heading, 115.0);

      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: offsetTarget,
            zoom: 17.6,
            bearing: heading,
            tilt: 58.0,
          ),
        ),
        duration: const Duration(milliseconds: 500),
      );

      await _mapController!.setSymbolIconAllowOverlap(true);
      await _mapController!.setSymbolIconIgnorePlacement(true);
    } finally {
      Future.delayed(
        const Duration(milliseconds: 600),
        () {
          if (mounted) {
            _isProgrammaticCameraMove = false;
          }
        },
      );
    }
  }

  Future<void> _moveCameraToLocation(
    LatLng location, {
    required double zoom,
    required double tilt,
  }) async {
    if (_mapController == null) return;

    _isProgrammaticCameraMove = true;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: zoom,
            tilt: tilt,
          ),
        ),
        duration: const Duration(milliseconds: 600),
      );
    } finally {
      Future.delayed(
        const Duration(milliseconds: 750),
        () {
          if (mounted) {
            _isProgrammaticCameraMove = false;
          }
        },
      );
    }
  }

  Future<void> _showFullRoute() async {
    if (_mapController == null) return;

    final navigationController =
        Provider.of<NavigationController>(context, listen: false);

    final points = navigationController.currentRoutePoints;

    if (points.length < 2) return;

    setState(() {
      _cameraFollowing = false;
    });

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        _boundsFromPoints(points),
        left: 54.0,
        top: 160.0,
        right: 54.0,
        bottom: 180.0,
      ),
      duration: const Duration(milliseconds: 700),
    );
  }

  Future<void> _goToStart() async {
    setState(() {
      _cameraFollowing = false;
    });

    await _moveCameraToLocation(
      _startLocation,
      zoom: 17.0,
      tilt: 35.0,
    );
  }

  Future<void> _followDriver() async {
    final navigationController =
        Provider.of<NavigationController>(context, listen: false);

    final location =
        navigationController.snappedDriverLocation ?? _startLocation;

    setState(() {
      _cameraFollowing = true;
    });

    await _moveCameraToDriver(
      location,
      heading: navigationController.driverRouteBearing,
    );
  }

  Future<void> _resetToNorth() async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.bearingTo(0.0),
      duration: const Duration(milliseconds: 500),
    );
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _stopNavigation() async {
    final navigationController =
        Provider.of<NavigationController>(context, listen: false);

    navigationController.stopNavigation();

    if (_mapController != null) {
      await _mapController!.clearLines();
      await _clearRouteDecorations();

      if (_driverSymbol != null) {
        await _mapController!.removeSymbol(_driverSymbol!);
        _driverSymbol = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _navigationStarted = false;
      _cameraFollowing = false;
      _selectedPlace = null;
      _selectedDestination = null;
    });

    await _showCurrentLocationMarker(moveCamera: false);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _pulseController
      ..removeListener(_updateCurrentLocationPulse)
      ..dispose();

    _positionStream?.cancel();

    final navigationController =
        Provider.of<NavigationController>(context, listen: false);

    if (_controllerListenerAdded) {
      navigationController.removeListener(_navigationControllerChanged);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapLongClick: (point, coordinates) {
              if (!_navigationStarted) {
                _selectDestinationFromMap(coordinates);
              }
            },
            onCameraIdle: () {
              if (!_isProgrammaticCameraMove && mounted) {
                setState(() {
                  _cameraFollowing = false;
                });
              }
            },
            styleString: _currentMapStyle, // 👈 متصل به متد هوشمند تم روز/شب
            initialCameraPosition: CameraPosition(
              target: _startLocation,
              zoom: 16.0,
            ),
            trackCameraPosition: true,
          ),

          if (_isLoadingLocation)
            Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Card(
                    color: AppColors.cardBackground,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        'getting_your_location'.tr(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (!_navigationStarted)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.buttonText,
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 20,
                  ),
                  label: Text(
                    'driver_registration'.tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            right: 16,
            bottom: _navigationStarted ? 140 : 260,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapActionButton(
                    icon: Icons.navigation_rounded,
                    tooltip: 'align_to_north'.tr(),
                    iconColor: Colors.redAccent,
                    onPressed: _resetToNorth,
                  ),
                  const SizedBox(height: 10),
                  if (_navigationStarted) ...[
                    _MapActionButton(
                      icon: Icons.alt_route_rounded,
                      tooltip: 'show_full_route'.tr(),
                      onPressed: _showFullRoute,
                    ),
                    const SizedBox(height: 10),
                    _MapActionButton(
                      icon: Icons.home_outlined,
                      tooltip: 'back_to_start'.tr(),
                      onPressed: _goToStart,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _MapActionButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'my_location'.tr(),
                    iconColor: AppColors.primaryButton,
                    onPressed: () async {
                      if (_navigationStarted) {
                        _followDriver();
                      } else {
                        if (_mapController != null) {
                          await _mapController!.updateMyLocationTrackingMode(
                            MyLocationTrackingMode.tracking,
                          );
                        }
                        if (_currentLocation != null) {
                          _moveCameraToLocation(
                            _currentLocation!,
                            zoom: 16.5,
                            tilt: 35.0,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          if (_navigationStarted && !_cameraFollowing)
            Positioned(
              left: 20,
              right: 20,
              bottom: 135,
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _followDriver,
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text('return_to_route'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.buttonText,
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),

          Consumer<NavigationController>(
            builder: (context, controller, child) {
              if (!_navigationStarted || !controller.isNavigating) {
                return const SizedBox.shrink();
              }

              return Positioned(
                top: 18,
                left: 68,
                right: 16,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBrand,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          controller.currentTurnIcon,
                          color: AppColors.buttonText,
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${controller.distanceToNextTurn} ${'meters'.tr()}',
                                style: const TextStyle(
                                  color: AppColors.buttonText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                controller.navigationInstruction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.buttonText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: controller.toggleVoice,
                          icon: Icon(
                            controller.isVoiceEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: AppColors.buttonText,
                          ),
                        ),
                        IconButton(
                          onPressed: _stopNavigation,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.buttonText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          if (_navigationStarted)
            Consumer<NavigationController>(
              builder: (context, controller, child) {
                if (!controller.isNavigating) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Card(
                      color: Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'route_guide'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${controller.distanceToNextTurn} ${'meters'.tr()}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    controller.navigationInstruction.isEmpty
                                        ? 'route_preparing'.tr()
                                        : controller.navigationInstruction,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primaryButton,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: AppColors.buttonText,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _stopNavigation,
                              child: Text(
                                'end_trip'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          if (!_navigationStarted)
            DestinationSearchSheet(
              selectedPlace: _selectedPlace,
              onPlaceSelected: _onPlaceSelected,
              onConfirmDestination: _confirmDestination,
            ),
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: iconColor ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}
