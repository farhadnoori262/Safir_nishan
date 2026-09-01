import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  StreamSubscription<Position>? positionStreamHomePage;
  StreamSubscription<QuerySnapshot>? tripRequestStream;

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
      setState(() {});
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

      if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
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
              // آیکون وضعیت راننده
              Icon(
                isDriverAvailable ? Icons.local_taxi_rounded : Icons.do_not_disturb_on_rounded,
                size: 90,
                color: isDriverAvailable ? AppColors.primaryBrand : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                isDriverAvailable
                    ? 'شما آنلاین هستید و آماده دریافت سفر'
                    : 'شما آفلاین هستید',
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
                    ? 'به محض ثبت درخواست در محدوده شما، اعلان ارسال می‌شود.'
                    : 'برای شروع دریافت سفرهای جدید، دکمه زیر را بزنید.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),

              // دکمه تغییر وضعیت آنلاین / آفلاین
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isDriverAvailable ? Colors.red.shade900 : AppColors.primaryBrand).withOpacity(0.25),
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
                          color: isDriverAvailable ? Colors.greenAccent : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isDriverAvailable 
                            ? 'status_offline_btn'.tr() 
                            : 'status_online_btn'.tr(),
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
