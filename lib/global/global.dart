import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/lang_helper.dart';

// اطلاعات عمومی کاربر
String userName = '';
String userEmail = '';

// استریم‌های فعال برای ردیابی زنده موقعیت مکانی راننده
StreamSubscription<Position>? positionStreamHomePage;
StreamSubscription<Position>? positionStreamNewTripPage;

// مدت زمان هشدارهای درخواست سفر به ثانیه (۴۰ ثانیه فرصت برای قبول سفر)
int driverTripRequestTimeout = 40;

// پخش‌کننده صدای زنگ درخواست سفر سفیر
final audioPlayer = AudioPlayer();

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

// اطلاعات وسیله نقلیه (موتر، موتورسایکل یا ریکشا)
String vehicleType = "economic_car";
String carModel = "";
String carColor = "";
String carNumber = "";

// متغیرهای مربوط به سیستم قیمت‌دهی و کرایه
String bidAmount = "";
String fareAmount = "";

// متغیرهای مربوط به زبان سیستم سفیر
String currentLanguage = "fa";

/// تابعی برای دریافت ترجمه نوع وسیله نقلیه
String getTranslatedVehicleType(BuildContext context, String type) {
  if (type == "economic_car" || type == "modern_car" || type == "motorbike") {
    return tr(context, type);
  }
  return type;
}

const Color black80 = Colors.black87;
const Color black90 = Colors.black87;
