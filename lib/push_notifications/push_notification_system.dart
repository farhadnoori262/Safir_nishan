import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_notification_channel/flutter_notification_channel.dart';
import 'package:flutter_notification_channel/notification_importance.dart';
import 'package:latlong2/latlong.dart';
import 'package:safir_drivers/global/global.dart'; 
import 'package:safir_drivers/main.dart'; 
import 'package:safir_drivers/models/trip_details.dart'; 
import 'package:safir_drivers/widgets/notification_dialog.dart'; 

class PushNotificationSystem {
  FirebaseMessaging firebaseCloudMessaging = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<String?> generateDeviceRegistrationToken() async {
    String? deviceRecognitionToken = await firebaseCloudMessaging.getToken();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && deviceRecognitionToken != null) {
      await FirebaseFirestore.instance
          .collection("drivers")
          .doc(currentUser.uid)
          .set({
        "deviceToken": deviceRecognitionToken,
        "token": deviceRecognitionToken,
      }, SetOptions(merge: true));
    }
    
    await firebaseCloudMessaging.subscribeToTopic("drivers");
    await firebaseCloudMessaging.subscribeToTopic("users");
    return deviceRecognitionToken;
  }

  startListeningForNewNotification(BuildContext context) async {
    var result = await FlutterNotificationChannel().registerNotificationChannel(
      description: 'برای نمایش نوتیفیکیشن‌های درخواست سفر سفیر',
      id: 'safirDriversApp',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'Safir Drivers',
    );

    log('\nNotification Channel Result: $result');

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? messageRemote) {
      if (messageRemote != null) {
        String? tripID = _extractTripId(messageRemote);
        if (tripID != null) {
          log("Terminated Trip ID: $tripID");
          retrieveTripRequestInfo(tripID, context);
        }
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage? messageRemote) {
      if (messageRemote != null) {
        String? tripID = _extractTripId(messageRemote);
        if (tripID != null) {
          log("Foreground Trip ID: $tripID");
          retrieveTripRequestInfo(tripID, context);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? messageRemote) {
      if (messageRemote != null) {
        String? tripID = _extractTripId(messageRemote);
        if (tripID != null) {
          log("Background Trip ID: $tripID");
          retrieveTripRequestInfo(tripID, context);
        }
      }
    });
  }

  String? _extractTripId(RemoteMessage message) {
    return message.data["tripID"] ?? message.data["trip_id"] ?? message.data["ride_id"];
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  retrieveTripRequestInfo(String tripID, BuildContext context) async {
    final currentContext = navigatorKey.currentContext ?? context;

    try {
      DocumentSnapshot tripSnapshot = await FirebaseFirestore.instance
          .collection("rides")
          .doc(tripID)
          .get();

      if (!tripSnapshot.exists || tripSnapshot.data() == null) {
        log("Error: No document found in Firestore for tripID $tripID");
        return;
      }

      Map<String, dynamic> data = tripSnapshot.data() as Map<String, dynamic>;
      log("Firestore Trip Data: $data");

      final String tripStatus =
    data["status"]?.toString().trim().toLowerCase() ?? "";

if (tripStatus != "requested") {
  log(
    "Trip $tripID ignored. "
    "Current status: $tripStatus, expected: requested.",
  );
  return;
}

      // 🔴 ۲. فیلتر زمان: عدم نمایش سفرهای بیشتر از ۳ دقیقه پیش
      if (data["createdAt"] != null) {
        Timestamp createdTimestamp = data["createdAt"] as Timestamp;
        DateTime createdAt = createdTimestamp.toDate();
        DateTime now = DateTime.now();

        if (now.difference(createdAt).inMinutes > 3) {
          log("Trip $tripID is expired (created more than 3 minutes ago). Ignoring.");
          return;
        }
      }

      // پخش هشدار صوتی برای سفرهای معتبر
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('audio/alert-sound.mp3'));
      } catch (e) {
        log("Audio error: $e");
      }

      TripDetails tripDetailsInfo = TripDetails();

      // 📍 مبدأ
      if (data["from_lat"] != null && data["from_lng"] != null) {
        double? lat = _parseDouble(data["from_lat"]);
        double? lng = _parseDouble(data["from_lng"]);
        if (lat != null && lng != null) {
          tripDetailsInfo.pickUpLatLng = LatLng(lat, lng);
        }
      } else if (data["from"] is GeoPoint) {
        GeoPoint gp = data["from"] as GeoPoint;
        tripDetailsInfo.pickUpLatLng = LatLng(gp.latitude, gp.longitude);
      }

      tripDetailsInfo.pickupAddress = data["pickup_address"]?.toString() ?? data["pickUpAddress"]?.toString() ?? "";

      // 🏁 مقصد
      if (data["to_lat"] != null && data["to_lng"] != null) {
        double? lat = _parseDouble(data["to_lat"]);
        double? lng = _parseDouble(data["to_lng"]);
        if (lat != null && lng != null) {
          tripDetailsInfo.dropOffLatLng = LatLng(lat, lng);
        }
      } else if (data["to"] is GeoPoint) {
        GeoPoint gp = data["to"] as GeoPoint;
        tripDetailsInfo.dropOffLatLng = LatLng(gp.latitude, gp.longitude);
      }

      tripDetailsInfo.dropOffAddress = data["dropoff_address"]?.toString() ?? data["dropOffAddress"]?.toString() ?? "";

      // 👤 مشخصات مسافر و کرایه
      tripDetailsInfo.userName = data["full_name"]?.toString() ?? data["userName"]?.toString() ?? "";
      tripDetailsInfo.userPhone = data["phone"]?.toString() ?? data["userPhone"]?.toString() ?? "";
      
      bidAmount = data["bidAmount"]?.toString() ?? data["bid_amount"]?.toString() ?? "";
      fareAmount = data["fare"]?.toString() ?? data["fareAmount"]?.toString() ?? "";
      tripDetailsInfo.tripID = tripID;

      // 🔔 نمایش پاپ‌آپ فقط برای سفر معتبر
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => NotificationDialog(
          tripDetailsInfo: tripDetailsInfo,
          bidAmount: bidAmount,
          fareAmount: fareAmount,
        ),
      );
    } catch (e, stackTrace) {
      log("Error parsing trip request info from Firestore: $e\n$stackTrace");
    }
  }
}
