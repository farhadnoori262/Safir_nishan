import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Position? currentPositionOfDriver;
  bool isDriverAvailable = false;
  bool isLoading = false;
  Timestamp? driverWentOnlineAt;

  StreamSubscription<Position>? positionStreamHomePage;
  StreamSubscription<QuerySnapshot>? tripRequestStream;

  void listenForTripRequests() {
  tripRequestStream?.cancel();

  final Timestamp? onlineTime = driverWentOnlineAt;

  if (onlineTime == null) {
    debugPrint(
      "Trip listener was not started because driver online time is null.",
    );
    return;
  }

  tripRequestStream = FirebaseFirestore.instance
      .collection('rides')
      .where('status', isEqualTo: 'requested')
      .where('createdAt', isGreaterThan: onlineTime)
      .snapshots()
      .listen(
    (snapshot) {
      debugPrint(
        "New requested rides after online: ${snapshot.docs.length}",
      );

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final String tripID = change.doc.id;

          debugPrint("New trip request received: $tripID");

          if (mounted && isDriverAvailable) {
            PushNotificationSystem()
                .retrieveTripRequestInfo(tripID, context);
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
    driverWentOnlineAt = Timestamp.now();

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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                isDriverAvailable
                    ? Icons.local_taxi_rounded
                    : Icons.do_not_disturb_on_rounded,
                size: 90,
                color: isDriverAvailable
                    ? AppColors.primaryBrand
                    : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                isDriverAvailable
                    ? 'online_title'.tr()
                    : 'offline_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isDriverAvailable
                    ? 'online_subtitle'.tr()
                    : 'offline_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),

              if (currentUser != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rides')
                      .where('driverId', isEqualTo: currentUser.uid)
                      .where('status',
                          whereIn: ['accepted', 'arrived', 'ontrip'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      var tripDoc = snapshot.data!.docs.first;
                      var tripData = tripDoc.data() as Map<String, dynamic>;
                      String tripId = tripDoc.id;
                      String passengerName =
                          tripData['userName'] ?? 'passenger'.tr();
                      String passengerPhone = tripData['userPhone'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: AppColors.primaryBrand,
                                  child:
                                      Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        passengerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'active_trip'.tr(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _makePhoneCall(passengerPhone),
                                  icon: const Icon(Icons.phone,
                                      color: Colors.green, size: 26),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
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
                              icon: const Icon(Icons.chat_bubble_rounded,
                                  size: 20),
                              label: Text('chat_with_passenger'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBrand,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

              Container(
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
