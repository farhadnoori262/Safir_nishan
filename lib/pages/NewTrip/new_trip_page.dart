import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../global/global.dart';
import '../../methods/common_method.dart';
import '../../models/trip_details.dart';
import '../../utils/app_colors.dart';
import '../../widgets/loading_dialog.dart';
import '../../widgets/payment_dialog.dart';

class NewTripPage extends StatefulWidget {
  final TripDetails? newTripDetailsInfo;
  const NewTripPage({super.key, this.newTripDetailsInfo});

  @override
  State<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends State<NewTripPage> {
  String statusOfTrip = "accepted";
  String buttonTitleKey = "btn_arrived";
  Color buttonColor = AppColors.primaryButton;
  CommonMethods commonMethods = CommonMethods();

  // 🗺️ باز کردن مسیریاب‌های بیرونی
  Future<void> _openExternalNavigationApp(double lat, double lng) async {
    final Uri neshanUri = Uri.parse('neshan://navi?lat=$lat&lng=$lng');
    final Uri googleUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final Uri webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(neshanUri)) {
        await launchUrl(neshanUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(googleUri)) {
        await launchUrl(googleUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // 📡 ارسال موقعیت زنده راننده به فایربیس
  getLiveLocationUpdatesOfDriver() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    positionStreamNewTripPage = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position positionDriver) {
      driverCurrentPosition = positionDriver;

      if (widget.newTripDetailsInfo?.tripID != null) {
        FirebaseFirestore.instance
            .collection("rides")
            .doc(widget.newTripDetailsInfo!.tripID!)
            .update({
          "driverLocation": {
            "latitude": driverCurrentPosition!.latitude,
            "longitude": driverCurrentPosition!.longitude,
          },
          "driver_lat": driverCurrentPosition!.latitude,
          "driver_lng": driverCurrentPosition!.longitude,
        });
      }
    });
  }

  // 🏁 پایان سفر و محاسبه درآمد در Realtime Database
  endTripNow() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(
        messageText: 'ending_trip'.tr(),
      ),
    );

    String finalFareAmount = "0";
    if (bidAmount != "null" && bidAmount.isNotEmpty) {
      finalFareAmount = bidAmount.toString();
    } else {
      finalFareAmount = fareAmount.toString();
    }

    if (widget.newTripDetailsInfo?.tripID != null) {
      await FirebaseFirestore.instance
          .collection("rides")
          .doc(widget.newTripDetailsInfo!.tripID!)
          .update({
        "fareAmount": finalFareAmount,
        "fare": double.tryParse(finalFareAmount) ?? 0,
        "status": "ended",
      });
    }

    positionStreamNewTripPage?.cancel();

    if (mounted) Navigator.pop(context);

    displayLoadingDialog(finalFareAmount);
    await saveFareAmountToDriverTotalEearning(finalFareAmount);
  }

  displayLoadingDialog(faremmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => PaymentDialog(fareAmount: faremmount),
    );
  }

  // 💰 آپدیت درآمد راننده در Realtime Database
  Future<void> saveFareAmountToDriverTotalEearning(String fareAmount) async {
    String currentDriverUid = FirebaseAuth.instance.currentUser!.uid;
    DatabaseReference driverRef = FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(currentDriverUid);

    DataSnapshot snap = await driverRef.child("earnings").get();
    double fareAmountForThisAmount = double.tryParse(fareAmount) ?? 0.0;

    if (snap.exists && snap.value != null) {
      double previousTotalEarning =
          double.tryParse(snap.value.toString()) ?? 0.0;
      double newTotalEarning = previousTotalEarning + fareAmountForThisAmount;
      await driverRef.update({"earnings": newTotalEarning.toStringAsFixed(2)});
    } else {
      await driverRef.update({"earnings": fareAmountForThisAmount.toStringAsFixed(2)});
    }
  }

  // 🚗 دریافت مستقیم دیتا از Realtime Database و ذخیره پلاک کامل، عکس و نام در Firestore
  Future<void> saveDriverDataToTripInfo() async {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // دریافت اطلاعات به روز راننده از Realtime Database
      DatabaseReference driverRef =
          FirebaseDatabase.instance.ref().child("drivers").child(currentUid);
      DataSnapshot snapshot = await driverRef.get();

      String realDriverName = "";
      String realDriverPhone = "";
      String realDriverPhoto = "";
      String fullCarPlate = "";
      String carModelName = "";
      String carColorName = "";

      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        String fName = data['firstName'] ?? '';
        String sName = data['secondName'] ?? '';
        realDriverName = "$fName $sName".trim();
        realDriverPhone = data['phoneNumber'] ?? '';
        realDriverPhoto = data['profilePicture'] ?? '';

        // استخراج فیلدهای خودرو و پلاک کامل افغانستان
        var vehicle = data['vehicleInfo'];
        if (vehicle != null) {
          carModelName = vehicle['brand'] ?? '';
          carColorName = vehicle['color'] ?? '';
          
          String rawPlate = vehicle['registrationPlateNumber'] ?? '';
          String prov = vehicle['plateProvince'] ?? '';
          String cat = vehicle['plateCategory'] ?? '';
          String type = vehicle['plateType'] ?? '';

          if (prov.isNotEmpty && rawPlate.isNotEmpty) {
            fullCarPlate = "$prov - $cat $rawPlate ($type)";
          } else {
            fullCarPlate = rawPlate;
          }
        }
      }

      // ساخت مپ کامل داده‌ها
      Map<String, dynamic> driverDataMap = {
        "status": "accepted",
        "driverId": currentUid,
        "driver_id": currentUid,
        "driverName": realDriverName.isNotEmpty ? realDriverName : "$driverName $driverSecondName",
        "driver_name": realDriverName.isNotEmpty ? realDriverName : "$driverName $driverSecondName",
        "driverPhone": realDriverPhone.isNotEmpty ? realDriverPhone : driverPhone,
        "driver_phone": realDriverPhone.isNotEmpty ? realDriverPhone : driverPhone,
        "driverPhoto": realDriverPhoto.isNotEmpty ? realDriverPhoto : driverPhoto,
        "driver_photo": realDriverPhoto.isNotEmpty ? realDriverPhoto : driverPhoto,
        "carDetails": "$carModelName - $fullCarPlate - $carColorName",
        "car_details": "$carModelName - $fullCarPlate - $carColorName",
        "carNumber": fullCarPlate,
        "car_number": fullCarPlate,
      };

      if (driverCurrentPosition != null) {
        driverDataMap["driverLocation"] = {
          'latitude': driverCurrentPosition!.latitude,
          'longitude': driverCurrentPosition!.longitude,
        };
        driverDataMap["driver_lat"] = driverCurrentPosition!.latitude;
        driverDataMap["driver_lng"] = driverCurrentPosition!.longitude;
      }

      // آپدیت سند سفر در Firestore
      if (widget.newTripDetailsInfo?.tripID != null) {
        await FirebaseFirestore.instance
            .collection("rides")
            .doc(widget.newTripDetailsInfo!.tripID!)
            .update(driverDataMap);
      }
    } catch (e) {
      debugPrint("Error saving driver data to trip: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    saveDriverDataToTripInfo();
    getLiveLocationUpdatesOfDriver();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              "مدیریت سفر فعال",
              style: TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primaryBrand,
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // آدرس مبدأ
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, color: AppColors.primaryBrand, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("مبدأ مسافر:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.newTripDetailsInfo?.pickupAddress ?? "",
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 16),

                        // آدرس مقصد
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("مقصد مسافر:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.newTripDetailsInfo?.dropOffAddress ?? "",
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // 🧭 دکمه باز کردن مسیریاب خارجی (گوگل مپس / نشان)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            dynamic targetLocation = statusOfTrip == "accepted"
                                ? widget.newTripDetailsInfo?.pickUpLatLng
                                : widget.newTripDetailsInfo?.dropOffLatLng;


                            if (targetLocation != null && targetLocation.latitude != null && targetLocation.longitude != null) {
                              _openExternalNavigationApp(
                                targetLocation.latitude!,
                                targetLocation.longitude!,
                              );
                            } else {
                              commonMethods.displaySnackBar("مختصات مقصد یافت نشد!", context);
                            }
                          },
                          icon: const Icon(Icons.navigation_rounded, color: Colors.white),
                          label: Text(
                            statusOfTrip == "accepted"
                                ? "مسیریابی به مبدأ مسافر"
                                : "مسیریابی به مقصد",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'IranYekan',
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 🔘 دکمه وضعیت سفر (رسیدم / شروع سفر / پایان سفر)
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (statusOfTrip == "accepted") {
                                setState(() {
                                  buttonTitleKey = "btn_start_trip";
                                  buttonColor = AppColors.primaryBrand;
                                  statusOfTrip = "arrived";
                                });

                                if (widget.newTripDetailsInfo?.tripID != null) {
                                  await FirebaseFirestore.instance
                                      .collection("rides")
                                      .doc(widget.newTripDetailsInfo!.tripID!)
                                      .update({"status": "arrived"});
                                }
                              } else if (statusOfTrip == "arrived") {
                                setState(() {
                                  buttonTitleKey = "btn_end_trip";
                                  buttonColor = Colors.redAccent;
                                  statusOfTrip = "ontrip";
                                });

                                if (widget.newTripDetailsInfo?.tripID != null) {
                                  await FirebaseFirestore.instance
                                      .collection("rides")
                                      .doc(widget.newTripDetailsInfo!.tripID!)
                                      .update({"status": "ontrip"});
                                }
                              } else if (statusOfTrip == "ontrip") {
                                endTripNow();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: AppColors.buttonText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              buttonTitleKey.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'IranYekan',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
