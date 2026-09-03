import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart'; // 📌 ایمپورت پکیج اصلی ترجمه
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../global/global.dart';
import '../methods/common_method.dart';
import '../models/trip_details.dart';
import '../pages/NewTrip/new_trip_page.dart';
import 'loading_dialog.dart';

class NotificationDialog extends StatefulWidget {
  final TripDetails? tripDetailsInfo;
  final String? fareAmount;
  final String? bidAmount;

  const NotificationDialog({
    super.key,
    this.tripDetailsInfo,
    this.fareAmount,
    this.bidAmount,
  });

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  String tripRequestStatus = "";
  CommonMethods cMethods = CommonMethods();
  late Timer timer;

  // 🎨 پالت رنگی سفیر
  static const Color brandPrimary = Color(0xFF145A41);
  static const Color btnPrimary = Color(0xFF1B7A57);
  static const Color btnPressed = Color(0xFF0F4A35);
  static const Color cardBgLight = Color(0xFFEAF6F1);
  static const Color textOnBtn = Color(0xFFFFFFFF);

  cancelNotificationDialogAfter20Sec() {
    const oneTickPerSecond = Duration(seconds: 1);

    timer = Timer.periodic(oneTickPerSecond, (timer) {
      driverTripRequestTimeout = driverTripRequestTimeout - 1;

      if (tripRequestStatus == "accepted") {
        timer.cancel();
        driverTripRequestTimeout = 40;
        return;
      }

      if (driverTripRequestTimeout == 0) {
        timer.cancel();
        driverTripRequestTimeout = 40;
        try {
          audioPlayer.stop();
        } catch (e) {
          debugPrint("Audio stop error: $e");
        }

        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    cancelNotificationDialogAfter20Sec();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  checkAvailabilityOfTripRequest(BuildContext context) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(
        messageText: 'msg_please_wait'.tr(),
      ),
    );

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    String tripID = widget.tripDetailsInfo?.tripID ?? "";

    try {
      DocumentReference tripRef =
          FirebaseFirestore.instance.collection("rides").doc(tripID);

      DocumentSnapshot tripSnapshot = await tripRef.get();

      if (mounted) {
        Navigator.pop(context);
      }

      if (tripSnapshot.exists) {
        Map<String, dynamic>? data =
            tripSnapshot.data() as Map<String, dynamic>?;

        String currentStatus = data?["status"]?.toString() ?? "";

        if (currentStatus == "requested" || currentStatus == "waiting") {
          await tripRef.update({
            "status": "accepted",
            "driver_id": currentUser.uid,
            "accepted_at": FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance
              .collection("drivers")
              .doc(currentUser.uid)
              .update({
            "newTripStatus": "accepted",
          }).catchError((e) => debugPrint("Driver update error: $e"));

          cMethods.turnOffLocationUpdatesForHomePage();

          if (mounted) {
            Navigator.pop(context);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) =>
                    NewTripPage(newTripDetailsInfo: widget.tripDetailsInfo),
              ),
            );
          }
        } else if (currentStatus == "accepted") {
          if (mounted) {
            cMethods.displaySnackBar("این سفر قبلاً توسط راننده دیگری گرفته شده است.", context);
            Navigator.pop(context);
          }
        } else if (currentStatus == "cancelled") {
          if (mounted) {
            cMethods.displaySnackBar('err_trip_cancelled'.tr(), context);
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            cMethods.displaySnackBar('err_trip_not_found'.tr(), context);
            Navigator.pop(context);
          }
        }
      } else {
        if (mounted) {
          cMethods.displaySnackBar('err_trip_not_found'.tr(), context);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error accepting trip: $e");
      if (mounted) {
        cMethods.displaySnackBar("خطایی رخ داد. دوباره تلاش کنید.", context);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fareAmount = widget.fareAmount ?? "۰";
    final String currencyUnit = 'currency_unit'.tr();
    final String bidAmount =
    widget.bidAmount == "null" || widget.bidAmount == null || widget.bidAmount!.isEmpty
        ? 'no_bid_offer'.tr()
        : "${widget.bidAmount} $currencyUnit";

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.white,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: cardBgLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_taxi_rounded,
                color: brandPrimary,
                size: 38,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'title_new_trip_request'.tr(),
              style: const TextStyle(
                fontFamily: 'IranYekan',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 16),

            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: brandPrimary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'label_pickup_location'.tr(),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'IranYekan'),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.tripDetailsInfo?.pickupAddress ?? 'unknown_address'.tr(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'label_dropoff_location'.tr(),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'IranYekan'),
                          ),
                          Text(
                            widget.tripDetailsInfo?.dropOffAddress ?? 'unknown_address'.tr(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBgLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('label_standard_fare'.tr(), style: const TextStyle(fontFamily: 'IranYekan', color: Colors.black54, fontSize: 13)),
                      Text(
                        "$fareAmount $currencyUnit", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'IranYekan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('label_passenger_bid'.tr(), style: const TextStyle(fontFamily: 'IranYekan', color: Colors.black54, fontSize: 13)),
                      Text(bidAmount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: brandPrimary, fontFamily: 'IranYekan')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {
                        try {
                          audioPlayer.stop();
                        } catch (e) {
                          debugPrint("Audio error: $e");
                        }
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'btn_decline_trip'.tr(),
                        style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          audioPlayer.stop();
                        } catch (e) {
                          debugPrint("Audio error: $e");
                        }
                        setState(() {
                          tripRequestStatus = "accepted";
                        });
                        await checkAvailabilityOfTripRequest(context);
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.pressed)) {
                            return btnPressed;
                          }
                          return btnPrimary;
                        }),
                        elevation: WidgetStateProperty.all(0),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      child: Text(
                        'btn_accept_trip'.tr(),
                        style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 13, color: textOnBtn),
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
}
