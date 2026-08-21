import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_notification_channel/flutter_notification_channel.dart';
import 'package:flutter_notification_channel/notification_importance.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:safir_drivers/global/global.dart'; 
import 'package:safir_drivers/main.dart'; 
import 'package:safir_drivers/models/trip_details.dart'; 
import 'package:safir_drivers/widgets/notification_dialog.dart'; 

class PushNotificationSystem {
  FirebaseMessaging firebaseCloudMessaging = FirebaseMessaging.instance;

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
    
    firebaseCloudMessaging.subscribeToTopic("drivers");
    firebaseCloudMessaging.subscribeToTopic("users");
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
        String? tripID = messageRemote.data["tripID"] ?? messageRemote.data["trip_id"] ?? messageRemote.data["ride_id"];
        if (tripID != null) {
          log("Terminated Trip ID: $tripID");
          retrieveTripRequestInfo(tripID, context);
        }
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage? messageRemote) {
      if (messageRemote != null) {
        String? tripID = messageRemote.data["tripID"] ?? messageRemote.data["trip_id"] ?? messageRemote.data["ride_id"];
        if (tripID != null) {
          log("Foreground Trip ID: $tripID");
          retrieveTripRequestInfo(tripID, context);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? messageRemote) {
      if (messageRemote != null) {
        String? tripID = messageRemote.data["tripID"] ?? messageRemote.data["trip_id"] ?? messageRemote.data["ride_id"];
        if (tripID != null) {
          log("Background Trip ID: $tripID");
          retrieveTripRequestInfo(tripID, context);
        }
      }
    });
  }

  retrieveTripRequestInfo(String tripID, BuildContext context) async {
    final currentContext = navigatorKey.currentContext ?? context;

    if (currentContext != null) {
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

        try {
          final player = AudioPlayer();
          player.play(AssetSource('audio/alert-sound.mp3'));
        } catch (e) {
          log("Audio error: $e");
        }

        TripDetails tripDetailsInfo = TripDetails();

        // 📍 ۱. مبدأ
        if (data["from_lat"] != null && data["from_lng"] != null) {
          double lat = double.parse(data["from_lat"].toString());
          double lng = double.parse(data["from_lng"].toString());
          tripDetailsInfo.pickUpLatLng = LatLng(lat, lng);
        } else if (data["from"] is GeoPoint) {
          GeoPoint gp = data["from"] as GeoPoint;
          tripDetailsInfo.pickUpLatLng = LatLng(gp.latitude, gp.longitude);
        }

        tripDetailsInfo.pickupAddress = data["pickup_address"]?.toString() ?? data["pickUpAddress"]?.toString() ?? "";

        // 🏁 ۲. مقصد
        if (data["to_lat"] != null && data["to_lng"] != null) {
          double lat = double.parse(data["to_lat"].toString());
          double lng = double.parse(data["to_lng"].toString());
          tripDetailsInfo.dropOffLatLng = LatLng(lat, lng);
        } else if (data["to"] is GeoPoint) {
          GeoPoint gp = data["to"] as GeoPoint;
          tripDetailsInfo.dropOffLatLng = LatLng(gp.latitude, gp.longitude);
        }

        tripDetailsInfo.dropOffAddress = data["dropoff_address"]?.toString() ?? data["dropOffAddress"]?.toString() ?? "";

        // 👤 ۳. مشخصات مسافر و کرایه
        tripDetailsInfo.userName = data["full_name"]?.toString() ?? data["userName"]?.toString() ?? "";
        tripDetailsInfo.userPhone = data["phone"]?.toString() ?? data["userPhone"]?.toString() ?? "";
        
        bidAmount = data["bidAmount"]?.toString() ?? data["bid_amount"]?.toString() ?? "";
        fareAmount = data["fare"]?.toString() ?? data["fareAmount"]?.toString() ?? "";
        tripDetailsInfo.tripID = tripID;

        // 🔔 ۴. نمایش پاپ‌آپ پذیرش سفر
        showDialog(
          context: currentContext,
          barrierDismissible: false,
          builder: (BuildContext context) => NotificationDialog(
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
}
