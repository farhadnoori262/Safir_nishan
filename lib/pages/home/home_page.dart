import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safir_drivers/controllers/navigation_controller.dart';
import 'package:safir_drivers/pages/navigation/navigation_page.dart';
import 'package:safir_drivers/providers/registration_provider.dart'; 
import 'package:safir_drivers/utils/app_colors.dart';
import '../../push_notifications/push_notification_system.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  MapLibreMapController? mapController;

  Position? currentPositionOfDriver;
  LatLng currentLatLng = const LatLng(34.5553, 69.2075);
  bool isDriverAvailable = false;
  bool isMapMoving = false;

  Symbol? driverSymbol; // 📌 فلش متحرک راننده
  Symbol? destinationSymbol; // 📌 پین قفل‌شده مقصد

  LatLng? previousLocation;

  StreamSubscription<Position>? positionStreamHomePage;
  StreamSubscription<QuerySnapshot>? tripRequestStream;

  void _onMapCreated(MapLibreMapController controller) async {
    mapController = controller;
    await _loadCustomIcons();
    _updateDriverMarker(currentLatLng);
  }

  /// 📌 بارگذاری آیکون‌های Assets در MapLibre
  Future<void> _loadCustomIcons() async {
    if (mapController == null) return;
    try {
      final ByteData bytes = await rootBundle.load("assets/images/car_icon.png");
      final Uint8List list = bytes.buffer.asUint8List();
      await mapController!.addImage("driver-arrow", list);
    } catch (e) {
      debugPrint("Error loading icon asset: $e");
    }
  }

  /// 📐 محاسبه زاویه حرکت (Bearing) برای چرخش دقیق فلش روی خط سرک
  double _calculateBearing(LatLng start, LatLng end) {
    double startLat = start.latitude * (math.pi / 180.0);
    double startLng = start.longitude * (math.pi / 180.0);
    double endLat = end.latitude * (math.pi / 180.0);
    double endLng = end.longitude * (math.pi / 180.0);

    double dLng = endLng - startLng;
    double y = math.sin(dLng) * math.cos(endLat);
    double x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    double bearing = math.atan2(y, x);
    bearing = bearing * (180.0 / math.pi);
    return (bearing + 360.0) % 360.0;
  }

  /// 📌 به‌روزرسانی یا ایجاد نشانگر متحرک راننده با چرخش دقیق
  Future<void> _updateDriverMarker(LatLng position) async {
    if (mapController == null) return;

    double bearing = 0.0;
    if (previousLocation != null && previousLocation != position) {
      bearing = _calculateBearing(previousLocation!, position);
    }
    previousLocation = position;

    if (driverSymbol == null) {
      driverSymbol = await mapController!.addSymbol(
        SymbolOptions(
          geometry: position,
          iconImage: "driver-arrow",
          iconSize: 0.8,
          iconRotate: bearing,
          iconAnchor: "center",
        ),
      );
    } else {
      await mapController!.updateSymbol(
        driverSymbol!,
        SymbolOptions(
          geometry: position,
          iconRotate: bearing,
        ),
      );
    }
  }

  /// 📌 ثبت و قفل مارکر مقصد روی نقشه
  Future<void> _setDestinationMarker(LatLng destination) async {
    if (mapController == null) return;

    if (destinationSymbol != null) {
      await mapController!.removeSymbol(destinationSymbol!);
    }

    destinationSymbol = await mapController!.addSymbol(
      SymbolOptions(
        geometry: destination,
        iconImage: "marker-15", // یا آیکون دلخواه مقصد در صورت لود در addImage
        iconSize: 1.5,
        iconAnchor: "bottom",
      ),
    );
  }

  /// 📌 پاکسازی مارکر مقصد
  Future<void> _clearDestinationMarker() async {
    if (mapController != null && destinationSymbol != null) {
      await mapController!.removeSymbol(destinationSymbol!);
      destinationSymbol = null;
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!mounted || mapController == null) return;

    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: destLocation,
          zoom: destZoom,
        ),
      ),
    );
  }

  /// 📌 متد رسم خط مسیر
  Future<void> _drawRoutePolyline(List<LatLng> points) async {
    if (mapController == null || points.isEmpty) return;

    await mapController!.clearLines();

    await mapController!.addLine(
      LineOptions(
        geometry: points,
        lineColor: "#145A41",
        lineWidth: 6.0,
        lineOpacity: 0.85,
      ),
    );
  }

  /// 📌 پاک کردن خط مسیر
  Future<void> _clearRoutePolyline() async {
    if (mapController != null) {
      await mapController!.clearLines();
    }
  }

  /// 🚀 شروع مسیریابی واقعی به همراه پین مقصد قفل‌شده
  Future<void> startRealNavigation(LatLng start, LatLng destination) async {
    final navController = Provider.of<NavigationController>(context, listen: false);

    List<LatLng> points = await navController.startNavigation(
      start,
      destination,
      context.locale.languageCode,
    );

    if (points.isNotEmpty) {
      await _drawRoutePolyline(points);
      await _setDestinationMarker(destination);
      _animatedMapMove(start, 17.0);
      _updateDriverMarker(start);
    }
  }

  /// 🧪 تابع شبیه‌سازی حرکت
  void startSimulatedTestDrive(NavigationController navController) async {
    List<LatLng> simulatedPoints = [
      const LatLng(34.5553, 69.2075),
      const LatLng(34.5558, 69.2080),
      const LatLng(34.5564, 69.2088),
      const LatLng(34.5570, 69.2095),
    ];

    List<LatLng> points = await navController.startNavigation(
      simulatedPoints.first,
      simulatedPoints.last,
      context.locale.languageCode,
    );

    if (points.isNotEmpty) {
      await _drawRoutePolyline(points);
      await _setDestinationMarker(simulatedPoints.last);
    } else {
      await _drawRoutePolyline(simulatedPoints);
      await _setDestinationMarker(simulatedPoints.last);
    }

    List<String> instructions = [
      'continue_straight'.tr(),
      'voice_turn_right_now'.tr(),
      'voice_turn_left_now'.tr(),
      'arrived'.tr(),
    ];

    List<IconData> icons = [
      Icons.straight,
      Icons.turn_right,
      Icons.turn_left,
      Icons.location_on,
    ];

    for (int i = 0; i < simulatedPoints.length; i++) {
      await Future.delayed(const Duration(seconds: 4));

      if (!mounted) return;

      _animatedMapMove(simulatedPoints[i], 17.5);
      _updateDriverMarker(simulatedPoints[i]);

      navController.updateInstruction(
        instruction: instructions[i],
        distance: (150 - (i * 40)).clamp(0, 500),
        icon: icons[i],
      );

      navController.speakInstruction(instructions[i]);
    }
  }

  void listenForTripRequests() {
    tripRequestStream?.cancel();
    tripRequestStream = FirebaseFirestore.instance
        .collection('rides')
        .where('status', isEqualTo: 'requested')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          String tripID = change.doc.id;
          if (mounted) {
            PushNotificationSystem().retrieveTripRequestInfo(tripID, context);
          }
        }
      }
    });
  }

  Future<void> getCurrentLiveLocationOfDriver() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position positionOfUser = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);
      
      currentPositionOfDriver = positionOfUser;

      if (!mounted) return;

      LatLng newPos = LatLng(currentPositionOfDriver!.latitude, currentPositionOfDriver!.longitude);

      setState(() {
        currentLatLng = newPos;
      });

      _animatedMapMove(currentLatLng, 16.0);
      _updateDriverMarker(currentLatLng);
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  _loadDriverStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool status = prefs.getBool('isDriverAvailable') ?? false;
    if (!mounted) return;

    setState(() {
      isDriverAvailable = status;
    });

    if (isDriverAvailable) {
      goOnlineNow();
      setAndGetLocationUpdates();
      listenForTripRequests();
    }
  }

  _saveDriverStatus(bool status) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDriverAvailable', status);
  }

  goOnlineNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String uid = user.uid;

    if (currentPositionOfDriver != null) {
      await FirebaseFirestore.instance.collection("onlineDrivers").doc(uid).set({
        "driverId": uid,
        "latitude": currentPositionOfDriver!.latitude,
        "longitude": currentPositionOfDriver!.longitude,
        "last_active": FieldValue.serverTimestamp(),
        "status": "idle",
      }, SetOptions(merge: true));
    }

    await FirebaseFirestore.instance.collection("drivers").doc(uid).update({
      "newTripStatus": "waiting",
      "isOnline": true,
    }).catchError((e) {
      debugPrint("Error updating driver status: $e");
    });
  }

  setAndGetLocationUpdates() {
    positionStreamHomePage?.cancel();
    positionStreamHomePage = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
      ),
    ).listen((Position position) {
      currentPositionOfDriver = position;
      LatLng rawLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      final navController = Provider.of<NavigationController>(context, listen: false);

      if (navController.isNavigating) {
        navController.updateDriverPosition(
          rawLatLng,
          langCode: context.locale.languageCode,
        );

        LatLng activeLocation = navController.snappedDriverLocation ?? rawLatLng;

        setState(() {
          currentLatLng = activeLocation;
        });

        _animatedMapMove(activeLocation, 17.5);
        _updateDriverMarker(activeLocation);
      } else {
        setState(() {
          currentLatLng = rawLatLng;
        });
        _updateDriverMarker(rawLatLng);
      }

      if (isDriverAvailable) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirebaseFirestore.instance.collection("onlineDrivers").doc(user.uid).set({
            "driverId": user.uid,
            "latitude": position.latitude,
            "longitude": position.longitude,
            "last_active": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    });
  }

  goOfflineNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      
      await FirebaseFirestore.instance.collection("onlineDrivers").doc(uid).delete();

      await FirebaseFirestore.instance.collection("drivers").doc(uid).update({
        "newTripStatus": "offline",
        "isOnline": false,
      }).catchError((e) {
        debugPrint("Error going offline: $e");
      });
    }

    positionStreamHomePage?.cancel();
    tripRequestStream?.cancel();
  }

  initializePushNotificationSystem() {
    PushNotificationSystem notificationSystem = PushNotificationSystem();
    notificationSystem.generateDeviceRegistrationToken();
    notificationSystem.startListeningForNewNotification(context);
  }

  @override
  void initState() {
    super.initState();
    _loadDriverStatus();
    initializePushNotificationSystem();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<RegistrationProvider>(context, listen: false)
            .retrieveCurrentDriverInfo();
        getCurrentLiveLocationOfDriver();
      }
    });
  }

  @override
  void dispose() {
    positionStreamHomePage?.cancel();
    tripRequestStream?.cancel();
    super.dispose();
  }

  void _showStatusChangeModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_settings_new,
                  color: AppColors.primaryBrand,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                (!isDriverAvailable)
                    ? 'change_to_online_title'.tr()
                    : 'change_to_offline_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                (!isDriverAvailable)
                    ? 'change_to_online_desc'.tr()
                    : 'change_to_offline_desc'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isDriverAvailable) {
                          goOnlineNow();
                          setAndGetLocationUpdates();
                          listenForTripRequests();
                          Navigator.pop(context);
                          if (mounted) {
                            setState(() {
                              isDriverAvailable = true;
                            });
                          }
                          _saveDriverStatus(true);
                        } else {
                          goOfflineNow();
                          Navigator.pop(context);
                          if (mounted) {
                            setState(() {
                              isDriverAvailable = false;
                            });
                          }
                          _saveDriverStatus(false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDriverAvailable 
                            ? Colors.red.shade700 
                            : AppColors.primaryButton,
                        foregroundColor: AppColors.buttonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'confirm'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'cancel'.tr(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void openNavigationTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          currentLocation: currentLatLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navController = Provider.of<NavigationController>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 🗺️ نقشه MapLibre
          MapLibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: currentLatLng,
              zoom: 16.0,
            ),
            styleString: 'assets/map/style.json',
            myLocationEnabled: false,
            trackCameraPosition: true,
            
            onCameraMove: (CameraPosition position) {
              if (!isMapMoving && mounted) {
                setState(() {
                  isMapMoving = true;
                });
              }
            },
            onCameraIdle: () {
              if (isMapMoving && mounted) {
                setState(() {
                  isMapMoving = false;
                  if (mapController != null && !navController.isNavigating) {
                    currentLatLng = mapController!.cameraPosition!.target;
                  }
                });
              }
            },
          ),

          // 📍 مارکر مرکز نقشه
          if (!navController.isNavigating)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.translationValues(0, isMapMoving ? -14 : 0, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrand,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isMapMoving ? 6 : 8,
                        height: isMapMoving ? 3 : 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(isMapMoving ? 0.3 : 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 🔊 📌 بنر نشان مسیریابی (طراحی تابلو به سبک تصویر دو)
          if (navController.isNavigating)
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E), // 👈 زمینه مشکی/تیره کامل مطابق تصویر
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${navController.distanceToNextTurn} ${'meters'.tr()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              navController.navigationInstruction,
                              style: const TextStyle(
                                color: Color(0xFFB0BEC5),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 👈 فلش سفید بزرگ جهت پیچیدن
                      Icon(
                        navController.currentTurnIcon,
                        color: Colors.white,
                        size: 44,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          navController.toggleVoice();
                        },
                        icon: Icon(
                          navController.isVoiceEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white70,
                          size: 26,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          navController.stopNavigation();
                          _clearRoutePolyline();
                          _clearDestinationMarker();
                        },
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 🔘 دکمه وضعیت آنلاین / آفلاین
          if (!navController.isNavigating)
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: SafeArea(
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: (isDriverAvailable ? Colors.red.shade900 : AppColors.primaryBrand).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _showStatusChangeModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDriverAvailable ? Colors.red.shade600 : AppColors.primaryBrand,
                        foregroundColor: AppColors.buttonText,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDriverAvailable ? Colors.greenAccent : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isDriverAvailable 
                                ? 'status_offline_btn'.tr() 
                                : 'status_online_btn'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 🧭 دکمه تست صفحه مسیریابی
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: 'navigation_test_btn',
              onPressed: openNavigationTest,
              backgroundColor: AppColors.primaryBrand,
              icon: const Icon(
                Icons.navigation,
                color: Colors.white,
              ),
              label: Text(
                'navigation_test_btn'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 🎯 دکمه GPS
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'recenter_btn',
              onPressed: getCurrentLiveLocationOfDriver,
              backgroundColor: AppColors.cardBackground,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.my_location, color: AppColors.primaryBrand, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}
