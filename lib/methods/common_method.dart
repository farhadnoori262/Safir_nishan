import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../global/global.dart';
import '../models/direction_details.dart';

class CommonMethods {
  /// بررسی وضعیت اتصال اینترنت راننده (سازگار با connectivity_plus 6.0+)
  Future<void> checkConnectivity(BuildContext context) async {
    final List<ConnectivityResult> connectionResults =
        await Connectivity().checkConnectivity();

    final bool hasConnection = connectionResults.contains(ConnectivityResult.wifi) ||
        connectionResults.contains(ConnectivityResult.mobile) ||
        connectionResults.contains(ConnectivityResult.ethernet);

    if (!hasConnection) {
      if (!context.mounted) return;
      displaySnackBar('no_internet_error'.tr(), context);
    }
  }

  /// نمایش پیام‌های سیستم با استایل یکنواخت سفیر
  void displaySnackBar(String message, BuildContext context) {
    if (!context.mounted) return;

    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// متد کمکی برای پشتیبانی از فراخوانی‌های قدیمی
  void showSnackBar(BuildContext context, String message) {
    displaySnackBar(message, context);
  }

  /// غیرفعال کردن موقت به‌روزرسانی زنده موقعیت
  void turnOffLocationUpdatesForHomePage() {
    positionStreamHomePage?.pause();
  }

  /// فعال کردن به‌روزرسانی زنده و ثبت موقعیت راننده در Geofire فایربیس
  void turnOnLocationUpdatesForHomePage() {
    positionStreamHomePage?.resume();

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentPos = driverCurrentPosition;

    if (currentUser != null && currentPos != null) {
      Geofire.setLocation(
        currentUser.uid,
        currentPos.latitude,
        currentPos.longitude,
      );
    }
  }

  /// متد عمومی ارسال درخواست به API
  static Future<dynamic> sendRequestToAPI(String apiUrl) async {
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("API Error: Status code ${response.statusCode}");
        return "error";
      }
    } catch (error) {
      debugPrint("HTTP Request Exception: $error");
      return "error";
    }
  }

  /// دریافت جزئیات و نقاط مسیر از سرویس مسیریابی OSRM
  static Future<DirectionDetails?> getDirectionDetailsFromAPI(
    LatLng source,
    LatLng destination,
  ) async {
    final String urlDirectionsAPI =
        "https://router.project-osrm.org/route/v1/driving/"
        "${source.longitude},${source.latitude};"
        "${destination.longitude},${destination.latitude}"
        "?overview=full&geometries=geojson";

    final responseFromAPI = await sendRequestToAPI(urlDirectionsAPI);

    if (responseFromAPI == "error" ||
        responseFromAPI == null ||
        responseFromAPI["routes"] == null ||
        (responseFromAPI["routes"] as List).isEmpty) {
      return null;
    }

    final detailsModel = DirectionDetails();
    final firstRoute = responseFromAPI["routes"][0];

    final double distanceInMeters = (firstRoute["distance"] as num).toDouble();
    final double durationInSeconds = (firstRoute["duration"] as num).toDouble();

    detailsModel.distanceValueDigits = distanceInMeters.round();
    detailsModel.durationValueDigits = durationInSeconds.round();

    final double distanceInKm = distanceInMeters / 1000;
    final double durationInMinutes = durationInSeconds / 60;

    detailsModel.distanceTextString = "${distanceInKm.toStringAsFixed(1)} km";
    detailsModel.durationTextString = "${durationInMinutes.round()} min";

    final List<dynamic> coordinates =
        firstRoute["geometry"]["coordinates"] as List<dynamic>;

    final List<LatLng> polylinePointsList = coordinates.map((point) {
      return LatLng(
        (point[1] as num).toDouble(),
        (point[0] as num).toDouble(),
      );
    }).toList();

    detailsModel.polylinePoints = polylinePointsList;

    return detailsModel;
  }

  /// فرمول هوشمند محاسبه کرایه سفیر بر اساس نوع خدمت و مسافت
  String calculateFareAmount(
    DirectionDetails directionDetails, {
    String vehicleCategory = "economic_car",
    double surgeMultiplier = 1.0,
  }) {
    double baseFare = 50.0;
    double perKmRate = 20.0;
    double perMinuteRate = 5.0;
    double minimumFare = 80.0;
    double bookingFee = 10.0;

    // تنظیم نرخ بر اساس نوع وسیله یا خدمت انتخاب‌شده
    switch (vehicleCategory) {
      case "modern_car":
        baseFare = 80.0;
        perKmRate = 30.0;
        perMinuteRate = 8.0;
        minimumFare = 130.0;
        break;

      case "motorbike":
        baseFare = 30.0;
        perKmRate = 12.0;
        perMinuteRate = 3.0;
        minimumFare = 50.0;
        break;

      case "cargo":
        baseFare = 100.0;
        perKmRate = 35.0;
        perMinuteRate = 10.0;
        minimumFare = 150.0;
        break;

      case "intercity":
        baseFare = 150.0;
        perKmRate = 25.0;
        perMinuteRate = 4.0;
        minimumFare = 300.0;
        break;

      case "economic_car":
      default:
        baseFare = 50.0;
        perKmRate = 20.0;
        perMinuteRate = 5.0;
        minimumFare = 80.0;
        break;
    }

    final double distanceInKm =
        (directionDetails.distanceValueDigits ?? 0) / 1000.0;
    final double durationInMinutes =
        (directionDetails.durationValueDigits ?? 0) / 60.0;

    final double totalDistanceFare = distanceInKm * perKmRate;
    final double totalDurationFare = durationInMinutes * perMinuteRate;

    double totalFare =
        (baseFare + totalDistanceFare + totalDurationFare + bookingFee) *
            surgeMultiplier;

    if (totalFare < minimumFare) {
      totalFare = minimumFare;
    }

    return totalFare.toStringAsFixed(0);
  }
}

/// نمونه متغیر عمومی جهت دسترسی سریع در برنامه
final CommonMethods commonMethods = CommonMethods();
