import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class DirectionDetails {
  String? distanceTextString; // متن مسافت خام از API (مثلاً 5.4 km)
  String? durationTextString; // متن زمان سفر خام از API (مثلاً 12 min)
  int? distanceValueDigits; // مقدار دقیق مسافت به متر
  int? durationValueDigits; // مقدار دقیق زمان به ثانیه
  String? encodedPoints; // نقاط رمزنگاری‌شده مسیر
  List<LatLng>? polylinePoints; // نقاط دقیق مسیر جهت رسم روی نقشه

  DirectionDetails({
    this.distanceTextString,
    this.durationTextString,
    this.distanceValueDigits,
    this.durationValueDigits,
    this.encodedPoints,
    this.polylinePoints,
  });

  /// دریافت مسافت فرمت‌شده و ترجمه‌شده (مثلاً: ۵.۴ کیلومتر)
  String getFormattedDistance(BuildContext context) {
    if (distanceValueDigits == null) return '';
    final double distanceInKm = distanceValueDigits! / 1000;
    return '${distanceInKm.toStringAsFixed(1)} ${"km_unit".tr()}';
  }

  /// دریافت زمان سفر فرمت‌شده و ترجمه‌شده (مثلاً: ۱۲ دقیقه)
  String getFormattedDuration(BuildContext context) {
    if (durationValueDigits == null) return '';
    final int durationInMinutes = (durationValueDigits! / 60).round();
    return '$durationInMinutes ${"min_unit".tr()}';
  }
}
