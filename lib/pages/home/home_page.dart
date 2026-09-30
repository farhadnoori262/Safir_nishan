import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/controllers/navigation_controller.dart';
import 'package:safir_drivers/pages/chat_page.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import '../../push_notifications/push_notification_system.dart';
import 'active_trip_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  MapLibreMapController? mapController;
  Symbol? _driverNavigationSymbol;
  bool _isDriverArrowImageAdded = false;
  bool _isMapStyleReady = false;
  bool _isNavArrowVisible = false;
  Position? currentPositionOfDriver;

  // ───────── حرکت آیکن روی مسیر (منطق MapScreenRoute) ─────────
  late AnimationController _arrowAnimationController;
  List<LatLng> _navRoutePoints = <LatLng>[];
  int _lastSyncedRouteVersion = -1; // نسخهٔ مسیرِ NavigationController
  int _navProgressIndex = 0; // پیشرفت روی مسیر (فقط به جلو)
  int _navLastRenderedSegment = -1;
  LatLng? _navLastRenderedPoint;
  Line? _navRemainingLine; // خط سبز (باقی‌ماندهٔ مسیر)
  Line? _navTraveledLine; // خط خاکستری (طی‌شده)

  Position? _pendingNavPosition;
  bool _isProcessingNavUpdate = false;

  LatLng? _arrowAnimStart;
  LatLng? _arrowAnimEnd;
  LatLng? _arrowDisplayLatLng; // موقعیت لحظه‌ایِ آیکن (وسط انیمیشن)
  LatLng? _arrowLastTarget;
  double _arrowAnimStartBearing = 0.0;
  double _arrowAnimEndBearing = 0.0;
  double _arrowDisplayBearing = 0.0;
  DateTime? _lastArrowUpdateAt;

  static const double _offRouteThresholdMeters = 50.0;

  // نوشتن لوکیشن در Firestore حداکثر هر ۲ ثانیه (با ارسال آخرین مقدار)
  static const Duration _locationWriteInterval = Duration(seconds: 2);
  DateTime? _lastLocationWriteAt;
  Timer? _locationWriteTimer;
  Position? _queuedLocation;

  bool isDriverAvailable = false;
  bool isLoading = false;

  String? activeTripId;
  String? activeTripStatus;

  DateTime? driverOnlineTimestamp;

  bool _isTripActionLoading = false;
  bool _isStartingRoute = false;
  bool _isDisposing = false;

  StreamSubscription<Position>? positionStreamHomePage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? tripRequestStream;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_animateNavArrow);
    _loadDriverStatus();
    initializePushNotificationSystem();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Provider.of<RegistrationProvider>(
        context,
        listen: false,
      ).retrieveCurrentDriverInfo();

      await getCurrentLiveLocationOfDriver();
    });
  }

  @override
  void dispose() {
    _isDisposing = true;
    positionStreamHomePage?.cancel();
    tripRequestStream?.cancel();
    _locationWriteTimer?.cancel();
    _arrowAnimationController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  Future<void> _centerMapOnDriver() async {
    if (mapController == null) return;

    final Position? livePosition = await getCurrentLiveLocationOfDriver();
    if (livePosition == null || mapController == null) return;

    LatLng target = LatLng(
      livePosition.latitude,
      livePosition.longitude,
    );

    if (mounted) {
      final NavigationController navController =
          context.read<NavigationController>();

      if (navController.isNavigating && _arrowLastTarget != null) {
        target = _arrowLastTarget!;
      }
    }

    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 17,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );
  }

  bool _isTripOwnedByCurrentDriver(Map<String, dynamic> tripData) {
    final String? currentDriverId = FirebaseAuth.instance.currentUser?.uid;
    if (currentDriverId == null) return false;

    final String tripDriverId = tripData['driver_id']?.toString() ??
        tripData['driverId']?.toString() ??
        '';

    return tripDriverId == currentDriverId;
  }

  LatLng? _extractLatLng(
    Map<String, dynamic> data,
    List<String> keys, {
    String? latKey,
    String? lngKey,
  }) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is GeoPoint) {
        return LatLng(value.latitude, value.longitude);
      }

      if (value is Map) {
        final double? lat = double.tryParse(
          value['latitude']?.toString() ?? value['lat']?.toString() ?? '',
        );

        final double? lng = double.tryParse(
          value['longitude']?.toString() ?? value['lng']?.toString() ?? '',
        );

        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    }

    if (latKey != null && lngKey != null) {
      final double? lat = double.tryParse(data[latKey]?.toString() ?? '');
      final double? lng = double.tryParse(data[lngKey]?.toString() ?? '');

      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    return null;
  }

  Future<void> _prepareDriverNavigationArrow() async {
    if (mapController == null || _isDriverArrowImageAdded) return;

    try {
      final ByteData imageData = await rootBundle.load(
        'assets/images/driver_navigation_arrow.png',
      );

      await mapController!.addImage(
        'driver_navigation_arrow',
        imageData.buffer.asUint8List(),
      );

      _isDriverArrowImageAdded = true;
    } catch (e) {
      debugPrint('Error preparing driver navigation arrow: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  🧭 حرکت آیکن راننده روی مسیر (منطق MapScreenRoute تست‌شده)
  //   • چسباندن به مسیر (≤ ۵۰ متر) و پیشروی فقط «به جلو»
  //   • حرکت خطی با مدتی برابر فاصلهٔ واقعی بین دو GPS
  //   • انیمیشن از موقعیت لحظه‌ایِ آیکن شروع می‌شود
  //   • زاویه از جهت حرکت (بیش از ۳ متر جابه‌جایی)
  //   • مسیر به طی‌شده (خاکستری) و باقی‌مانده (سبز) تقسیم می‌شود
  //   • مسیریابی مجدد را خودِ NavigationController انجام می‌دهد و خط با آن هماهنگ می‌شود
  // ════════════════════════════════════════════════════════════

  Future<void> _animateNavArrow() async {
    if (!mounted ||
        mapController == null ||
        _driverNavigationSymbol == null ||
        _arrowAnimStart == null ||
        _arrowAnimEnd == null) {
      return;
    }

    // حرکت خطی، بدون easing
    final double t = _arrowAnimationController.value;

    final double latitude = _arrowAnimStart!.latitude +
        (_arrowAnimEnd!.latitude - _arrowAnimStart!.latitude) * t;
    final double longitude = _arrowAnimStart!.longitude +
        (_arrowAnimEnd!.longitude - _arrowAnimStart!.longitude) * t;

    double diff = _arrowAnimEndBearing - _arrowAnimStartBearing;
    if (diff.abs() > 180) diff -= 360 * diff.sign;
    final double bearing = (_arrowAnimStartBearing + diff * t + 360) % 360;

    _arrowDisplayLatLng = LatLng(latitude, longitude);
    _arrowDisplayBearing = bearing;

    try {
      await mapController!.updateSymbol(
        _driverNavigationSymbol!,
        SymbolOptions(
          geometry: LatLng(latitude, longitude),
          iconRotate: bearing,
          iconAnchor: 'center',
        ),
      );
    } catch (e) {
      debugPrint('Nav arrow animation error: $e');
    }
  }

  /// فقط «آخرین» موقعیت پردازش می‌شود و پردازش‌ها پشت‌سرهم اجرا می‌شوند
  Future<void> _processPendingNavPosition() async {
    if (_isProcessingNavUpdate) return;
    _isProcessingNavUpdate = true;

    try {
      while (_pendingNavPosition != null && mounted) {
        final Position p = _pendingNavPosition!;
        _pendingNavPosition = null;

        await _updateNavArrow(LatLng(p.latitude, p.longitude), p.heading);
      }
    } finally {
      _isProcessingNavUpdate = false;
    }
  }

  Future<void> _updateNavArrow(LatLng rawPosition, double rawHeading) async {
    if (mapController == null || !_isMapStyleReady) return;

    if (!mounted) return;

    // 🔧 مسیر فقط یک مالک دارد: NavigationController. هر بار که مسیر عوض شد
    // (شروع سفر یا مسیریابی مجدد خودکار) نسخهٔ جدید را می‌گیریم و خط را
    // دوباره می‌کشیم. به این ترتیب خط روی نقشه همیشه با دستورهای پیچ یکی است.
    final NavigationController navController =
        context.read<NavigationController>();

    if (navController.routeVersion != _lastSyncedRouteVersion &&
        navController.routePoints.length >= 2) {
      _lastSyncedRouteVersion = navController.routeVersion;
      _navRoutePoints = List<LatLng>.of(navController.routePoints);
      _navProgressIndex = 0;
      _navLastRenderedSegment = -1;
      _navLastRenderedPoint = null;

      await _renderNavLines(
        traveled: <LatLng>[],
        remaining: _navRoutePoints,
      );
    }

    final List<LatLng> route = _navRoutePoints;

    LatLng target = rawPosition;
    _NavSnap? onRouteSnap;

    if (route.length >= 2) {
      final _NavSnap? snap = _snapToNavRoute(
        rawPosition,
        route,
        startIndex: _navProgressIndex,
      );

      if (snap != null && snap.distance <= _offRouteThresholdMeters) {
        onRouteSnap = snap;
        target = snap.point;
        _navProgressIndex = max(_navProgressIndex, snap.segmentIndex);
      }
    }

    await _prepareDriverNavigationArrow();

    if (mapController != null && _isDriverArrowImageAdded) {
      try {
        final LatLng? previousTarget = _arrowLastTarget;

        // ───── زاویه ─────
        double bearing = _arrowAnimEndBearing;

        if (_driverNavigationSymbol == null) {
          if (onRouteSnap != null) {
            bearing = _calculateBearing(
              route[onRouteSnap.segmentIndex],
              route[onRouteSnap.segmentIndex + 1],
            );
          } else if (rawHeading >= 0) {
            bearing = rawHeading;
          }
        } else if (previousTarget != null &&
            Geolocator.distanceBetween(
                  previousTarget.latitude,
                  previousTarget.longitude,
                  target.latitude,
                  target.longitude,
                ) >
                3) {
          bearing = _calculateBearing(previousTarget, target);
        }

        // ───── مدت انیمیشن = فاصلهٔ واقعی بین دو آپدیت ─────
        final DateTime now = DateTime.now();
        final int dtMs = _lastArrowUpdateAt == null
            ? 1000
            : now.difference(_lastArrowUpdateAt!).inMilliseconds;
        _lastArrowUpdateAt = now;

        if (_driverNavigationSymbol == null) {
          _driverNavigationSymbol = await mapController!.addSymbol(
            SymbolOptions(
              geometry: target,
              iconImage: 'driver_navigation_arrow',
              iconSize: 0.55,
              iconRotate: bearing,
              iconAnchor: 'center',
            ),
          );

          _arrowLastTarget = target;
          _arrowDisplayLatLng = target;
          _arrowDisplayBearing = bearing;
          _arrowAnimStartBearing = bearing;
          _arrowAnimEndBearing = bearing;

          // نقطهٔ آبی GPS خام دیگر لازم نیست؛ فقط فلش روی مسیر دیده شود
          if (mounted && !_isNavArrowVisible) {
            setState(() {
              _isNavArrowVisible = true;
            });
          }
        } else {
          _arrowAnimStart = _arrowDisplayLatLng ?? previousTarget ?? target;
          _arrowAnimEnd = target;
          _arrowAnimStartBearing = _arrowDisplayBearing;
          _arrowAnimEndBearing = bearing;

          _arrowAnimationController.stop();
          _arrowAnimationController.duration = Duration(
            milliseconds: dtMs.clamp(400, 2500).toInt(),
          );
          _arrowAnimationController.forward(from: 0.0);

          _arrowLastTarget = target;
        }
      } catch (e) {
        debugPrint('Error updating driver navigation arrow: $e');
      }
    } else if (!_isDriverArrowImageAdded) {
      debugPrint('Driver navigation arrow image is not loaded.');
    }

    if (onRouteSnap != null) {
      await _renderNavProgress(onRouteSnap, route);
    }
  }

  /// مسیر را به دو بخش تقسیم می‌کند: طی‌شده (خاکستری) و باقی‌مانده (سبز)
  Future<void> _renderNavProgress(_NavSnap snap, List<LatLng> route) async {
    if (mapController == null) return;
    if (!identical(route, _navRoutePoints)) return;
    if (snap.segmentIndex + 1 >= route.length) return;

    final LatLng? lastPoint = _navLastRenderedPoint;
    if (snap.segmentIndex == _navLastRenderedSegment &&
        lastPoint != null &&
        Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              snap.point.latitude,
              snap.point.longitude,
            ) <
            3) {
      return;
    }

    _navLastRenderedSegment = snap.segmentIndex;
    _navLastRenderedPoint = snap.point;

    final List<LatLng> traveled = <LatLng>[
      for (int i = 0; i <= snap.segmentIndex; i++) route[i],
      snap.point,
    ];
    final List<LatLng> remaining = <LatLng>[
      snap.point,
      for (int i = snap.segmentIndex + 1; i < route.length; i++) route[i],
    ];

    await _renderNavLines(traveled: traveled, remaining: remaining);
  }

  Future<void> _renderNavLines({
    required List<LatLng> traveled,
    required List<LatLng> remaining,
  }) async {
    if (mapController == null || remaining.isEmpty) return;

    // یک خط با دو نقطهٔ یکسان روی نقشه دیده نمی‌شود
    final List<LatLng> grey = traveled.length >= 2
        ? traveled
        : <LatLng>[remaining.first, remaining.first];

    try {
      if (_navRemainingLine != null && _navTraveledLine != null) {
        await mapController!.updateLine(
          _navTraveledLine!,
          LineOptions(geometry: grey),
        );
        await mapController!.updateLine(
          _navRemainingLine!,
          LineOptions(geometry: remaining),
        );
        return;
      }
    } catch (_) {
      // خط‌ها پاک شده‌اند؛ پایین‌تر دوباره اضافه می‌شوند
      _navRemainingLine = null;
      _navTraveledLine = null;
    }

    try {
      await mapController!.clearLines();

      _navTraveledLine = await mapController!.addLine(
        LineOptions(
          geometry: grey,
          lineColor: '#B0B7C3',
          lineWidth: 6.0,
          lineJoin: 'round',
        ),
      );

      _navRemainingLine = await mapController!.addLine(
        LineOptions(
          geometry: remaining,
          lineColor: '#0F7D55',
          lineWidth: 6.0,
          lineOpacity: 0.85,
          lineJoin: 'round',
        ),
      );
    } catch (e) {
      debugPrint('Error rendering navigation lines: $e');
    }
  }

  /// نزدیک‌ترین نقطه روی مسیر؛ فقط «به جلو» از نقطهٔ پیشرفت جست‌وجو می‌کند
  /// (جلوی پرش به سمت برگشتِ مسیر در دور برگردان‌ها را می‌گیرد).
  _NavSnap? _snapToNavRoute(
    LatLng gpsPoint,
    List<LatLng> polyline, {
    int startIndex = 0,
    double maxAheadMeters = 600,
  }) {
    if (polyline.length < 2) return null;

    final int from = max(0, min(startIndex - 1, polyline.length - 2));

    double minDistance = double.infinity;
    LatLng closestPoint = polyline[from];
    int bestIndex = from;
    double travelled = 0;

    for (int i = from; i < polyline.length - 1; i++) {
      final LatLng a = polyline[i];
      final LatLng b = polyline[i + 1];

      final LatLng projected = _getClosestPointOnSegment(gpsPoint, a, b);

      final double distance = Geolocator.distanceBetween(
        gpsPoint.latitude,
        gpsPoint.longitude,
        projected.latitude,
        projected.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projected;
        bestIndex = i;
      }

      travelled += Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      if (travelled > maxAheadMeters) break;
    }

    return _NavSnap(closestPoint, minDistance, bestIndex);
  }

  LatLng _getClosestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final double x = p.longitude, y = p.latitude;
    final double x1 = a.longitude, y1 = a.latitude;
    final double x2 = b.longitude, y2 = b.latitude;

    final double dx = x2 - x1;
    final double dy = y2 - y1;

    if (dx == 0 && dy == 0) return a;

    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0).toDouble();

    return LatLng(y1 + t * dy, x1 + t * dx);
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final double startLatRad = start.latitude * pi / 180;
    final double startLngRad = start.longitude * pi / 180;
    final double endLatRad = end.latitude * pi / 180;
    final double endLngRad = end.longitude * pi / 180;

    final double dLng = endLngRad - startLngRad;

    final double y = sin(dLng) * cos(endLatRad);
    final double x = cos(startLatRad) * sin(endLatRad) -
        sin(startLatRad) * cos(endLatRad) * cos(dLng);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  /// نوشتن لوکیشن راننده در Firestore: حداکثر هر ۲ ثانیه، و همیشه آخرین مقدار
  void _queueDriverLocationWrite(Position position) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastLocationWriteAt;

    if (last == null || now.difference(last) >= _locationWriteInterval) {
      _lastLocationWriteAt = now;
      _queuedLocation = null;
      unawaited(_updateDriverLiveLocation(position));
      return;
    }

    _queuedLocation = position;

    _locationWriteTimer ??= Timer(
      _locationWriteInterval - now.difference(last),
      () {
        _locationWriteTimer = null;
        final Position? queued = _queuedLocation;
        _queuedLocation = null;

        if (queued != null && mounted && isDriverAvailable) {
          _lastLocationWriteAt = DateTime.now();
          unawaited(_updateDriverLiveLocation(queued));
        }
      },
    );
  }

  bool _hasWarnedBackgroundLocation = false;

  /// 🔧 راهنمای فعال‌سازی «همیشه اجازه بده» — بدون این، ردیابی به‌محض
  /// قفل شدن صفحه یا رفتن اپ به پس‌زمینه متوقف می‌شود.
  Future<void> _promptEnableBackgroundLocation() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: const Text(
          'برای ادامهٔ ارسال موقعیت حتی وقتی صفحه قفل است، از تنظیمات '
          'گوشی روی مجوز موقعیت این اپ بزنید «همیشه اجازه بده».',
        ),
        action: SnackBarAction(
          label: 'تنظیمات',
          onPressed: () {
            unawaited(Geolocator.openAppSettings());
          },
        ),
      ),
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<Position?> getCurrentLiveLocationOfDriver() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await _showMessage('لطفاً GPS یا Location گوشی را فعال کنید.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _showMessage('اجازهٔ دسترسی به موقعیت مکانی داده نشده است.');
        return null;
      }

      // 🔧 FIX: مجوز عادی («فقط حین استفاده») برای وقتی که اپ باز است کافی‌ست،
      // ولی اگر راننده صفحه را قفل کند یا اپ پس‌زمینه برود، اندروید ۱۰ به بعد
      // بدون مجوز «همیشه اجازه بده» ارسال موقعیت را قطع می‌کند. این مجوز را
      // نمی‌شود با یک دیالوگ عادی گرفت؛ کاربر باید از تنظیمات سیستم فعالش کند.
      if (permission == LocationPermission.whileInUse && !_hasWarnedBackgroundLocation) {
        _hasWarnedBackgroundLocation = true;
        unawaited(_promptEnableBackgroundLocation());
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      currentPositionOfDriver = position;

      if (mounted) {
        setState(() {});
      }

      return position;
    } catch (e) {
      debugPrint('Error fetching driver location: $e');
      await _showMessage('دریافت موقعیت مکانی انجام نشد.');
      return null;
    }
  }

  Future<void> _loadDriverStatus() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool savedStatus = prefs.getBool('isDriverAvailable') ?? false;

      if (!mounted) return;

      // 🔧 FIX: flip the flag BEFORE calling goOnlineNow(), since
      // goOnlineNow() -> _updateDriverLiveLocation() checks isDriverAvailable
      // and silently skips the Firestore write if it's still false.
      setState(() {
        isDriverAvailable = savedStatus;
      });

      if (savedStatus) {
        await goOnlineNow();
        setAndGetLocationUpdates();
        listenForTripRequests();
      }
    } catch (e) {
      debugPrint('Error loading driver status: $e');
    }
  }

  Future<void> _saveDriverStatus(bool status) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDriverAvailable', status);
  }

  Future<void> _setDriverStatus({
    required String status,
    required bool isOnline,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('drivers').doc(user.uid).set(
      {
        'newTripStatus': status,
        'isOnline': isOnline,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _updateDriverLiveLocation(Position position) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || !isDriverAvailable) return;

    try {
      await _firestore.collection('driver_locations').doc(user.uid).set(
        {
          'driver_id': user.uid,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'is_online': true,
          'active_trip_id': activeTripId,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error updating driver live location: $e');
    }
  }

  Future<void> goOnlineNow() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    driverOnlineTimestamp = DateTime.now();
    currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();

    if (currentPositionOfDriver != null) {
      await _updateDriverLiveLocation(currentPositionOfDriver!);
    }

    await _setDriverStatus(status: 'waiting', isOnline: true);
  }

  Future<void> goOfflineNow() async {
    if (activeTripId != null) {
      await _showMessage('تا پایان یا لغو سفر فعال نمی‌توانید آفلاین شوید.');
      return;
    }

    await positionStreamHomePage?.cancel();
    positionStreamHomePage = null;

    await tripRequestStream?.cancel();
    tripRequestStream = null;

    _locationWriteTimer?.cancel();
    _locationWriteTimer = null;
    _queuedLocation = null;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('driver_locations').doc(user.uid).set(
        {
          'is_online': false,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error setting driver offline location: $e');
    }

    try {
      await _setDriverStatus(status: 'offline', isOnline: false);
    } catch (e) {
      debugPrint('Error setting driver offline: $e');
    }
  }

  void setAndGetLocationUpdates() {
    positionStreamHomePage?.cancel();

    positionStreamHomePage = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
        // 🔧 FIX: بدون این، اندروید به‌محض اینکه اپ پس‌زمینه بره یا صفحه
        // قفل بشه، این استریم رو متوقف می‌کنه — دقیقاً همون رفتاری که
        // باعث «یک آپدیت میاد، بعد هیچی» می‌شد. با این نوتیفیکیشن،
        // اندروید یک Foreground Service می‌سازه و ادامه می‌ده به فرستادن
        // موقعیت حتی وقتی اپ پس‌زمینه‌ست.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'سفیر — سفر فعال',
          notificationText: 'در حال ارسال موقعیت مکانی شما به مسافر است.',
          enableWakeLock: true,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      ),
    ).listen(
      (Position position) {
        if (_isDisposing) return;

        currentPositionOfDriver = position;

        if (!mounted) return;

        // نوشتن در Firestore منتظر نمی‌ماند تا حرکت آیکن کند نشود
        _queueDriverLocationWrite(position);

        final NavigationController navController =
            context.read<NavigationController>();

        if (navController.isNavigating) {
          navController.updateDriverPosition(
            LatLng(position.latitude, position.longitude),
            langCode: context.locale.languageCode,
          );

          _pendingNavPosition = position;
          unawaited(_processPendingNavPosition());
        }
      },
      onError: (Object error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  void listenForTripRequests() {
    tripRequestStream?.cancel();

    tripRequestStream = _firestore
        .collection('rides')
        .where('status', isEqualTo: TripStatus.searching)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        if (!mounted || !isDriverAvailable || activeTripId != null) return;

        for (final DocumentChange<Map<String, dynamic>> change
            in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;

          final String tripId = change.doc.id;

          PushNotificationSystem().retrieveTripRequestInfo(
            tripId,
            context,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Firestore ride listener error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void initializePushNotificationSystem() {
    final PushNotificationSystem notificationSystem =
        PushNotificationSystem();

    notificationSystem.generateDeviceRegistrationToken();
    notificationSystem.startListeningForNewNotification(context);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final String number = phoneNumber.trim();

    if (number.isEmpty) {
      await _showMessage('شمارهٔ تماس مسافر موجود نیست.');
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: number);

    try {
      final bool launched = await launchUrl(phoneUri);

      if (!launched) {
        await _showMessage('باز کردن تماس تلفنی ممکن نشد.');
      }
    } catch (e) {
      debugPrint('Phone launch error: $e');
      await _showMessage('باز کردن تماس تلفنی ممکن نشد.');
    }
  }

  Future<void> _openExternalMap(double lat, double lng) async {
    final Uri mapUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      final bool launched = await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _showMessage('باز کردن نقشه انجام نشد.');
      }
    } catch (e) {
      debugPrint('External map launch error: $e');
      await _showMessage('باز کردن نقشه انجام نشد.');
    }
  }

  Future<void> _clearRouteAndNavigation() async {
    try {
      if (mounted) {
        context.read<NavigationController>().stopNavigation();
      }

      _arrowAnimationController.stop();
      _pendingNavPosition = null;
      _navRoutePoints = <LatLng>[];
      _lastSyncedRouteVersion = -1;
      _navProgressIndex = 0;
      _navLastRenderedSegment = -1;
      _navLastRenderedPoint = null;
      _navRemainingLine = null;
      _navTraveledLine = null;
      _arrowAnimStart = null;
      _arrowAnimEnd = null;
      _arrowDisplayLatLng = null;
      _arrowLastTarget = null;
      _lastArrowUpdateAt = null;
      _arrowAnimEndBearing = 0.0;
      _arrowDisplayBearing = 0.0;

      if (mapController != null) {
        await mapController!.clearLines();
        if (mapController != null && _driverNavigationSymbol != null) {
          await mapController!.removeSymbol(_driverNavigationSymbol!);
          _driverNavigationSymbol = null;
        }
      }

      if (mounted && _isNavArrowVisible) {
        setState(() {
          _isNavArrowVisible = false;
        });
      }
    } catch (e) {
      debugPrint('Error clearing route: $e');
    }
  }

  Future<void> _saveDriverDataToTripInfo(String tripId) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || tripId.isEmpty) return;

    try {
      final DocumentSnapshot<Map<String, dynamic>> driverDoc =
          await _firestore.collection('drivers').doc(currentUser.uid).get();

      String realDriverName = '';
      String realDriverPhone = '';
      String realDriverPhoto = '';
      String carModelName = '';
      String carColorName = '';
      String rawPlateNumber = '';
      String plateProvince = '';
      String plateCategory = '';
      String plateType = '';

      if (driverDoc.exists && driverDoc.data() != null) {
        final Map<String, dynamic> data = driverDoc.data()!;

        final String firstName = data['firstName']?.toString() ?? '';
        final String secondName = data['secondName']?.toString() ?? '';
        realDriverName = '$firstName $secondName'.trim();
        realDriverPhone = data['phoneNumber']?.toString() ?? '';
        realDriverPhoto = data['profilePicture']?.toString() ?? '';

        final dynamic vehicle = data['vehicleInfo'];
        if (vehicle is Map) {
          carModelName = vehicle['brand']?.toString() ?? '';
          carColorName = vehicle['color']?.toString() ?? '';
          rawPlateNumber = vehicle['registrationPlateNumber']?.toString() ?? '';
          plateProvince = vehicle['plateProvince']?.toString() ?? '';
          plateCategory = vehicle['plateCategory']?.toString() ?? '';
          plateType = vehicle['plateType']?.toString() ?? '';
        }
      } else {
        debugPrint(
          '⚠️ Driver document not found in Firestore for uid: ${currentUser.uid}',
        );
      }

      final String fullCarPlate = (plateProvince.isNotEmpty && rawPlateNumber.isNotEmpty)
          ? '$plateProvince - $plateCategory $rawPlateNumber ($plateType)'
          : rawPlateNumber;

      final Map<String, dynamic> driverDataMap = {
        'driver_id': currentUser.uid,
        'driverId': currentUser.uid,

        'driver_name': realDriverName,
        'driverName': realDriverName,
        'driver_phone': realDriverPhone,
        'driverPhone': realDriverPhone,
        'driver_photo': realDriverPhoto,
        'driverPhoto': realDriverPhoto,

        'car_details': '$carModelName - $carColorName',
        'carDetails': '$carModelName - $carColorName',
        'car_color': carColorName,
        'carColor': carColorName,
        'car_number': fullCarPlate,
        'carNumber': fullCarPlate,

        'plate_province': plateProvince,
        'plate_category': plateCategory,
        'plate_num': rawPlateNumber,
        'plate_farsi_num': rawPlateNumber,
        'is_temp_plate': false,

        'driver_data_updated_at': FieldValue.serverTimestamp(),
      };

      if (currentPositionOfDriver != null) {
        driverDataMap['driverLocation'] = {
          'latitude': currentPositionOfDriver!.latitude,
          'longitude': currentPositionOfDriver!.longitude,
        };
        driverDataMap['driver_lat'] = currentPositionOfDriver!.latitude;
        driverDataMap['driver_lng'] = currentPositionOfDriver!.longitude;
      }

      await _firestore.collection('rides').doc(tripId).set(
            driverDataMap,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error saving driver data into trip: $e');
    }
  }

  Future<void> _startPickupRoute(
    String tripId,
    Map<String, dynamic> tripData,
  ) async {
    if (_isStartingRoute) return;

    _isStartingRoute = true;

    try {
      await _saveDriverDataToTripInfo(tripId);

      currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();
      if (currentPositionOfDriver == null) return;

      final LatLng? pickupLatLng = _extractLatLng(
        tripData,
        [
          'originLatLng',
          'pickup_location',
          'pickupLatLng',
          'origin',
        ],
        latKey: 'from_lat',
        lngKey: 'from_lng',
      );

      if (pickupLatLng == null) {
        await _showMessage('مختصات مبدأ این سفر پیدا نشد.');
        return;
      }

      activeTripId = tripId;
      activeTripStatus = TripStatus.accepted;

      await startTripNavigation(
        LatLng(
          currentPositionOfDriver!.latitude,
          currentPositionOfDriver!.longitude,
        ),
        pickupLatLng,
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error starting pickup route: $e');
    } finally {
      _isStartingRoute = false;
    }
  }

  Future<void> _startDestinationRoute(
    String tripId,
    Map<String, dynamic> tripData,
  ) async {
    if (_isStartingRoute) return;

    _isStartingRoute = true;

    try {
      currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();
      if (currentPositionOfDriver == null) return;

      final LatLng? destinationLatLng = _extractLatLng(
        tripData,
        [
          'destinationLatLng',
          'dropoff_location',
          'dropoffLatLng',
          'destination',
        ],
        latKey: 'to_lat',
        lngKey: 'to_lng',
      );

      if (destinationLatLng == null) {
        await _showMessage('مختصات مقصد این سفر پیدا نشد.');
        return;
      }

      activeTripId = tripId;
      activeTripStatus = TripStatus.onTrip;

      await startTripNavigation(
        LatLng(
          currentPositionOfDriver!.latitude,
          currentPositionOfDriver!.longitude,
        ),
        destinationLatLng,
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error starting destination route: $e');
    } finally {
      _isStartingRoute = false;
    }
  }

  Future<void> startTripNavigation(
    LatLng driverPos,
    LatLng destinationPos,
  ) async {
    final NavigationController navController =
        context.read<NavigationController>();

    final List<LatLng> routePoints = await navController.startNavigation(
      driverPos,
      destinationPos,
      context.locale.languageCode,
    );

    if (!mounted) return;

    _lastSyncedRouteVersion = navController.routeVersion;
    _navRoutePoints = List<LatLng>.of(routePoints);
    _navProgressIndex = 0;
    _navLastRenderedSegment = -1;
    _navLastRenderedPoint = null;

    if (_navRoutePoints.length >= 2) {
      await _renderNavLines(
        traveled: <LatLng>[],
        remaining: _navRoutePoints,
      );
    }

    // آیکن را همان لحظه روی مسیر بگذار (بدون انتظار برای GPS بعدی)
    if (currentPositionOfDriver != null) {
      _pendingNavPosition = currentPositionOfDriver;
      await _processPendingNavPosition();
    }
  }

  Future<void> _updateTripStatus(
    String tripId,
    String newStatus,
    Map<String, dynamic> tripData,
  ) async {
    if (_isTripActionLoading || tripId.isEmpty) return;

    final User? driver = FirebaseAuth.instance.currentUser;
    if (driver == null) return;

    if (mounted) {
      setState(() {
        _isTripActionLoading = true;
      });
    }

    try {
      final DocumentReference<Map<String, dynamic>> tripRef =
          _firestore.collection('rides').doc(tripId);

      final bool updated = await _firestore.runTransaction<bool>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(tripRef);

          if (!snapshot.exists) return false;

          final Map<String, dynamic> data = snapshot.data() ?? {};
          final String currentStatus = data['status']?.toString() ?? '';

          final String assignedDriverId = data['driver_id']?.toString() ??
              data['driverId']?.toString() ??
              '';

          if (assignedDriverId != driver.uid) return false;

          final bool canArrive = currentStatus == TripStatus.accepted &&
              newStatus == TripStatus.arrived;

          final bool canStart = currentStatus == TripStatus.arrived &&
              newStatus == TripStatus.onTrip;

          final bool canComplete = currentStatus == TripStatus.onTrip &&
              newStatus == TripStatus.completed;

          if (!canArrive && !canStart && !canComplete) return false;

          final Map<String, dynamic> updateData = {
            'status': newStatus,
            'updated_at': FieldValue.serverTimestamp(),
          };

          if (newStatus == TripStatus.arrived) {
            updateData['arrived_at'] = FieldValue.serverTimestamp();
          } else if (newStatus == TripStatus.onTrip) {
            updateData['started_at'] = FieldValue.serverTimestamp();
          } else if (newStatus == TripStatus.completed) {
            updateData['completed_at'] = FieldValue.serverTimestamp();
          }

          transaction.update(tripRef, updateData);
          return true;
        },
      );

      if (!updated) {
        await _showMessage(
          'عملیات انجام نشد؛ وضعیت سفر تغییر کرده یا سفر متعلق به شما نیست.',
        );
        return;
      }

      if (newStatus == TripStatus.arrived) {
        if (mounted) {
          setState(() {
            activeTripId = tripId;
            activeTripStatus = TripStatus.arrived;
          });
        }
        return;
      }

      if (newStatus == TripStatus.onTrip) {
        await _startDestinationRoute(tripId, tripData);
        return;
      }

      if (newStatus == TripStatus.completed) {
        await _clearRouteAndNavigation();
        await _setDriverStatus(status: 'waiting', isOnline: true);

        if (mounted) {
          setState(() {
            activeTripId = null;
            activeTripStatus = null;
          });
        }

        await _showMessage('سفر با موفقیت پایان یافت.');
      }
    } catch (e, stackTrace) {
      debugPrint('Error updating trip status: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _showMessage('تغییر وضعیت سفر انجام نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) {
        setState(() {
          _isTripActionLoading = false;
        });
      }
    }
  }

  Future<void> _cancelTrip(String tripId) async {
    if (_isTripActionLoading || tripId.isEmpty) return;

    final User? driver = FirebaseAuth.instance.currentUser;
    if (driver == null) return;

    if (mounted) {
      setState(() {
        _isTripActionLoading = true;
      });
    }

    try {
      final DocumentReference<Map<String, dynamic>> tripRef =
          _firestore.collection('rides').doc(tripId);

      final bool cancelled = await _firestore.runTransaction<bool>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(tripRef);

          if (!snapshot.exists) return false;

          final Map<String, dynamic> data = snapshot.data() ?? {};
          final String currentStatus = data['status']?.toString() ?? '';

          final String assignedDriverId = data['driver_id']?.toString() ??
              data['driverId']?.toString() ??
              '';

          if (assignedDriverId != driver.uid) return false;

          if (currentStatus != TripStatus.accepted &&
              currentStatus != TripStatus.arrived &&
              currentStatus != TripStatus.onTrip) {
            return false;
          }

          transaction.update(
            tripRef,
            {
              'status': TripStatus.cancelledByDriver,
              'cancelled_by': 'driver',
              'cancelled_by_driver_id': driver.uid,
              'cancelled_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            },
          );

          return true;
        },
      );

      if (!cancelled) {
        await _showMessage('لغو انجام نشد؛ وضعیت سفر قبلاً تغییر کرده است.');
        return;
      }

      await _clearRouteAndNavigation();
      await _setDriverStatus(status: 'waiting', isOnline: true);

      if (mounted) {
        setState(() {
          activeTripId = null;
          activeTripStatus = null;
        });
      }

      await _showMessage('سفر لغو شد.');
    } catch (e, stackTrace) {
      debugPrint('Error cancelling trip: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _showMessage('لغو سفر انجام نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) {
        setState(() {
          _isTripActionLoading = false;
        });
      }
    }
  }

  Future<void> _handleRemoteTripEnd() async {
    await _clearRouteAndNavigation();

    try {
      await _setDriverStatus(status: 'waiting', isOnline: true);
    } catch (e) {
      debugPrint('Error resetting driver status after remote trip end: $e');
    }

    if (!mounted) return;

    setState(() {
      activeTripId = null;
      activeTripStatus = null;
    });

    await _showMessage('سفر توسط مسافر لغو شد.');
  }

  LatLng? _getNavigationTarget(
    String status,
    Map<String, dynamic> tripData,
  ) {
    final bool goingToPickup = status == TripStatus.accepted ||
        status == TripStatus.arrived;

    return _extractLatLng(
      tripData,
      goingToPickup
          ? [
              'origin',
              'originLatLng',
              'pickup_location',
              'pickupLatLng',
            ]
          : [
              'destination',
              'destinationLatLng',
              'dropoff_location',
              'dropoffLatLng',
            ],
      latKey: goingToPickup ? 'from_lat' : 'to_lat',
      lngKey: goingToPickup ? 'from_lng' : 'to_lng',
    );
  }

  void _showStatusChangeModal() {
    if (_isTripActionLoading) return;

    showModalBottomSheet(
      context: context,
      isDismissible: !isLoading,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    !isDriverAvailable
                        ? 'change_to_online_title'.tr()
                        : 'change_to_offline_title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (isDriverAvailable &&
                                      activeTripId != null) {
                                    await _showMessage(
                                      'تا پایان یا لغو سفر فعال نمی‌توانید آفلاین شوید.',
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    isLoading = true;
                                  });

                                  try {
                                    if (!isDriverAvailable) {
                                      // 🔧 FIX: flip the flag to true FIRST
                                      // (before goOnlineNow), otherwise
                                      // _updateDriverLiveLocation() silently
                                      // skips writing the driver's real
                                      // coordinates to Firestore, leaving
                                      // driver_locations pointing at stale
                                      // data until the next GPS move.
                                      if (mounted) {
                                        setState(() {
                                          isDriverAvailable = true;
                                        });
                                      } else {
                                        isDriverAvailable = true;
                                      }

                                      await goOnlineNow();
                                      setAndGetLocationUpdates();
                                      listenForTripRequests();
                                      await _saveDriverStatus(true);
                                    } else {
                                      if (mounted) {
                                        setState(() {
                                          isDriverAvailable = false;
                                        });
                                      } else {
                                        isDriverAvailable = false;
                                      }

                                      await goOfflineNow();
                                      await _saveDriverStatus(false);
                                    }
                                  } catch (e) {
                                    debugPrint('Status update error: $e');
                                    await _showMessage(
                                      'تغییر وضعیت راننده انجام نشد.',
                                    );
                                  } finally {
                                    isLoading = false;

                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDriverAvailable
                                ? const Color(0xFFE53935)
                                : const Color(0xFF0F7D55),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'btn_confirm'.tr(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(modalContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'btn_cancel'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            MapLibreMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  currentPositionOfDriver?.latitude ?? 34.5553,
                  currentPositionOfDriver?.longitude ?? 69.2075,
                ),
                zoom: 15,
              ),
              styleString: 'assets/map/style.json',
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationEnabled: !_isNavArrowVisible,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: () async {
                _isMapStyleReady = true;
                _isDriverArrowImageAdded = false;
                await _prepareDriverNavigationArrow();
              },
            ),
            Positioned(
              top: 20,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter_btn',
                elevation: 1,
                backgroundColor: Colors.white,
                onPressed: _centerMapOnDriver,
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF0F7D55),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: isLoading ? null : _showStatusChangeModal,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDriverAvailable
                          ? const Color(0xFFE53935)
                          : const Color(0xFF0F7D55),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDriverAvailable
                              ? 'go_offline'.tr()
                              : 'go_online'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (currentUser != null && isDriverAvailable)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('rides')
                    .where('driver_id', isEqualTo: currentUser.uid)
                    .where(
                      'status',
                      whereIn: [
                        TripStatus.accepted,
                        TripStatus.arrived,
                        TripStatus.onTrip,
                      ],
                    )
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    debugPrint('Active trip stream error: ${snapshot.error}');
                    return const SizedBox.shrink();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    if (activeTripId != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && activeTripId != null) {
                          _handleRemoteTripEnd();
                        }
                      });
                    }

                    return const SizedBox.shrink();
                  }

                  final QueryDocumentSnapshot<Map<String, dynamic>> tripDoc =
                      snapshot.data!.docs.first;

                  final String tripId = tripDoc.id;
                  final Map<String, dynamic> tripData = tripDoc.data();
                  final String status =
                      tripData['status']?.toString() ?? TripStatus.accepted;

                  if (!_isTripOwnedByCurrentDriver(tripData)) {
                    return const SizedBox.shrink();
                  }

                  if (activeTripId != tripId || activeTripStatus != status) {
                    final String? previousTripId = activeTripId;

                    activeTripId = tripId;
                    activeTripStatus = status;

                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;

                      if (previousTripId != null &&
                          previousTripId != tripId) {
                        await _clearRouteAndNavigation();
                      }

                      if (status == TripStatus.accepted) {
                        await _startPickupRoute(tripId, tripData);
                      } else if (status == TripStatus.onTrip) {
                        await _startDestinationRoute(tripId, tripData);
                      }
                    });
                  }

                  return ActiveTripSheet(
                    tripId: tripId,
                    status: status,
                    tripData: tripData,
                    isTripActionLoading: _isTripActionLoading,
                    onUpdateTripStatus: (tId, newStatus) {
                      _updateTripStatus(tId, newStatus, tripData);
                    },
                    onCancelTrip: _cancelTrip,
                    onMakePhoneCall: _makePhoneCall,
                    onOpenExternalMap: (lat, lng) =>
                        _openExternalMap(lat, lng),
                    getNavigationTarget: () =>
                        _getNavigationTarget(status, tripData),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// نتیجهٔ چسباندن یک نقطهٔ GPS به مسیر
class _NavSnap {
  final LatLng point;
  final double distance;
  final int segmentIndex;

  const _NavSnap(this.point, this.distance, this.segmentIndex);
}
