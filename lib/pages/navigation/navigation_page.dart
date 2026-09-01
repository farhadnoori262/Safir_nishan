import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

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
import 'widgets/navigation_route_arrow.dart';
import 'widgets/navigation_turn_banner.dart';

/// نتیجهٔ پروجکشن موقعیت خام GPS روی نزدیک‌ترین بخش از خط مسیر.
/// point: نقطهٔ چسبیده‌شده به جادّه (snapped).
/// bearing: راستای واقعی همان بخش از جادّه (بر حسب درجه، نسبت به شمال).
class _RouteProjection {
  final LatLng point;
  final double bearing;
  const _RouteProjection(this.point, this.bearing);
}

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

class _NavigationPageState extends State<NavigationPage> {
  static const String _destinationIconName = 'safir-destination-pin';
  static const String _driverDotIconName = 'safir-driver-dot';
  static const String _driverArrowIconName = 'safir-driver-arrow';
  static const LatLng _fallbackLocation = LatLng(34.5553, 69.2075);

  MapLibreMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  Symbol? _destinationSymbol;
  Symbol? _driverSymbol;

  final List<Symbol> _turnSymbols = [];
  final List<Line> _turnLines = [];

  PlaceSearchResult? _selectedPlace;
  LatLng? _selectedDestination;
  LatLng? _currentLocation;

  // موقعیت و جهتِ چسبیده‌شده به جادّه (منبع واحد حقیقت برای مارکر و دوربین)
  LatLng? _snappedDriverLocation;
  double _driverBearing = 0.0;

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
    // پین نیتیو دیگر استفاده نمی‌شود؛ مارکر راننده کاملاً دستی مدیریت می‌شود.
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

    if (_selectedDestination != null) {
      await _showSelectedDestinationMarker(moveCamera: false);
    }

    // نمایش اولیهٔ نقطهٔ دایره‌ای (حالت idle) به محض آماده‌شدن نقشه
    if (_currentLocation != null) {
      await _updateDriverMarker(_currentLocation!, navigating: false);
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
        });
      }

      final navigationController = Provider.of<NavigationController>(context, listen: false);

      if (_navigationStarted && navigationController.isNavigating) {
        // به کنترلر هم خبر می‌دهیم (برای ETA، بنر گردش، و غیره)
        navigationController.updateDriverPosition(
          rawLocation,
          langCode: context.locale.languageCode,
        );

        final routePoints = navigationController.currentRoutePoints;

        LatLng lockedLocation = rawLocation;
        double lockedBearing = _driverBearing;

        if (routePoints.length >= 2) {
          final projection = _projectOntoRoute(rawLocation, routePoints);
          if (projection != null) {
            lockedLocation = projection.point;
            lockedBearing = projection.bearing;


          }
        }

        _snappedDriverLocation = lockedLocation;
        _driverBearing = lockedBearing;

        await _updateDriverMarker(
          lockedLocation,
          navigating: true,
          rotate: lockedBearing,
        );

        if (_cameraFollowing) {
          await _moveCameraToDriver(lockedLocation, heading: lockedBearing);
        }
      } else {
        // قبل از شروع ناوبری: فقط دایرهٔ ساده روی مکان خام GPS
        await _updateDriverMarker(rawLocation, navigating: false);
      }
    } finally {
      _isUpdatingMap = false;
    }
  }

  // ---------------------------------------------------------------------
  // منطق Snap-to-Route (چسباندن موقعیت خام GPS به نزدیک‌ترین نقطهٔ مسیر)
  // ---------------------------------------------------------------------

  _RouteProjection? _projectOntoRoute(LatLng gps, List<LatLng> route) {
    if (route.length < 2) return null;

    double bestDistanceMeters = double.infinity;
    LatLng bestPoint = route.first;
    double bestBearing = _driverBearing;

    for (int i = 0; i < route.length - 1; i++) {
      final segmentStart = route[i];
      final segmentEnd = route[i + 1];

      final projected = _closestPointOnSegment(gps, segmentStart, segmentEnd);
      final distanceMeters = _approxDistanceMeters(gps, projected);

      if (distanceMeters < bestDistanceMeters) {
        bestDistanceMeters = distanceMeters;
        bestPoint = projected;
        bestBearing = _bearingBetween(segmentStart, segmentEnd);
      }
    }

    return _RouteProjection(bestPoint, bestBearing);
  }

  /// نزدیک‌ترین نقطه روی پارهٔ خط [a]-[b] به نقطهٔ [p]
  /// (با تصویر تخت/planar محلی بر حسب متر، دقت کافی برای فاصله‌های شهری).
  LatLng _closestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final latRefRad = a.latitude * math.pi / 180.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(latRefRad);

    final ax = 0.0;
    final ay = 0.0;
    final bx = (b.longitude - a.longitude) * metersPerDegLng;
    final by = (b.latitude - a.latitude) * metersPerDegLat;
    final px = (p.longitude - a.longitude) * metersPerDegLng;
    final py = (p.latitude - a.latitude) * metersPerDegLat;

    final dx = bx - ax;
    final dy = by - ay;
    final lengthSq = dx * dx + dy * dy;

    double t = lengthSq == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);

    final projX = ax + t * dx;
    final projY = ay + t * dy;

    final lng = a.longitude + projX / metersPerDegLng;
    final lat = a.latitude + projY / metersPerDegLat;

    return LatLng(lat, lng);
  }

  double _approxDistanceMeters(LatLng p, LatLng q) {
    final latRefRad = p.latitude * math.pi / 180.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(latRefRad);

    final dx = (q.longitude - p.longitude) * metersPerDegLng;
    final dy = (q.latitude - p.latitude) * metersPerDegLat;

    return math.sqrt(dx * dx + dy * dy);
  }

  /// راستای واقعی (bearing) از نقطهٔ a به b، بر حسب درجه نسبت به شمال.
  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final bearingRad = math.atan2(y, x);
    final bearingDeg = bearingRad * 180.0 / math.pi;

    return (bearingDeg + 360.0) % 360.0;
  }

  // ---------------------------------------------------------------------
  // ساخت آیکن‌های مارکر راننده (دایره برای idle، فلش برای navigating)
  // ---------------------------------------------------------------------

  Future<Uint8List> _renderIconBytes(
    void Function(Canvas canvas, Size size) painter,
    Size size,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
    painter(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _paintDriverDot(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 2;
    final innerRadius = outerRadius * 0.62;

    canvas.drawCircle(center, outerRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()..color = const Color(0xFF1E88E5),
    );
  }

  void _paintDriverArrow(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // فلش رو به بالا (نوک بالا، فرورفتگی در پایین وسط)
    final path = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.86, h * 0.88)
      ..lineTo(w * 0.50, h * 0.66)
      ..lineTo(w * 0.14, h * 0.88)
      ..close();

    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outline);

    final fill = Paint()..color = const Color(0xFF1E88E5);
    canvas.drawPath(path, fill);
  }

  Future<void> _addMapImages() async {
    if (_mapController == null || _iconsAdded) return;

    await NavigationMapPainters.addCanvasImage(
      _mapController!,
      _destinationIconName,
      NavigationMapPainters.drawDestinationPin,
      width: 100,
      height: 124,
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

    // آیکن‌های مارکر راننده (دایره idle + فلش navigating)
    final dotBytes = await _renderIconBytes(_paintDriverDot, const Size(46, 46));
    await _mapController!.addImage(_driverDotIconName, dotBytes);

    final ByteData bytes = await rootBundle.load('assets/images/navigation_arrow.png');
final Uint8List arrowBytes = bytes.buffer.asUint8List();
await _mapController!.addImage(_driverArrowIconName, arrowBytes);

    _iconsAdded = true;
  }

  /// آپدیت/ایجاد مارکر واحد راننده. همیشه همین یک Symbol را جابه‌جا و
  /// آیکن/زاویه‌اش را عوض می‌کنیم؛ هرگز Symbol جدید اضافه نمی‌شود
  /// (تا از چشمک‌زدن/پرش جلوگیری شود).
  Future<void> _updateDriverMarker(
  LatLng position, {
  required bool navigating,
  double rotate = 0,
}) async {
  if (_mapController == null || !_iconsAdded) return;

  // محاسبه اندازه فلش متناسب با زوم نقشه
  double dynamicSize = 0.85;
  if (navigating) {
    final currentZoom = _mapController!.zoomLevel;
    dynamicSize = (math.pow(2, currentZoom - 18.0) * 0.85).clamp(0.25, 1.3);
  }

  final options = SymbolOptions(
    geometry: position,
    iconImage: navigating ? _driverArrowIconName : _driverDotIconName,
    iconRotate: 0, // فلش همیشه رو به بالا ثابت می‌ماند
    iconAnchor: "center",
    iconSize: dynamicSize,
    iconRotationAlignment: "viewport",
    iconPitchAlignment: "viewport",
  );

  if (_driverSymbol == null) {
    _driverSymbol = await _mapController!.addSymbol(options);
    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);
  } else {
    await _mapController!.updateSymbol(_driverSymbol!, options);
  }
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
      iconSize: 0.70,
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

    await NavigationRouteStyle.drawRoute(_mapController!, routePoints);
    await _drawRouteDecorations(navigationController);

    // --- نقطهٔ کلیدی رفع باگ ---
    // به‌جای اتکا به مقدار GPS خام (که ممکن است هنوز داخل خانه باشد)،
    // بلافاصله مارکر را روی خودِ نوک ابتدای خط مسیر (که همیشه روی جادّه است)
    // قرار می‌دهیم؛ جهت اولیه هم از همان بخش اول مسیر گرفته می‌شود.
    final initialBearing = routePoints.length >= 2
    ? (_bearingBetween(routePoints[0], routePoints[1]) + 180.0) % 360.0
: (navigationController.driverRouteBearing + 180.0) % 360.0;



    final initialLocation = routePoints.first;

    _snappedDriverLocation = initialLocation;
    _driverBearing = initialBearing;

    await _updateDriverMarker(
      initialLocation,
      navigating: true,
      rotate: initialBearing,
    );

    await _moveCameraToDriver(initialLocation, heading: initialBearing);
  }

  Future<void> _drawRouteDecorations(NavigationController navigationController) async {
    if (_mapController == null || _selectedDestination == null) return;

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

  Future<void> _moveCameraToDriver(LatLng location, {required double heading}) async {
  if (_mapController == null) return;
  _isProgrammaticCameraMove = true;

  try {
    // قفل کردن نقطه تمرکز دوربین در ۳۵٪ پایینی صفحه
    await _mapController!.updateContentInsets(
      EdgeInsets.only(
        top: 0,
        bottom: MediaQuery.of(context).size.height * 0.35,
        left: 0,
        right: 0,
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 18.0,
          bearing: heading,
          tilt: 55.0,
        ),
      ),
      duration: const Duration(milliseconds: 400),
    );
  } catch (_) {
  } finally {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _isProgrammaticCameraMove = false;
    });
  }
}


    await _mapController!.updateContentInsets(
  EdgeInsets.only(
    top: 0,
    bottom: MediaQuery.of(context).size.height * 0.35,
    left: 0,
    right: 0,
  ),
);

  } catch (_) {
  } finally {
    Future.delayed(const Duration(milliseconds: 600), () {
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
    final location = _snappedDriverLocation ?? _startLocation;

    setState(() => _cameraFollowing = true);

    await _moveCameraToDriver(location, heading: _driverBearing);
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
    final navigationController = Provider.of<NavigationController>(context, listen: false);
    navigationController.stopNavigation();

    if (_mapController != null) {
      await _mapController!.clearLines();
      await _clearRouteDecorations();

      // بازگشت مارکر راننده به حالت دایرهٔ ساده (idle)
      final fallback = _currentLocation ?? _startLocation;
      _snappedDriverLocation = null;
      await _updateDriverMarker(fallback, navigating: false);
    }

    if (!mounted) return;

    setState(() {
      _navigationStarted = false;
      _cameraFollowing = false;
      _selectedPlace = null;
      _selectedDestination = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _positionStream?.cancel();

    final navigationController = Provider.of<NavigationController>(context, listen: false);
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
            // پین نیتیو خاموش است؛ مارکر راننده به‌طور کامل دستی (Symbol سفارشی) مدیریت می‌شود
            myLocationEnabled: false,
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
            styleString: NavigationRouteStyle.currentMapStyle,
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
                  await _moveCameraToLocation(
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
