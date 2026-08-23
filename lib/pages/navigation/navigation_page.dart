import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../controllers/navigation_controller.dart';
import '../../models/place_search_result.dart';
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

    _startLocationTracking();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
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
        title: 'مقصد مسافر',
        address: 'مسیریابی هوشمند سفیر',
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
        _showMessage('لطفاً موقعیت مکانی گوشی را روشن کنید.');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('اجازهٔ دسترسی به موقعیت مکانی داده نشد.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      await _handleLocationUpdate(position);

      await _positionStream?.cancel();

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).listen(
        (position) async {
          await _handleLocationUpdate(position);
        },
      );
    } catch (_) {
      _showMessage('دریافت موقعیت فعلی امکان‌پذیر نشد.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
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

  Future<void> _addMapImages() async {
    if (_mapController == null || _iconsAdded) return;

    await NavigationMapPainters.addCanvasImage(
      _mapController!,
      _driverIconName,
      NavigationMapPainters.drawDriverArrow,
      width: 120,
      height: 120,
    );

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
      title: 'در حال دریافت آدرس...',
      address: 'لطفاً چند لحظه صبر کنید.',
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
        _showMessage('آدرس این نقطه پیدا نشد؛ مقصد همچنان قابل استفاده است.');
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
      _showMessage('ابتدا مقصد را انتخاب کنید.');
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

      _showMessage('مسیر قابل دریافت نیست. اتصال اینترنت را بررسی کنید.');
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

    await _mapController!.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#005F73',
        lineWidth: 14.0,
        lineOpacity: 0.90,
      ),
    );

    await _mapController!.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#00E5FF',
        lineWidth: 8.0,
        lineOpacity: 0.60,
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

    for (var index = 0;
        index < navigationController.routeSteps.length;
        index++) {
      final step = navigationController.routeSteps[index];

      if (step.distance < 18) continue;
      if (index == 0 && step.modifier == 'straight') continue;

      final symbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: step.location,
          iconImage: _turnIconName(step.modifier),
          iconSize: 0.44,
          iconRotate: _routeBearingAt(
            step.location,
            navigationController.currentRoutePoints,
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
            textHaloColor: '#005F73',
            textHaloWidth: 2.0,
            textOffset: const Offset(0, -2.0),
          ),
        );

        _turnSymbols.add(labelSymbol);
      }
    }
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
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 17.5,
            bearing: heading,
            tilt: 50.0,
          ),
        ),
        duration: const Duration(milliseconds: 650),
      );
    } finally {
      Future.delayed(
        const Duration(milliseconds: 800),
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
            styleString: 'assets/map/style.json',
            initialCameraPosition: CameraPosition(
              target: _startLocation,
              zoom: 16.0,
            ),
            myLocationEnabled: false,
            trackCameraPosition: true,
          ),

          if (_isLoadingLocation)
            const Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text('در حال دریافت موقعیت شما...'),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 5,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'بازگشت',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: SafirColors.primary,
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
                    backgroundColor: SafirColors.primary,
                    foregroundColor: Colors.white,
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
                    _showMessage('انتقال به صفحه ثبت‌نام راننده');
                  },
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 20,
                  ),
                  label: const Text(
                    'ثبت‌نام راننده',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          if (_navigationStarted)
            Positioned(
              right: 16,
              bottom: 140,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapActionButton(
                      icon: Icons.navigation_rounded,
                      tooltip: 'تنظیم به سمت شمال',
                      iconColor: Colors.redAccent,
                      onPressed: _resetToNorth,
                    ),
                    const SizedBox(height: 10),
                    _MapActionButton(
                      icon: Icons.alt_route_rounded,
                      tooltip: 'نمایش کل مسیر',
                      onPressed: _showFullRoute,
                    ),
                    const SizedBox(height: 10),
                    _MapActionButton(
                      icon: Icons.home_outlined,
                      tooltip: 'بازگشت به مبدا',
                      onPressed: _goToStart,
                    ),
                    const SizedBox(height: 10),
                    _MapActionButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'بازگشت به مسیر',
                      iconColor: SafirColors.primary,
                      onPressed: _followDriver,
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
                  label: const Text('بازگشت به مسیر'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SafirColors.primary,
                    foregroundColor: Colors.white,
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
                      color: SafirColors.primary,
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
                          color: Colors.white,
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
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                controller.navigationInstruction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
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
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: _stopNavigation,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
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
                                  const Text(
                                    'راهنمای مسیر',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${controller.distanceToNextTurn} ${'meters'.tr()}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    controller.navigationInstruction.isEmpty
                                        ? 'مسیر در حال آماده‌سازی است...'
                                        : controller.navigationInstruction,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.teal,
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
                                foregroundColor: Colors.white,
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
                              child: const Text(
                                'پایان سفر',
                                style: TextStyle(
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
          color: iconColor ?? Colors.black87,
        ),
      ),
    );
  }
}
