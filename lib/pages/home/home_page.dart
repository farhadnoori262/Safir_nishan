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

  StreamSubscription<Position>? positionStreamHomePage;
  StreamSubscription<QuerySnapshot>? tripRequestStream;

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  void listenForTripRequests() {
    tripRequestStream?.cancel();

    driverOnlineTimestamp = DateTime.now().subtract(const Duration(seconds: 10));

    tripRequestStream = FirebaseFirestore.instance
        .collection('rides')
        .where('status', isEqualTo: 'requested')
        .snapshots()
        .listen(
      (snapshot) {
        debugPrint("Total active trip requests found: ${snapshot.docs.length}");

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final String tripID = change.doc.id;
            final data = change.doc.data() as Map<String, dynamic>?;

            if (data == null) continue;

            final dynamic createdAtValue = data['created_at'] ?? data['createdAt'] ?? data['timestamp'];
            if (createdAtValue is Timestamp) {
              final DateTime tripTime = createdAtValue.toDate();
              if (driverOnlineTimestamp != null && tripTime.isBefore(driverOnlineTimestamp!)) {
                log("Trip $tripID is older than driver online time. Skipping.");
                continue;
              }
            }

            debugPrint("New valid trip request received: $tripID");

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
    await FirebaseFirestore.instance
        .collection("drivers")
        .doc(uid)
        .update({
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

      final navController = context.read<NavigationController>();
      if (navController.isNavigating) {
        navController.updateDriverPosition(
          LatLng(position.latitude, position.longitude),
          langCode: context.locale.languageCode,
        );
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
        await FirebaseFirestore.instance
            .collection("drivers")
            .doc(uid)
            .update({
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

  Future<void> startTripNavigation(LatLng driverPos, LatLng destinationPos) async {
    final navController = context.read<NavigationController>();

    final routePoints = await navController.startNavigation(
      driverPos,
      destinationPos,
      context.locale.languageCode,
    );

    if (routePoints.isNotEmpty && mapController != null) {
      await mapController!.clearLines();
      await mapController!.addLine(
        LineOptions(
          geometry: routePoints,
          lineColor: "#006837",
          lineWidth: 6.0,
          lineOpacity: 0.8,
        ),
      );
    }
  }

  Future<void> _updateTripStatus(String tripId, String newStatus, Map<String, dynamic> tripData) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(tripId).update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (currentPositionOfDriver != null) {
        LatLng driverLatLng = LatLng(currentPositionOfDriver!.latitude, currentPositionOfDriver!.longitude);

        if (newStatus == 'accepted') {
          GeoPoint? originPoint = tripData['originLatLng'] ?? tripData['pickup_location'];
          if (originPoint != null) {
            LatLng pickupLatLng = LatLng(originPoint.latitude, originPoint.longitude);
            await startTripNavigation(driverLatLng, pickupLatLng);
          }
        } else if (newStatus == 'arrived' || newStatus == 'ontrip') {
          GeoPoint? destinationPoint = tripData['destinationLatLng'] ?? tripData['dropoff_location'];
          if (destinationPoint != null) {
            LatLng dropoffLatLng = LatLng(destinationPoint.latitude, destinationPoint.longitude);
            await startTripNavigation(driverLatLng, dropoffLatLng);
          }
        } else if (newStatus == 'completed') {
          context.read<NavigationController>().stopNavigation();
          if (mapController != null) {
            await mapController!.clearLines();
          }
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
                          onPressed: isLoading
                              ? null
                              : () async {
                                  setModalState(() {
                                    isLoading = true;
                                  });

                                  try {
                                    if (!isDriverAvailable) {
                                      await goOnlineNow();
                                      setAndGetLocationUpdates();
                                      listenForTripRequests();
                                      await _saveDriverStatus(true);

                                      if (mounted) {
                                        setState(() {
                                          isDriverAvailable = true;
                                        });
                                      }
                                    } else {
                                      await goOfflineNow();
                                      await _saveDriverStatus(false);

                                      if (mounted) {
                                        setState(() {
                                          isDriverAvailable = false;
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint("Error changing status: $e");
                                  } finally {
                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                    }
                                    isLoading = false;
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
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'btn_confirm'.tr(),
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
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(modalContext),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'btn_cancel'.tr(),
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

            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (currentUser != null && isDriverAvailable)
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('rides')
                                  .where('driverId', isEqualTo: currentUser.uid)
                                  .where('status', whereIn: ['accepted', 'arrived', 'ontrip', 'in_progress'])
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                  var activeTripDoc = snapshot.data!.docs.first;
                                  var tripData = activeTripDoc.data() as Map<String, dynamic>;
                                  String tripId = activeTripDoc.id;
                                  String status = tripData['status'] ?? 'accepted';

                                  String passengerName = tripData['userName'] ?? tripData['full_name'] ?? 'passenger'.tr();
                                  String passengerPhone = tripData['userPhone'] ?? tripData['phone'] ?? '';
                                  String passengerRating = '${tripData['userRating'] ?? tripData['rating'] ?? '4.8'}';
                                  String originAddress = tripData['originAddress'] ?? tripData['pickup_address'] ?? 'مبدأ مشخص نشده';
                                  String destinationAddress = tripData['destinationAddress'] ?? tripData['dropoff_address'] ?? 'مقصد مشخص نشده';
                                  String duration = '${tripData['duration'] ?? '15'}';
                                  String distance = '${tripData['distance'] ?? '5.2'}';
                                  String price = '${tripData['fareAmount'] ?? tripData['price'] ?? '120'}';

                                  return Container(
                                    margin: const EdgeInsets.only(top: 40, bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            const CircleAvatar(
                                              radius: 24,
                                              backgroundColor: AppColors.primaryBrand,
                                              child: Icon(Icons.person, color: Colors.white, size: 28),
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
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        passengerRating,
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    'شماره تماس مسافر: $passengerPhone',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => _makePhoneCall(passengerPhone),
                                              icon: const Icon(Icons.phone, color: Colors.green, size: 26),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 20),

                                        Row(
                                          children: [
                                            Column(
                                              children: [
                                                const Icon(Icons.circle, color: Colors.green, size: 10),
                                                Container(height: 20, width: 2, color: Colors.grey.shade300),
                                                const Icon(Icons.location_on, color: Colors.red, size: 14),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'مبدأ: $originAddress',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'مقصد: $destinationAddress',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildInfoItem('زمان تخمینی', '$duration دقیقه', Icons.access_time),
                                              _buildInfoItem('مسافت', '$distance km', Icons.alt_route),
                                              _buildInfoItem('کرایه تخمینی', '$price AFN', Icons.payments_outlined),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        Consumer<NavigationController>(
                                          builder: (context, nav, child) {
                                            if (!nav.isNavigating || nav.instructionText.isEmpty) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF8E1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 16),
                                                    SizedBox(width: 8),
                                                    Text('لطفاً به موقع به مقصد برسید', style: TextStyle(fontSize: 11)),
                                                  ],
                                                ),
                                              );
                                            }

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E9),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFF006837), width: 1),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.navigation, color: Color(0xFF006837), size: 22),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      nav.instructionText,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF006837),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        SizedBox(
                                          width: double.infinity,
                                          height: 46,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF006837),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 36,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue[50],
                                                    elevation: 0,
                                                    padding: EdgeInsets.zero,
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
                                                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 16),
                                                  label: const Text('چت پیامکی', style: TextStyle(color: Colors.blue, fontSize: 11)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: SizedBox(
                                                height: 36,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.teal[50],
                                                    elevation: 0,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  onPressed: () {
                                                    // اکشن اشتراک موقعیت مکانی
                                                  },
                                                  icon: const Icon(Icons.share_location, color: Colors.teal, size: 16),
                                                  label: const Text('اشتراک موقعیت', style: TextStyle(color: Colors.teal, fontSize: 11)),
                                                ),
                                              ),
                                            ),
                                            if (status != 'ontrip' && status != 'in_progress') ...[
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: SizedBox(
                                                  height: 36,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red[50],
                                                      elevation: 0,
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                    onPressed: () => _cancelTrip(tripId),
                                                    child: const Text('لغو سفر', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isDriverAvailable
                                  ? Colors.red.shade900
                                  : AppColors.primaryBrand)
                              .withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _showStatusChangeModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDriverAvailable
                            ? Colors.red.shade600
                            : AppColors.primaryBrand,
                        foregroundColor: AppColors.buttonText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDriverAvailable
                                  ? Colors.greenAccent
                                  : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isDriverAvailable
                                ? 'go_offline'.tr()
                                : 'go_online'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getActionButtonTitle(String status) {
    switch (status) {
      case 'accepted':
        return 'من به مسافر رسیدم';
      case 'arrived':
        return 'شروع سفر (حرکت به مقصد)';
      case 'ontrip':
      case 'in_progress':
        return 'پایان سفر';
      default:
        return 'من به مسافر رسیدم';
    }
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
      ],
    );
  }
}
