import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:safir_drivers/controllers/navigation_controller.dart';
import 'package:safir_drivers/pages/chat_page.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import '../../push_notifications/push_notification_system.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MapLibreMapController? mapController;
  Position? currentPositionOfDriver;
  bool isDriverAvailable = false;
  bool isLoading = false;
  DateTime? driverOnlineTimestamp;

  StreamSubscription? positionStreamHomePage;
  StreamSubscription? tripRequestStream;
  String? activeTripId;
  String? activeTripStatus;

  // 🔹 سیمبل/مارکر راننده روی نقشه
  Symbol? driverSymbol;

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  void _animateMapToPosition(double lat, double lng) {
    mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(lat, lng)),
    );
  }

  // 🔹 به‌روزرسانی موقعیت مارکر خودرو/فلش راننده روی نقشه
  Future<void> _updateDriverMarkerOnMap(double lat, double lng) async {
    if (mapController == null) return;

    try {
      if (driverSymbol == null) {
        // ایجاد مارکر راننده برای اولین بار
        driverSymbol = await mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(lat, lng),
            iconImage: "car-15", // آیکون پیش‌فرض خودرو در MapLibre (می‌توانید تصویر سفارشی هم اضافه کنید)
            iconSize: 2.0,
            iconAnchor: "center",
          ),
        );
      } else {
        // به‌روزرسانی موقعیت مارکر موجود جهت تعقیب مسیر
        await mapController!.updateSymbol(
          driverSymbol!,
          SymbolOptions(
            geometry: LatLng(lat, lng),
          ),
        );
      }
    } catch (e) {
      debugPrint("خطا در به‌روزرسانی مارکر راننده: $e");
    }
  }

  // 🔹 استخراج ایمن LatLng از فایربیس
  LatLng? _extractLatLng(Map<String, dynamic> data, List<String> keys, {String? latKey, String? lngKey}) {
    for (String key in keys) {
      final value = data[key];
      if (value is GeoPoint) {
        return LatLng(value.latitude, value.longitude);
      } else if (value is Map) {
        final lat = double.tryParse(value['latitude']?.toString() ?? value['lat']?.toString() ?? '');
        final lng = double.tryParse(value['longitude']?.toString() ?? value['lng']?.toString() ?? '');
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
    }
    if (latKey != null && lngKey != null) {
      final lat = double.tryParse(data[latKey]?.toString() ?? '');
      final lng = double.tryParse(data[lngKey]?.toString() ?? '');
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  void listenForTripRequests() {
    tripRequestStream?.cancel();
    driverOnlineTimestamp ??= DateTime.now();

    tripRequestStream = FirebaseFirestore.instance
        .collection('rides')
        .where('status', whereIn: ['requested', 'pending'])
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final String tripID = change.doc.id;
            final data = change.doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final dynamic createdAtValue =
                data['created_at'] ?? data['createdAt'] ?? data['timestamp'];

            if (createdAtValue is Timestamp) {
              final DateTime tripTime = createdAtValue.toDate();
              if (driverOnlineTimestamp != null &&
                  tripTime.isBefore(driverOnlineTimestamp!)) {
                continue;
              }
            } else if (createdAtValue is int) {
              final DateTime tripTime =
                  DateTime.fromMillisecondsSinceEpoch(createdAtValue);
              if (driverOnlineTimestamp != null &&
                  tripTime.isBefore(driverOnlineTimestamp!)) {
                continue;
              }
            }

            if (mounted && isDriverAvailable) {
              PushNotificationSystem().retrieveTripRequestInfo(tripID, context);
            }
          }
        }
      },
      onError: (error) {
        debugPrint("Error listening for trip requests: $error");
      },
    );
  }

  Future<Position?> getCurrentLiveLocationOfDriver() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return null;
      }
      Position positionOfUser = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);
      currentPositionOfDriver = positionOfUser;

      if (mounted) {
        setState(() {});
        _animateMapToPosition(positionOfUser.latitude, positionOfUser.longitude);
        _updateDriverMarkerOnMap(positionOfUser.latitude, positionOfUser.longitude);
      }
      return positionOfUser;
    } catch (e) {
      debugPrint("Error fetching location: $e");
      return null;
    }
  }

  Future<void> _loadDriverStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool status = prefs.getBool('isDriverAvailable') ?? false;
    if (!mounted) return;

    setState(() {
      isDriverAvailable = status;
    });
    if (isDriverAvailable) {
      await goOnlineNow();
      setAndGetLocationUpdates();
      listenForTripRequests();
    }
  }

  Future<void> _saveDriverStatus(bool status) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDriverAvailable', status);
  }

  Future<void> updateDriverStatus(String uid) async {
    await FirebaseFirestore.instance.collection("drivers").doc(uid).update({
      "newTripStatus": "waiting",
      "isOnline": true,
    }).catchError((e) {
      debugPrint("Error updating driver status: $e");
    });
  }

  Future<void> goOnlineNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String uid = user.uid;
    driverOnlineTimestamp = DateTime.now();

    currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();
    if (currentPositionOfDriver != null) {
      await FirebaseFirestore.instance
          .collection("onlineDrivers")
          .doc(uid)
          .set({
        "driverId": uid,
        "latitude": currentPositionOfDriver!.latitude,
        "longitude": currentPositionOfDriver!.longitude,
        "last_active": FieldValue.serverTimestamp(),
        "status": "idle",
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint("Error updating onlineDrivers: $e");
      });
    }
    await updateDriverStatus(uid);
  }

  void setAndGetLocationUpdates() {
    positionStreamHomePage?.cancel();
    positionStreamHomePage = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
      ),
    ).listen((Position position) {
      currentPositionOfDriver = position;

      if (!mounted) return;

      _animateMapToPosition(position.latitude, position.longitude);
      _updateDriverMarkerOnMap(position.latitude, position.longitude);

      final navController = context.read<NavigationController>();
      if (navController.isNavigating) {
        navController.updateDriverPosition(
          LatLng(position.latitude, position.longitude),
          langCode: context.locale.languageCode,
        );

        if (mapController != null && navController.currentRoutePoints.isNotEmpty) {
          _drawRoutePolyline(navController.currentRoutePoints);
        }
      }

      if (isDriverAvailable) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirebaseFirestore.instance
              .collection("onlineDrivers")
              .doc(user.uid)
              .set({
            "driverId": user.uid,
            "latitude": position.latitude,
            "longitude": position.longitude,
            "last_active": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((e) {
            debugPrint("Error stream location update: $e");
          });
        }
      }
    }, onError: (error) {
      debugPrint("Location stream error: $error");
    });
  }

  Future<void> goOfflineNow() async {
    await positionStreamHomePage?.cancel();
    positionStreamHomePage = null;

    await tripRequestStream?.cancel();
    tripRequestStream = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      try {
        await FirebaseFirestore.instance
            .collection("onlineDrivers")
            .doc(uid)
            .delete();
      } catch (e) {
        debugPrint("Error deleting onlineDriver doc: $e");
      }
      try {
        await FirebaseFirestore.instance.collection("drivers").doc(uid).update({
          "newTripStatus": "offline",
          "isOnline": false,
        });
      } catch (e) {
        debugPrint("Error updating offline status: $e");
      }
    }
  }

  void initializePushNotificationSystem() {
    PushNotificationSystem notificationSystem = PushNotificationSystem();
    notificationSystem.generateDeviceRegistrationToken();
    notificationSystem.startListeningForNewNotification(context);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

      Future<void> _openExternalMap(double lat, double lng) async {
    final Uri mapUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    try {
      // استفاده مستقیم از launchUrl بدون گیر دادن به canLaunchUrl
      bool launched = await launchUrl(
        mapUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('امکان باز کردن مسیریاب وجود ندارد.')),
        );
      }
    } catch (e) {
      debugPrint("خطا در باز کردن مسیریاب: $e");
    }
  }

  Future<void> _drawRoutePolyline(List<LatLng> points) async {
    if (mapController == null || points.isEmpty) return;
    try {
      await mapController!.clearLines();
      await mapController!.addLine(
        LineOptions(
          geometry: points,
          lineColor: "#0F7D55",
          lineWidth: 6.0,
          lineOpacity: 0.85,
          lineJoin: 'round',
        ),
      );
    } catch (e) {
      debugPrint("خطا در رسم خط مسیر: $e");
    }
  }

  Future<void> _startPickupRoute(String tripId, Map<String, dynamic> tripData) async {
    try {
      currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();
      if (currentPositionOfDriver == null) return;

      LatLng? pickupLatLng = _extractLatLng(
        tripData, 
        ['originLatLng', 'pickup_location', 'pickupLatLng', 'origin'],
        latKey: 'from_lat',
        lngKey: 'from_lng',
      );

      if (pickupLatLng == null) return;

      final LatLng driverPosition = LatLng(
        currentPositionOfDriver!.latitude,
        currentPositionOfDriver!.longitude,
      );

      activeTripId = tripId;
      activeTripStatus = 'accepted';

      await startTripNavigation(driverPosition, pickupLatLng);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ خطا در مسیر مبدأ: $e');
    }
  }

  Future<void> _startDestinationRoute(String tripId, Map<String, dynamic> tripData) async {
    try {
      currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();
      if (currentPositionOfDriver == null) return;

      LatLng? dropoffLatLng = _extractLatLng(
        tripData, 
        ['destinationLatLng', 'dropoff_location', 'dropoffLatLng', 'destination'],
        latKey: 'to_lat',
        lngKey: 'to_lng',
      );

      if (dropoffLatLng == null) return;

      final LatLng driverPosition = LatLng(
        currentPositionOfDriver!.latitude,
        currentPositionOfDriver!.longitude,
      );

      activeTripId = tripId;
      activeTripStatus = 'ontrip';

      await startTripNavigation(driverPosition, dropoffLatLng);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ خطا در مسیر مقصد: $e');
    }
  }

  Future<void> startTripNavigation(LatLng driverPos, LatLng destinationPos) async {
    final navController = context.read<NavigationController>();

    final routePoints = await navController.startNavigation(
      driverPos,
      destinationPos,
      context.locale.languageCode,
    );

    if (routePoints.isNotEmpty) {
      await _drawRoutePolyline(routePoints);
    }
  }

  Future<void> _updateTripStatus(
      String tripId, String newStatus, Map<String, dynamic> tripData) async {
    try {
      if (newStatus == 'completed') {
        _showCompleteTripDialog(tripId, tripData);
        return;
      }

      await FirebaseFirestore.instance.collection('rides').doc(tripId).update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'accepted') {
        await _startPickupRoute(tripId, tripData);
      } else if (newStatus == 'arrived') {
        setState(() {
          activeTripStatus = 'arrived';
        });
      } else if (newStatus == 'ontrip' || newStatus == 'in_progress') {
        await _startDestinationRoute(tripId, tripData);
      }
    } catch (e) {
      debugPrint("Error updating trip status: $e");
    }
  }

  void _showCompleteTripDialog(String tripId, Map<String, dynamic> tripData) {
    String price = '${tripData['fareAmount'] ?? tripData['price'] ?? '0'}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0F7D55), size: 28),
              const SizedBox(width: 8),
              const Text('اتمام سفر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('آیا سفر به مقصد رسید و می‌خواهید آن را به پایان برسانید؟',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مبلغ کرایه دریافتی:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$price افغانی',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2E7D32))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('btn_cancel'.tr(), style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F7D55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await FirebaseFirestore.instance.collection('rides').doc(tripId).update({
                  'status': 'completed',
                  'completed_at': FieldValue.serverTimestamp(),
                });

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection("drivers").doc(user.uid).update({
                    "newTripStatus": "waiting",
                  });
                }

                context.read<NavigationController>().stopNavigation();
                if (mapController != null) {
                  await mapController!.clearLines();
                  if (driverSymbol != null) {
                    await mapController!.removeSymbol(driverSymbol!);
                    driverSymbol = null;
                  }
                }

                setState(() {
                  activeTripId = null;
                  activeTripStatus = null;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('سفر با موفقیت به پایان رسید.'),
                      backgroundColor: Color(0xFF0F7D55),
                    ),
                  );
                }
              },
              child: const Text('تأیید و دریافت کرایه', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelTrip(String tripId) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('لغو سفر', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('آیا از لغو این سفر اطمینان دارید؟ مسافر متوجه لغو سفر خواهد شد.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('btn_cancel'.tr(), style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                context.read<NavigationController>().stopNavigation();
                if (mapController != null) {
                  await mapController!.clearLines();
                  if (driverSymbol != null) {
                    await mapController!.removeSymbol(driverSymbol!);
                    driverSymbol = null;
                  }
                }

                await FirebaseFirestore.instance.collection('rides').doc(tripId).update({
                  'status': 'canceled',
                  'canceled_by': 'driver',
                  'canceled_at': FieldValue.serverTimestamp(),
                });

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection("drivers").doc(user.uid).update({
                    "newTripStatus": "waiting",
                  });
                }

                setState(() {
                  activeTripId = null;
                  activeTripStatus = null;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('سفر توسط شما لغو شد.'),
                      backgroundColor: Color(0xFFE53935),
                    ),
                  );
                }
              },
              child: const Text('بله، لغو شود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                    (!isDriverAvailable)
                        ? 'change_to_online_title'.tr()
                        : 'change_to_offline_title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
                                  setModalState(() => isLoading = true);

                                  try {
                                    if (!isDriverAvailable) {
                                      if (mounted) {
                                        setState(() => isDriverAvailable = true);
                                      }

                                      await _saveDriverStatus(true);
                                      await goOnlineNow();
                                      setAndGetLocationUpdates();
                                      listenForTripRequests();
                                    } else {
                                      await goOfflineNow();
                                      await _saveDriverStatus(false);

                                      if (mounted) {
                                        setState(() => isDriverAvailable = false);
                                      }
                                    }
                                  } finally {
                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                    }

                                    isLoading = false;
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
                          onPressed: () => Navigator.pop(modalContext),
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
    final currentUser = FirebaseAuth.instance.currentUser;

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
                zoom: 15.0,
              ),
              styleString: 'assets/map/style.json',
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.tracking,
              onMapCreated: _onMapCreated,
            ),

            Positioned(
              top: 20,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.small(
                  heroTag: 'recenter_btn',
                  elevation: 0,
                  backgroundColor: Colors.white,
                  onPressed: () => getCurrentLiveLocationOfDriver(),
                  child: const Icon(Icons.my_location_rounded, color: Color(0xFF0F7D55), size: 22),
                ),
              ),
            ),

            Positioned(
              top: 20,
              left: 16,
              child: Material(
                elevation: 4,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: _showStatusChangeModal,
                  borderRadius: BorderRadius.circular(30),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDriverAvailable ? const Color(0xFFE53935) : const Color(0xFF0F7D55),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDriverAvailable ? 'go_offline'.tr() : 'go_online'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (currentUser != null && isDriverAvailable)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rides')
                    .where('status', whereIn: ['accepted', 'arrived', 'ontrip', 'in_progress'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    DocumentSnapshot? activeTripDoc;

                    for (var doc in snapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      if (data['driverId'] == currentUser.uid || data['driver_id'] == currentUser.uid) {
                        activeTripDoc = doc;
                        break;
                      }
                    }

                    if (activeTripDoc == null) return const SizedBox.shrink();

                    var tripData = activeTripDoc.data() as Map<String, dynamic>;
                    String tripId = activeTripDoc.id;
                    String status = tripData['status'] ?? 'accepted';

                    if (activeTripId != tripId || activeTripStatus != status) {
                      activeTripId = tripId;
                      activeTripStatus = status;

                      if (status == 'accepted') {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _startPickupRoute(tripId, tripData);
                        });
                      } else if (status == 'ontrip' || status == 'in_progress') {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _startDestinationRoute(tripId, tripData);
                        });
                      }
                    }

                    String passengerName = tripData['userName'] ??
                        tripData['full_name'] ??
                        'passenger'.tr();
                    String passengerPhone =
                        tripData['userPhone'] ?? tripData['phone'] ?? '';
                    String passengerRating =
                        '${tripData['userRating'] ?? tripData['rating'] ?? '4.8'}';
                    String originAddress = tripData['originAddress'] ??
                        tripData['pickup_address'] ??
                        '';
                    String destinationAddress = tripData['destinationAddress'] ??
                        tripData['dropoff_address'] ??
                        '';
                    String duration = '${tripData['duration'] ?? '15'}';
                    String distance = '${tripData['distance'] ?? '5.2'}';
                    String price =
                        '${tripData['fareAmount'] ?? tripData['price'] ?? '120'}';

                    return DraggableScrollableSheet(
                      initialChildSize: 0.62,
                      minChildSize: 0.22,
                      maxChildSize: 0.90,
                      snap: true,
                      snapSizes: const [0.22, 0.62, 0.90],
                      builder: (context, scrollController) {
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, -6),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Center(
                                  child: Container(
                                    width: 44,
                                    height: 5,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F7D55).withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF0F7D55),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              passengerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  passengerRating,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  passengerPhone,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Material(
                                        color: const Color(0xFFE8F5E9),
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          onPressed: () => _makePhoneCall(passengerPhone),
                                          icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2E7D32), size: 22),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        children: [
                                          const Icon(Icons.circle, color: Color(0xFF0F7D55), size: 12),
                                          Container(
                                            height: 32,
                                            width: 2,
                                            color: Colors.grey.shade300,
                                          ),
                                          const Icon(Icons.location_on_rounded, color: Color(0xFFE53935), size: 16),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${'origin_label'.tr()}: $originAddress',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              '${'destination_label'.tr()}: $destinationAddress',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(child: _buildInfoCard('estimated_time_label'.tr(), '$duration min', Icons.access_time_rounded, Colors.orange)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildInfoCard('estimated_distance_label'.tr(), '$distance km', Icons.alt_route_rounded, Colors.blue)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildInfoCard('estimated_fare_label'.tr(), '$price AFN', Icons.account_balance_wallet_rounded, Colors.green)),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'msg_follow_navigation'.tr(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF795548),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F7D55),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      if (status == 'accepted') {
                                        _updateTripStatus(tripId, 'arrived', tripData);
                                      } else if (status == 'arrived') {
                                        _updateTripStatus(tripId, 'ontrip', tripData);
                                      } else if (status == 'ontrip' || status == 'in_progress') {
                                        _updateTripStatus(tripId, 'completed', tripData);
                                      }
                                    },
                                    child: Text(
                                      _getActionButtonTitle(status),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE3F2FD),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatPage(
                                                  tripId: tripId,
                                                  passengerName: passengerName,
                                                  passengerPhone: passengerPhone,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                                              color: Color(0xFF1E88E5), size: 18),
                                          label: Text(
                                            'btn_sms_chat'.tr(),
                                            style: const TextStyle(
                                              color: Color(0xFF1E88E5),
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (status != 'ontrip' && status != 'in_progress') ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SizedBox(
                                          height: 44,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFFEBEE),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () => _cancelTrip(tripId),
                                            child: Text(
                                              'btn_cancel_trip'.tr(),
                                              style: const TextStyle(
                                                color: Color(0xFFE53935),
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 10),

                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 1,
                                    ),
                                    onPressed: () async {
                                      LatLng? targetPos;
                                      if (status == 'accepted' || status == 'arrived') {
                                        targetPos = _extractLatLng(
                                          tripData, 
                                          ['originLatLng', 'pickup_location', 'pickupLatLng', 'origin'],
                                          latKey: 'from_lat',
                                          lngKey: 'from_lng',
                                        );
                                      } else {
                                        targetPos = _extractLatLng(
                                          tripData, 
                                          ['destinationLatLng', 'dropoff_location', 'dropoffLatLng', 'destination'],
                                          latKey: 'to_lat',
                                          lngKey: 'to_lng',
                                        );
                                      }

                                      if (targetPos != null) {
                                        await _openExternalMap(targetPos.latitude, targetPos.longitude);
                                      } else if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('مختصات مبدأ یا مقصد این سفر پیدا نشد.'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.near_me_rounded,
                                        color: Colors.white, size: 20),
                                    label: Text(
                                      (status == 'accepted' || status == 'arrived')
                                          ? 'btn_external_navigation_origin'.tr()
                                          : 'btn_external_navigation_destination'.tr(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getActionButtonTitle(String status) {
    switch (status) {
      case 'accepted':
        return 'btn_arrived_pickup'.tr();
      case 'arrived':
        return 'btn_start_trip'.tr();
      case 'ontrip':
      case 'in_progress':
        return 'btn_end_trip'.tr();
      default:
        return 'btn_arrived_pickup'.tr();
    }
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
