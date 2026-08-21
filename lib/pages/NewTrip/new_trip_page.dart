import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart'; // 📌 پکیج جدید نقشه
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/methods/map_theme_methods.dart';
import 'package:safir_drivers/models/trip_details.dart';
import 'package:safir_drivers/widgets/loading_dialog.dart';
import 'package:safir_drivers/widgets/payment_dialog.dart';

import '../../global/global.dart';
import '../../utils/lang_helper.dart';

class NewTripPage extends StatefulWidget {
  final TripDetails? newTripDetailsInfo;
  const NewTripPage({super.key, this.newTripDetailsInfo});

  @override
  State<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends State<NewTripPage> {
  MapLibreMapController? mapController;

  MapThemeMethods themeMethods = MapThemeMethods();

  List<LatLng> polylinePointsList = [];
  bool directionRequested = false;
  String statusOfTrip = "accepted";
  String durationText = "";
  String distanceText = "";
  double driverHeading = 0.0;

  String buttonTitleKey = "btn_arrived";

  // 🎨 پالت رنگی رسمی سفیر
  static const Color brandPrimary = Color(0xFF145A41);
  static const Color btnPrimary = Color(0xFF1B7A57);
  static const Color btnArrived = Color(0xFF0F4A35);
  static const Color btnEndTrip = Color(0xFFD32F2F);

  Color buttonColor = btnPrimary;
  CommonMethods commonMethods = CommonMethods();

  // 📐 محاسبه زاویه چرخش آیکون خودرو (Heading)
  double calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lng1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double lng2 = end.longitude * math.pi / 180;

    double dLng = lng2 - lng1;
    double y = math.sin(dLng) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    double brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
  }

  // 🗺️ دریافت مسیر و رسم Polyline روی MapLibre
  obtainDirectionAndDrawRoute(
      LatLng sourceLocationLatLng, LatLng destinationLocationLatLng) async {
    try {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) => LoadingDialog(
          messageText: tr(context, 'please_wait'),
        ),
      );

      var tripDetailsInfo = await CommonMethods.getDirectionDetailsFromAPI(
          sourceLocationLatLng, destinationLocationLatLng);

      if (mounted) Navigator.pop(context);

      if (tripDetailsInfo == null || tripDetailsInfo.polylinePoints == null) {
        return;
      }

      setState(() {
        polylinePointsList = tripDetailsInfo.polylinePoints!;
        durationText = tripDetailsInfo.durationTextString ?? "";
        distanceText = tripDetailsInfo.distanceTextString ?? "";
      });

      // رسم خط مسیر روی MapLibre
      if (mapController != null) {
        await mapController!.clearLines();
        await mapController!.addLine(
          LineOptions(
            geometry: polylinePointsList,
            lineColor: "#145A41",
            lineWidth: 5.0,
          ),
        );

        // جابه‌جایی دوربین روی مبدأ
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(sourceLocationLatLng, 15.5),
        );
      }
    } catch (e) {
      debugPrint("Error in obtainDirectionAndDrawRoute: $e");
    }
  }

  getLiveLocationUpdatesOfDriver() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    positionStreamNewTripPage = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position positionDriver) {
      if (driverCurrentPosition != null) {
        LatLng oldPos = LatLng(
            driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);
        LatLng newPos =
            LatLng(positionDriver.latitude, positionDriver.longitude);
        driverHeading = calculateBearing(oldPos, newPos);
      }

      driverCurrentPosition = positionDriver;

      LatLng driverCurrentPositionLatLng = LatLng(
          driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: driverCurrentPositionLatLng,
              zoom: 16.0,
              bearing: driverHeading,
            ),
          ),
        );
      }

      updateTripDetailsInformation();

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
          "driver_heading": driverHeading,
        });
      }
    });
  }

  updateTripDetailsInformation() async {
    if (!directionRequested) {
      directionRequested = true;

      if (driverCurrentPosition == null) return;

      var driverLocationLatLng = LatLng(
          driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);

      LatLng dropOffDestinationLocationLatLng;
      if (statusOfTrip == "accepted") {
        dropOffDestinationLocationLatLng =
            widget.newTripDetailsInfo!.pickUpLatLng!;
      } else {
        dropOffDestinationLocationLatLng =
            widget.newTripDetailsInfo!.dropOffLatLng!;
      }

      var directionDetailsInfo = await CommonMethods.getDirectionDetailsFromAPI(
          driverLocationLatLng, dropOffDestinationLocationLatLng);

      if (directionDetailsInfo != null) {
        directionRequested = false;

        if (mounted) {
          setState(() {
            durationText = directionDetailsInfo.durationTextString!;
            distanceText = directionDetailsInfo.distanceTextString!;
          });
        }
      }
    }
  }

  // 🏁 پایان سفر و محاسبه درآمد
  endTripNow() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(
        messageText: tr(context, 'ending_trip'),
      ),
    );

    var driverCurrentLocationLatLng = LatLng(
        driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);
    await CommonMethods.getDirectionDetailsFromAPI(
        widget.newTripDetailsInfo!.pickUpLatLng!,
        driverCurrentLocationLatLng);
    if (mounted) Navigator.pop(context);

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

    positionStreamNewTripPage!.cancel();

    displayLoadingDialog(finalFareAmount);

    saveFareAmountToDriverTotalEearning(finalFareAmount);
  }

  displayLoadingDialog(faremmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => PaymentDialog(fareAmount: faremmount),
    );
  }

  saveFareAmountToDriverTotalEearning(String fareAmount) async {
    String currentDriverUid = FirebaseAuth.instance.currentUser!.uid;
    DocumentReference driverRef = FirebaseFirestore.instance
        .collection("drivers")
        .doc(currentDriverUid);

    DocumentSnapshot snap = await driverRef.get();
    double fareAmountForThisAmount = double.tryParse(fareAmount) ?? 0.0;

    if (snap.exists && snap.data() != null) {
      var data = snap.data() as Map<String, dynamic>;
      double previousTotalEarning =
          double.tryParse(data["earnings"]?.toString() ?? "0") ?? 0.0;
      double newTotalEarning = previousTotalEarning + fareAmountForThisAmount;
      await driverRef.update({"earnings": newTotalEarning});
    } else {
      await driverRef.set({"earnings": fareAmountForThisAmount}, SetOptions(merge: true));
    }
  }

  saveDriverDataToTripInfo() async {
    Map<String, dynamic> driverDataMap = {
      "status": "accepted",
      "driverId": FirebaseAuth.instance.currentUser!.uid,
      "driver_id": FirebaseAuth.instance.currentUser!.uid,
      "driverName": "$driverName $driverSecondName",
      "driver_name": "$driverName $driverSecondName",
      "driverPhone": driverPhone,
      "driver_phone": driverPhone,
      "driverPhoto": driverPhoto,
      "driver_photo": driverPhoto,
      "carDetails": "$carModel - $carNumber - $carColor",
      "car_details": "$carModel - $carNumber - $carColor",
    };

    if (driverCurrentPosition != null) {
      driverDataMap["driverLocation"] = {
        'latitude': driverCurrentPosition!.latitude,
        'longitude': driverCurrentPosition!.longitude,
      };
      driverDataMap["driver_lat"] = driverCurrentPosition!.latitude;
      driverDataMap["driver_lng"] = driverCurrentPosition!.longitude;
    }

    if (widget.newTripDetailsInfo?.tripID != null) {
      await FirebaseFirestore.instance
          .collection("rides")
          .doc(widget.newTripDetailsInfo!.tripID!)
          .update(driverDataMap);
    }
  }

  @override
  void initState() {
    super.initState();
    saveDriverDataToTripInfo();
    getLiveLocationUpdatesOfDriver();
  }

  void _onMapCreated(MapLibreMapController controller) {

    mapController = controller;

    // رسم مسیر اولیه از مکان راننده به سمت مبدأ مسافر
    if (driverCurrentPosition != null &&
        widget.newTripDetailsInfo?.pickUpLatLng != null) {
      obtainDirectionAndDrawRoute(
        LatLng(driverCurrentPosition!.latitude,
            driverCurrentPosition!.longitude),
        widget.newTripDetailsInfo!.pickUpLatLng!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng initialMapCenter;
    if (driverCurrentPosition != null) {
      initialMapCenter = LatLng(
          driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);
    } else {
      initialMapCenter = const LatLng(34.5553, 69.2075);
    }

    return Directionality(
      textDirection: Directionality.of(context),
      child: SafeArea(
        child: Scaffold(
          body: Stack(
            children: [
              // 🗺️ نقشه وکتوری جدید سفیر با MapLibre
              MapLibreMap(
                initialCameraPosition: CameraPosition(
                  target: initialMapCenter,
                  zoom: 15.5,
                ),
                styleString: 'assets/map/style.json',
                onMapCreated: _onMapCreated,
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.tracking,
              ),

              // 📇 کارت مدرن اطلاعات سفیر در پایین صفحه
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // نشانگر فاصله و زمان
                        if (durationText.isNotEmpty || distanceText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF6F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 16, color: brandPrimary),
                                const SizedBox(width: 6),
                                Text(
                                  "$durationText ($distanceText)",
                                  style: const TextStyle(
                                    fontFamily: 'IranYekan',
                                    color: brandPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: Colors.grey.shade200),
                        const SizedBox(height: 12),

                        // آدرس مبدأ
                        Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 10, color: brandPrimary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.newTripDetailsInfo!.pickupAddress ?? "",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'IranYekan',
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // آدرس مقصد
                        Row(
                          children: [
                            const Icon(Icons.square,
                                size: 10, color: Colors.redAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.newTripDetailsInfo!.dropOffAddress ?? "",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'IranYekan',
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // دکمه تغییر وضعیت سفر (رسیدم / شروع سفر / پایان سفر)
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (statusOfTrip == "accepted") {
                                setState(() {
                                  buttonTitleKey = "btn_start_trip";
                                  buttonColor = btnArrived;
                                  statusOfTrip = "arrived";
                                });

                                if (widget.newTripDetailsInfo?.tripID != null) {
                                  await FirebaseFirestore.instance
                                      .collection("rides")
                                      .doc(widget.newTripDetailsInfo!.tripID!)
                                      .update({"status": "arrived"});
                                }

                                await obtainDirectionAndDrawRoute(
                                  widget.newTripDetailsInfo!.pickUpLatLng!,
                                  widget.newTripDetailsInfo!.dropOffLatLng!,
                                );
                              } else if (statusOfTrip == "arrived") {
                                setState(() {
                                  buttonTitleKey = "btn_end_trip";
                                  buttonColor = btnEndTrip;
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
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              tr(context, buttonTitleKey),
                              style: const TextStyle(
                                fontFamily: 'IranYekan',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
