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
  final FirebaseMessaging firebaseCloudMessaging = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isTripDialogOpen = false;
  String? _shownTripId;

  Future<String?> generateDeviceRegistrationToken() async {
    final NotificationSettings settings =
        await firebaseCloudMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('Notification permission: ${settings.authorizationStatus}');

    final String? deviceRecognitionToken =
        await firebaseCloudMessaging.getToken();

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && deviceRecognitionToken != null) {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(currentUser.uid)
          .set(
        {
          'deviceToken': deviceRecognitionToken,
          'token': deviceRecognitionToken,
        },
        SetOptions(merge: true),
      );
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .set(
        {
          'deviceToken': newToken,
          'token': newToken,
        },
        SetOptions(merge: true),
      );

      log('FCM token refreshed and saved for driver: ${user.uid}');
    });

    await firebaseCloudMessaging.subscribeToTopic('drivers');
    await firebaseCloudMessaging.subscribeToTopic('users');

    log('Driver FCM token: $deviceRecognitionToken');

    return deviceRecognitionToken;
  }

  Future<void> startListeningForNewNotification(
    BuildContext context,
  ) async {
    final result =
        await FlutterNotificationChannel().registerNotificationChannel(
      description: 'برای نمایش نوتیفیکیشن‌های درخواست سفر سفیر',
      id: 'safirDriversApp',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'Safir Drivers',
    );

    log('Notification Channel Result: $result');

    FirebaseMessaging.instance.getInitialMessage().then(
      (RemoteMessage? messageRemote) {
        if (messageRemote == null) return;

        final String? tripID = _extractTripId(messageRemote);
        if (tripID != null) {
          log('Terminated Trip ID: $tripID');
          retrieveTripRequestInfo(tripID, context);
        }
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage messageRemote) {
      final String? tripID = _extractTripId(messageRemote);

      if (tripID != null) {
        log('Foreground Trip ID: $tripID');
        retrieveTripRequestInfo(tripID, context);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage messageRemote) {
        final String? tripID = _extractTripId(messageRemote);

        if (tripID != null) {
          log('Background Trip ID: $tripID');
          retrieveTripRequestInfo(tripID, context);
        }
      },
    );
  }

  String? _extractTripId(RemoteMessage message) {
    return message.data['tripID'] ??
        message.data['trip_id'] ??
        message.data['ride_id'];
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _startTripAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      await _audioPlayer.play(
        AssetSource('audio/fa/alert-sound.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      log('Audio error: $e');
    }
  }

  Future<void> _stopTripAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      log('Stop audio error: $e');
    }
  }

  Future<void> retrieveTripRequestInfo(
    String tripID,
    BuildContext context,
  ) async {
    final BuildContext currentContext = navigatorKey.currentContext ?? context;

    if (_isTripDialogOpen && _shownTripId == tripID) {
      log('Trip dialog is already open: $tripID');
      return;
    }

    try {
      final DocumentSnapshot tripSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripID)
          .get();

      if (!tripSnapshot.exists || tripSnapshot.data() == null) {
        log('No document found in Firestore for tripID: $tripID');
        return;
      }

      final Map<String, dynamic> data =
          tripSnapshot.data() as Map<String, dynamic>;

      log('Firestore Trip Data: $data');

      final String tripStatus =
          data['status']?.toString().trim().toLowerCase() ?? '';

      if (tripStatus != 'searching') {
        log('Trip $tripID ignored. Current status: $tripStatus');
        return;
      }

      final dynamic createdAtValue =
          data['created_at'] ?? data['createdAt'] ?? data['timestamp'];

      if (createdAtValue is Timestamp) {
        final DateTime createdAt = createdAtValue.toDate();

        if (DateTime.now().difference(createdAt).inMinutes > 5) {
          log('Trip $tripID is expired. Ignoring.');
          return;
        }
      }

      final TripDetails tripDetailsInfo = TripDetails();

      if (data['from_lat'] != null && data['from_lng'] != null) {
        final double? lat = _parseDouble(data['from_lat']);
        final double? lng = _parseDouble(data['from_lng']);

        if (lat != null && lng != null) {
          tripDetailsInfo.pickUpLatLng = LatLng(lat, lng);
        }
      } else if (data['from'] is GeoPoint) {
        final GeoPoint geoPoint = data['from'] as GeoPoint;
        tripDetailsInfo.pickUpLatLng =
            LatLng(geoPoint.latitude, geoPoint.longitude);
      } else if (data['originLatLng'] is GeoPoint) {
        final GeoPoint geoPoint = data['originLatLng'] as GeoPoint;
        tripDetailsInfo.pickUpLatLng =
            LatLng(geoPoint.latitude, geoPoint.longitude);
      } else if (data['origin'] is Map) {
        final Map origin = data['origin'] as Map;
        final double? lat = _parseDouble(origin['latitude']);
        final double? lng = _parseDouble(origin['longitude']);

        if (lat != null && lng != null) {
          tripDetailsInfo.pickUpLatLng = LatLng(lat, lng);
        }
      }

      tripDetailsInfo.pickupAddress =
          data['pickup_address']?.toString() ??
              data['pickUpAddress']?.toString() ??
              data['originAddress']?.toString() ??
              data['origin_address']?.toString() ??
              'مبدأ نامشخص';

      if (data['to_lat'] != null && data['to_lng'] != null) {
        final double? lat = _parseDouble(data['to_lat']);
        final double? lng = _parseDouble(data['to_lng']);

        if (lat != null && lng != null) {
          tripDetailsInfo.dropOffLatLng = LatLng(lat, lng);
        }
      } else if (data['to'] is GeoPoint) {
        final GeoPoint geoPoint = data['to'] as GeoPoint;
        tripDetailsInfo.dropOffLatLng =
            LatLng(geoPoint.latitude, geoPoint.longitude);
      } else if (data['destinationLatLng'] is GeoPoint) {
        final GeoPoint geoPoint = data['destinationLatLng'] as GeoPoint;
        tripDetailsInfo.dropOffLatLng =
            LatLng(geoPoint.latitude, geoPoint.longitude);
      } else if (data['destination'] is Map) {
        final Map destination = data['destination'] as Map;
        final double? lat = _parseDouble(destination['latitude']);
        final double? lng = _parseDouble(destination['longitude']);

        if (lat != null && lng != null) {
          tripDetailsInfo.dropOffLatLng = LatLng(lat, lng);
        }
      }

      tripDetailsInfo.dropOffAddress =
          data['dropoff_address']?.toString() ??
              data['dropOffAddress']?.toString() ??
              data['destinationAddress']?.toString() ??
              data['destination_address']?.toString() ??
              'مقصد نامشخص';

      tripDetailsInfo.userName =
          data['userName']?.toString() ??
              data['passenger_name']?.toString() ??
              data['full_name']?.toString() ??
              data['passengerName']?.toString() ??
              'مسافر';

      tripDetailsInfo.userPhone =
          data['userPhone']?.toString() ??
              data['passenger_phone']?.toString() ??
              data['phone']?.toString() ??
              data['passengerPhone']?.toString() ??
              '';

      bidAmount = data['bidAmount']?.toString() ??
          data['bid_amount']?.toString() ??
          '';

      fareAmount = data['fare']?.toString() ??
          data['fareAmount']?.toString() ??
          data['price']?.toString() ??
          '';

      tripDetailsInfo.tripID = tripID;

      _isTripDialogOpen = true;
      _shownTripId = tripID;

      await _startTripAlertSound();

try {
  await showDialog(
    context: currentContext,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return NotificationDialog(
        tripDetailsInfo: tripDetailsInfo,
        bidAmount: bidAmount,
        fareAmount: fareAmount,
      );
    },
  );
} finally {
  await _stopTripAlertSound();
  _isTripDialogOpen = false;
  _shownTripId = null;
}
} catch (e, stackTrace) {
  await _stopTripAlertSound();
  _isTripDialogOpen = false;
  _shownTripId = null;

  log('Error parsing trip request info from Firestore: $e
$stackTrace');
}
}
}
