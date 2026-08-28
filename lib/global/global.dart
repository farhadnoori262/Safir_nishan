import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// اطلاعات عمومی کاربر
String userName = '';
String userEmail = '';

// استریم‌های فعال برای ردیابی زنده موقعیت مکانی راننده
StreamSubscription<Position>? positionStreamHomePage;
StreamSubscription<Position>? positionStreamNewTripPage;

// مدت زمان هشدارهای درخواست سفر به ثانیه (۴۰ ثانیه فرصت برای قبول سفر)
int driverTripRequestTimeout = 40;

// پخش‌کننده صدای زنگ درخواست سفر سفیر
final AudioPlayer audioPlayer = AudioPlayer();

// موقعیت مکانی زنده و فعلی راننده
Position? driverCurrentPosition;

// اطلاعات اختصاصی راننده جاری در سیستم سفیر
String driverName = "";
String driverPhone = "";
String driverPhoto = "";
String driverEmail = "";
String driverSecondName = "";
String address = "";
String rating = "";

// اطلاعات وسیله نقلیه (اقتصادی، مدرن، موتور، باربری، بین‌شهری)
String vehicleType = "economic_car";
String carModel = "";
String carColor = "";
String carNumber = "";

// متغیرهای مربوط به سیستم قیمت‌دهی و کرایه
String bidAmount = "";
String fareAmount = "";

// متغیرهای مربوط به زبان سیستم سفیر
String currentLanguage = "fa";

/// تابعی برای دریافت ترجمه نوع وسیله نقلیه و خدمت
String getTranslatedVehicleType(BuildContext context, String type) {
  const validVehicleTypes = {
    "economic_car",
    "modern_car",
    "motorbike",
    "cargo",
    "intercity",
  };

  if (validVehicleTypes.contains(type)) {
    return type.tr();
  }
  return type;
}
