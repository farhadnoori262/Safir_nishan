import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TripDetails {
  String? tripID;          // شناسه یا آی‌دی منحصربه‌فرد سفر

  LatLng? pickUpLatLng;    // مختصات جغرافیایی مبدأ (محل سوار شدن مسافر)
  String? pickupAddress;   // آدرس متنی مبدأ

  LatLng? dropOffLatLng;   // مختصات جغرافیایی مقصد (محل پیاده شدن مسافر)
  String? dropOffAddress;  // آدرس متنی مقصد

  String? userName;        // نام مسافر درخواست‌کننده سفیر
  String? userPhone;       // شماره تماس مسافر برای هماهنگی راننده

  TripDetails({
    this.tripID,
    this.pickUpLatLng,
    this.pickupAddress,
    this.dropOffLatLng,
    this.dropOffAddress,
    this.userName,
    this.userPhone,
  });

  /// دریافت آدرس مبدأ با پشتیبانی از چندزبانه بودن در صورت نبود آدرس
  String getPickupAddress(BuildContext context) {
    if (pickupAddress != null && pickupAddress!.trim().isNotEmpty) {
      return pickupAddress!;
    }
    return 'unknown_pickup_location'.tr();
  }

  /// دریافت آدرس مقصد با پشتیبانی از چندزبانه بودن در صورت نبود آدرس
  String getDropOffAddress(BuildContext context) {
    if (dropOffAddress != null && dropOffAddress!.trim().isNotEmpty) {
      return dropOffAddress!;
    }
    return 'unknown_dropoff_location'.tr();
  }

  /// دریافت نام مسافر (در صورت خالی بودن، عبارت "مسافر سفیر" را برمی‌گرداند)
  String getUserName(BuildContext context) {
    if (userName != null && userName!.trim().isNotEmpty) {
      return userName!;
    }
    return 'passenger_default_name'.tr();
  }

  // ساختن مدل از اطلاعات فایربیس یا سوکت
  factory TripDetails.fromMap(Map<String, dynamic> map, String tripId) {
    return TripDetails(
      tripID: tripId,
      pickupAddress: map['pickup_address'] ?? map['pickupAddress'],
      dropOffAddress: map['dropoff_address'] ?? map['dropOffAddress'],
      pickUpLatLng: map['pickup_lat'] != null && map['pickup_lng'] != null
          ? LatLng(
              double.parse(map['pickup_lat'].toString()),
              double.parse(map['pickup_lng'].toString()),
            )
          : null,
      dropOffLatLng: map['dropoff_lat'] != null && map['dropoff_lng'] != null
          ? LatLng(
              double.parse(map['dropoff_lat'].toString()),
              double.parse(map['dropoff_lng'].toString()),
            )
          : null,
      userName: map['user_name'] ?? map['userName'],
      userPhone: map['user_phone'] ?? map['userPhone'],
    );
  }
}
