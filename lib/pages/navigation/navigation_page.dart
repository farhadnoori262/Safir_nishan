import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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

import 'navigation_route_style.dart';
import 'widgets/navigation_bottom_panel.dart';
import 'widgets/navigation_controls.dart';
import 'widgets/navigation_driver_marker.dart';
import 'widgets/navigation_route_arrow.dart';
import 'widgets/navigation_turn_banner.dart';

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
  static const String _destinationIconName = 'safir-destination-pin';
  static const String _currentLocationIconName = 'safir-current-location-pulse';
  static const LatLng _fallbackLocation = LatLng(34.5553, 69.2075);

  MapLibreMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  Symbol? _currentLocationSymbol;
  Symbol? _destinationSymbol;

  final List<Symbol> _turnSymbols = [];
  final List<Line> _turnLines = [];

  PlaceSearchResult? _selectedPlace;
  LatLng? _selectedDestination;
  LatLng? _currentLocation;
  double _currentAccuracy = 5.0;

  double _driverHeading = 0.0;
  double _currentMapBearing = 0.0;

  double _smoothedHeading = 0.0;
  bool _headingInitialized = false;

  late final AnimationController _pulseController;

  bool _mapStyleReady = false;
  bool _iconsAdded = false;
  bool _navigationStarted = false;
  bool _controllerListenerAdded = false;
  bool _cameraFollowing = false;
  bool _isUpdatingMap = false;
  bool _isProgrammaticCameraMove = false;
  bool _isLoadingLocation = true;
  bool _isMapDragging = false; // جهت کنترل انیمیشن پرش پین وسط نقشه

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
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoadingLocation) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    });

    _startLocationTracking();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;

    _mapStyleReady = true;
    final navigationController = Provider.of<NavigationController>(context, listen: false);

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
    if (!widget.isDriverTrip || widget.dropoffLocation == null || _navigationStarted) {
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
      final rawLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLocation = rawLocation;
          _currentAccuracy = position.accuracy.clamp(2.0, 10.0);
        });
      }

      final navigationController = Provider.of<NavigationController>(context, listen: false);

      if (_navigationStarted && navigationController.isNavigating) {
        navigationController.updateDriverPosition(
          rawLocation,
          langCode: context.locale.languageCode,
        );

        final driverLocation = navigationController.snappedDriverLocation ?? rawLocation;

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
      _currentLocationIconName,
      (canvas, size) => NavigationMapPainters.drawCurrentLocationPulse(
        canvas,
        size,
        _pulseController.value,
        _currentAccuracy,
      ),
      width: 120,
      height: 120,
    );

    await NavigationMapPainters.addCanvasImage(
      _mapController!,
      _destinationIconName,
      NavigationMapPainters.drawDestinationPin,
      width: 120,
      height: 140, // بزرگ‌تر کردن کانواس پین مقصد
    );

    await NavigationMapPainters.addCanvasImage(
      _mapController!,
      NavigationRouteArrow.leftTurnIconName,
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
      NavigationRouteArrow.rightTurnIconName,
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
      NavigationRouteArrow.straightIconName,
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
      NavigationRouteArrow.uTurnIconName,
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

  Future<void> _onPlaceSelected(PlaceSearchResult place) async {
    if (!mounted) return;

    setState(() {
      _selectedPlace = place;
      _selectedDestination = LatLng(place.latitude, place.longitude);
    });

    await _showSelectedDestinationMarker(moveCamera: true);
  }

  Future<void> _selectDestinationFromMap(LatLng coordinates) async {
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
      if (mounted) _showMessage('address_not_found'.tr());
      return;
    }

    await _onPlaceSelected(realPlace);
  }

  Future<void> _showSelectedDestinationMarker({required bool moveCamera}) async {
    if (!_mapStyleReady || !_iconsAdded || _mapController == null || _selectedDestination == null) {
      return;
    }

    final options = SymbolOptions(
      geometry: _selectedDestination!,
      iconImage: _destinationIconName,
      iconSize: 1.10, // بزرگ‌سازی مقیاس آیکون پین
    );

    if (_destinationSymbol == null) {
      _destinationSymbol = await _mapController!.addSymbol(options);
    } else {
      await _mapController!.updateSymbol(_destinationSymbol!, options);
    }

    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);

    if (!moveCamera) return;

    _isProgrammaticCameraMove = true;
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedDestination!, zoom: 16.5),
        ),
        duration: const Duration(milliseconds: 550),
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _isProgrammaticCameraMove = false;
      });
    }
  }

  Future<void> _showCurrentLocationMarker({required bool moveCamera}) async {
    if (!_mapStyleReady || !_iconsAdded || _mapController == null || _currentLocation == null || _navigationStarted) {
      return;
    }

    final options = SymbolOptions(
      geometry: _currentLocation!,
      iconImage: _currentLocationIconName,
      iconSize: 0.75,
    );

    if (_currentLocationSymbol == null) {
      _currentLocationSymbol = await _mapController!.addSymbol(options);
    } else {
      await _mapController!.updateSymbol(_currentLocationSymbol!, options);
    }

    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);

    if (!moveCamera) return;

    await _moveCameraToLocation(_currentLocation!, zoom: 16.5, tilt: 35.0);
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
    if (!_mapStyleReady || _mapController == null || _selectedDestination == null || _navigationStarted) {
      return;
    }

    _headingInitialized = false;

    setState(() {
      _navigationStarted = true;
      _cameraFollowing = true;
    });

    final navigationController = Provider.of<NavigationController>(context, listen: false);

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

    await NavigationRouteStyle.drawRoute(_mapController!, routePoints);
    await _drawRouteDecorations(navigationController);

    await _updateDriverMarker(
      navigationController.snappedDriverLocation ?? _startLocation,
      heading: navigationController.driverRouteBearing,
      moveCamera: true,
    );
  }

  Future<void> _drawRouteDecorations(NavigationController navigationController) async {
    if (_mapController == null || _selectedDestination == null) return;

    await _clearRouteDecorations(keepDestination: true);

    if (_destinationSymbol == null) {
      _destinationSymbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: _selectedDestination!,
          iconImage: _destinationIconName,
          iconSize: 1.10,
        ),
      );
    }

    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);

    await NavigationRouteArrow.drawDecorations(
      controller: _mapController!,
      navigationController: navigationController,
      turnSymbols: _turnSymbols,
    );
  }

  Future<void> _clearRouteDecorations({bool keepDestination = false}) async {
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
    if (!mounted || !_mapStyleReady || _mapController == null || !_navigationStarted) {
      return;
    }

    final navigationController = Provider.of<NavigationController>(context, listen: false);

    if (navigationController.routeVersion == _lastRouteVersion || navigationController.currentRoutePoints.isEmpty) {
      return;
    }

    _lastRouteVersion = navigationController.routeVersion;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _mapController == null) return;
      await NavigationRouteStyle.drawRoute(_mapController!, navigationController.currentRoutePoints);
      await _drawRouteDecorations(navigationController);
    });
  }

  double _shortestAngleDiff(double from, double to) {
    double diff = (to - from) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return diff;
  }

  double _smoothHeadingUpdate(double targetHeading) {
    if (!_headingInitialized) {
      _headingInitialized = true;
      _smoothedHeading = targetHeading;
      return _smoothedHeading;
    }

    const double smoothingFactor = 0.35;
    final diff = _shortestAngleDiff(_smoothedHeading, targetHeading);
    _smoothedHeading = (_smoothedHeading + (diff * smoothingFactor) + 360.0) % 360.0;

    return _smoothedHeading;
  }

  Future<void> _updateDriverMarker(
    LatLng location, {
    required double heading,
    required bool moveCamera,
  }) async {
    if (!mounted) return;

    final smoothed = _smoothHeadingUpdate(heading);

    setState(() {
      _driverHeading = smoothed;
    });

    if (!moveCamera) return;
    await _moveCameraToDriver(location, heading: smoothed);
  }

  Future<void> _moveCameraToDriver(LatLng location, {required double heading}) async {
    if (_mapController == null) return;
    _isProgrammaticCameraMove = true;

    try {
      final LatLng offsetTarget = NavigationDriverMarker.getOffsetTarget(location, heading, 115.0);

      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: offsetTarget,
            zoom: 17.6,
            bearing: heading,
            tilt: 58.0,
          ),
        ),
        duration: const Duration(milliseconds: 450),
      );

      if (mounted) {
        setState(() {
          _currentMapBearing = heading;
        });
      }

      await _mapController!.setSymbolIconAllowOverlap(true);
      await _mapController!.setSymbolIconIgnorePlacement(true);
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _isProgrammaticCameraMove = false;
      });
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
          CameraPosition(target: location, zoom: zoom, tilt: tilt),
        ),
        duration: const Duration(milliseconds: 600),
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) _isProgrammaticCameraMove = false;
      });
    }
  }

  Future<void> _showFullRoute() async {
    if (_mapController == null) return;
    final navigationController = Provider.of<NavigationController>(context, listen: false);
    final points = navigationController.currentRoutePoints;

    if (points.length < 2) return;

    setState(() => _cameraFollowing = false);

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
    setState(() => _cameraFollowing = false);
    await _moveCameraToLocation(_startLocation, zoom: 17.0, tilt: 35.0);
  }

  Future<void> _followDriver() async {
    final navigationController = Provider.of<NavigationController>(context, listen: false);
    final location = navigationController.snappedDriverLocation ?? _startLocation;

    final smoothed = _smoothHeadingUpdate(navigationController.driverRouteBearing);

    setState(() {
      _cameraFollowing = true;
      _driverHeading = smoothed;
    });

    await _moveCameraToDriver(
      location,
      heading: smoothed,
    );
  }

  Future<void> _resetToNorth() async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.bearingTo(0.0),
      duration: const Duration(milliseconds: 500),
    );

    if (mounted) {
      setState(() {
        _currentMapBearing = 0.0;
      });
    }
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
    final navigationController = Provider.of<NavigationController>(context, listen: false);
    navigationController.stopNavigation();

    if (_mapController != null) {
      await _mapController!.clearLines();
      await _clearRouteDecorations();
    }

    if (!mounted) return;

    _headingInitialized = false;

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _pulseController
      ..removeListener(_updateCurrentLocationPulse)
      ..dispose();
    _positionStream?.cancel();

    final navigationController = Provider.of<NavigationController>(context, listen: false);
    if (_controllerListenerAdded) {
      navigationController.removeListener(_navigationControllerChanged);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
            onCameraMove: () {
              if (!_isProgrammaticCameraMove && !_navigationStarted) {
                setState(() => _isMapDragging = true);
              }
            },
            onCameraIdle: () {
              if (!_isProgrammaticCameraMove && mounted) {
                setState(() {
                  _cameraFollowing = false;
                  _isMapDragging = false;
                });
                
                // به‌روزرسانی اتوماتیک موقعیت مرکز نقشه در صورت نبود مقصد انتخاب شده
                if (!_navigationStarted && _selectedDestination == null && _mapController != null) {
                  final target = _mapController!.cameraPosition?.target;
                  if (target != null) {
                    _selectDestinationFromMap(target);
                  }
                }
              }
            },
            styleString: NavigationRouteStyle.currentMapStyle,
            initialCameraPosition: CameraPosition(
              target: _startLocation,
              zoom: 16.0,
            ),
            myLocationEnabled: false,
            trackCameraPosition: true,
          ),

          // ویجت پین مرکز نقشه (اصلی و انیمیشن‌دار)
          if (!_navigationStarted && _selectedDestination == null)
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 35),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: Matrix4.translationValues(
                        0, _isMapDragging ? -12 : 0, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SafirColors.primaryBrand,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                    _isMapDragging ? 0.35 : 0.18),
                                blurRadius: _isMapDragging ? 12 : 6,
                                offset: Offset(0, _isMapDragging ? 8 : 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isMapDragging ? 12 : 6,
                          height: _isMapDragging ? 4 : 3,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_navigationStarted)
            IgnorePointer(
              child: Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.62,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: (_driverHeading - _currentMapBearing) * math.pi / 180.0,
                      end: (_driverHeading - _currentMapBearing) * math.pi / 180.0,
                    ),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, angle, child) {
                      return Transform.rotate(
                        angle: angle,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/navigation_arrow.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
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
                        style: const TextStyle(color: AppColors.textPrimary),
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
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
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

          NavigationControls(
            navigationStarted: _navigationStarted,
            onResetToNorth: _resetToNorth,
            onShowFullRoute: _showFullRoute,
            onGoToStart: _goToStart,
            onFollowLocation: () async {
              if (_navigationStarted) {
                _followDriver();
              } else {
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
              return NavigationTurnBanner(
                controller: controller,
                onStopNavigation: _stopNavigation,
              );
            },
          ),

          if (_navigationStarted)
            Consumer<NavigationController>(
              builder: (context, controller, child) {
                if (!controller.isNavigating) {
                  return const SizedBox.shrink();
                }
                return NavigationBottomPanel(
                  controller: controller,
                  onStopNavigation: _stopNavigation,
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
