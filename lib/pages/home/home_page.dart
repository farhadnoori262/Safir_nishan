import 'dart:async';
import 'dart:developer';

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

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  void _animateMapToPosition(double lat, double lng) {
    mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(lat, lng)),
    );
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
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _drawRoutePolyline(List<LatLng> points) async {
    if (mapController == null || points.isEmpty) return;
    try {
      await mapController!.clearLines();
      await mapController!.addLine(
        LineOptions(
          geometry: points,
          lineColor: "#2196F3",
          lineWidth: 6.0,
          lineOpacity: 0.85,
          lineJoin: 'round',
        ),
      );
    } catch (e) {
      debugPrint("خطا در رسم خط مسیر: $e");
    }
  }

  Future<void> _startPickupRoute(
    String tripId,
    Map<String, dynamic> tripData,
  ) async {
    try {
      if (currentPositionOfDriver == null) {
        currentPositionOfDriver = await getCurrentLiveLocationOfDriver();
      }

      if (currentPositionOfDriver == null) return;

      final dynamic originPoint =
          tripData['originLatLng'] ?? tripData['pickup_location'];

      if (originPoint is! GeoPoint) return;

      final LatLng driverPosition = LatLng(
        currentPositionOfDriver!.latitude,
        currentPositionOfDriver!.longitude,
      );

      final LatLng pickupPosition = LatLng(
        originPoint.latitude,
        originPoint.longitude,
      );

      activeTripId = tripId;
      activeTripStatus = 'accepted';

      await startTripNavigation(driverPosition, pickupPosition);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ خطا در مسیر مبدأ: $e');
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
      await FirebaseFirestore.instance.collection('rides').doc(tripId).update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (currentPositionOfDriver != null) {
        LatLng driverLatLng = LatLng(
            currentPositionOfDriver!.latitude, currentPositionOfDriver!.longitude);

        if (newStatus == 'accepted') {
          GeoPoint? originPoint =
              tripData['originLatLng'] ?? tripData['pickup_location'];
          if (originPoint != null) {
            LatLng pickupLatLng =
                LatLng(originPoint.latitude, originPoint.longitude);
            await startTripNavigation(driverLatLng, pickupLatLng);
          }
        } else if (newStatus == 'arrived') {
          setState(() {
            activeTripStatus = 'arrived';
          });
        } else if (newStatus == 'ontrip' || newStatus == 'in_progress') {
          GeoPoint? destinationPoint =
              tripData['destinationLatLng'] ?? tripData['dropoff_location'];
          if (destinationPoint != null) {
            LatLng dropoffLatLng =
                LatLng(destinationPoint.latitude, destinationPoint.longitude);
            await startTripNavigation(driverLatLng, dropoffLatLng);
            setState(() {
              activeTripStatus = 'ontrip';
            });
          }
        } else if (newStatus == 'completed') {
          context.read<NavigationController>().stopNavigation();
          if (mapController != null) {
            await mapController!.clearLines();
          }
          setState(() {
            activeTripId = null;
            activeTripStatus = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Error updating trip status: $e");
    }
  }

  Future<void> _cancelTrip(String tripId) async {
    try {
      context.read<NavigationController>().stopNavigation();
      if (mapController != null) {
        await mapController!.clearLines();
      }

      await FirebaseFirestore.instance.collection('rides').doc(tripId).update({
        'status': 'canceled',
        'canceled_by': 'driver',
        'canceled_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        activeTripId = null;
        activeTripStatus = null;
      });
    } catch (e) {
      debugPrint("Error canceling trip: $e");
    }
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
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
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
                  Text(
                    (!isDriverAvailable)
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
                                    }
                                    } else {
                                      await goOfflineNow();
                                      await _saveDriverStatus(false);
                                      if (mounted) setState(() => isDriverAvailable = false);
                                    }
                                  } finally {
                                    if (modalContext.mounted) Navigator.pop(modalContext);
                                    isLoading = false;
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDriverAvailable
                                ? Colors.red.shade700
                                : AppColors.primaryButton,
                          ),
                          child: Text('btn_confirm'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(modalContext),
                          child: Text('btn_cancel'.tr()),
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
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter_btn',
                backgroundColor: Colors.white,
                onPressed: () => getCurrentLiveLocationOfDriver(),
                child: const Icon(Icons.my_location, color: AppColors.primaryBrand),
              ),
            ),

            Positioned(
              top: 16,
              left: 16,
              child: ElevatedButton(
                onPressed: _showStatusChangeModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDriverAvailable
                      ? Colors.red.shade600
                      : AppColors.primaryBrand,
                ),
                child: Text(
                  isDriverAvailable ? 'go_offline'.tr() : 'go_online'.tr(),
                ),
              ),
            ),

            if (currentUser != null && isDriverAvailable)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rides')
                    .where('driverId', isEqualTo: currentUser.uid)
                    .where('status', whereIn: [
                  'accepted',
                  'arrived',
                  'ontrip',
                  'in_progress'
                ]).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    var activeTripDoc = snapshot.data!.docs.first;
                    var tripData = activeTripDoc.data() as Map<String, dynamic>;
                    String tripId = activeTripDoc.id;
                    String status = tripData['status'] ?? 'accepted';

                    if (status == 'accepted' && activeTripId != tripId) {
                      _startPickupRoute(tripId, tripData);
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
                      initialChildSize: 0.60,
                      minChildSize: 0.20,
                      maxChildSize: 0.88,
                      snap: true,
                      snapSizes: const [0.20, 0.60, 0.88],
                      builder: (context, scrollController) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 15,
                                offset: Offset(0, -3),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                // ۱. مشخصات مسافر
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.green.shade700,
                                      child: const Icon(Icons.person, color: Colors.white, size: 26),
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
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 15),
                                              const SizedBox(width: 4),
                                              Text(
                                                passengerRating,
                                                style: const TextStyle(
                                                    fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${'passenger_phone_label'.tr()}: $passengerPhone',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _makePhoneCall(passengerPhone),
                                      icon: const Icon(Icons.phone, color: Colors.green, size: 24),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                // ۲. آدرس مبدأ و مقصد
                                Row(
                                  children: [
                                    Column(
                                      children: [
                                        const Icon(Icons.circle, color: Colors.green, size: 8),
                                        Container(height: 18, width: 2, color: Colors.grey.shade300),
                                        const Icon(Icons.location_on, color: Colors.red, size: 12),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${'origin_label'.tr()}: $originAddress',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12)),
                                          const SizedBox(height: 6),
                                          Text('${'destination_label'.tr()}: $destinationAddress',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // ۳. قیمت و مسافت
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildInfoItem('estimated_time_label'.tr(), '$duration min', Icons.access_time),
                                      _buildInfoItem('estimated_distance_label'.tr(), '$distance km', Icons.alt_route),
                                      _buildInfoItem('estimated_fare_label'.tr(), '$price AFN', Icons.payments_outlined),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // کادر راهنما
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'msg_follow_navigation'.tr(),
                                          style: const TextStyle(fontSize: 11, color: Colors.brown),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // ۴. دکمه اصلی عملیات سفر (سبز رنگ)
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF006837),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // ۵. دکمه‌های چت و لغو
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 38,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[50],
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8)),
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
                                          icon: const Icon(Icons.chat_bubble_outline,
                                              color: Colors.blue, size: 16),
                                          label: Text('btn_sms_chat'.tr(),
                                              style: const TextStyle(
                                                  color: Colors.blue, fontSize: 11)),
                                        ),
                                      ),
                                    ),
                                    if (status != 'ontrip' && status != 'in_progress') ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SizedBox(
                                          height: 38,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[50],
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _cancelTrip(tripId),
                                            child: Text('btn_cancel_trip'.tr(),
                                                style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // 🔹 ۶. دکمه آبی مسیریابی خارجی (پایین‌ترین بخش کشو)
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      GeoPoint? targetPoint;
                                      if (status == 'accepted' || status == 'arrived') {
                                        targetPoint = tripData['originLatLng'] ??
                                            tripData['pickup_location'];
                                      } else {
                                        targetPoint = tripData['destinationLatLng'] ??
                                            tripData['dropoff_location'];
                                      }
                                      if (targetPoint != null) {
                                        _openExternalMap(
                                            targetPoint.latitude, targetPoint.longitude);
                                      }
                                    },
                                    icon: const Icon(Icons.navigation_outlined,
                                        color: Colors.white, size: 18),
                                    label: Text(
                                      (status == 'accepted' || status == 'arrived')
                                          ? 'btn_external_navigation_origin'.tr()
                                          : 'btn_external_navigation_destination'.tr(),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
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

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
      ],
    );
  }
}
