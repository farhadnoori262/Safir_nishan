import 'package:maplibre_gl/maplibre_gl.dart';

class DirectionDetails {
  String? distanceTextString; // متن مسافت (مثلاً ۵.۴ کیلومتر)
  String? durationTextString; // متن زمان سفر (مثلاً ۱۲ دقیقه)
  int? distanceValueDigits;   // مقدار دقیق مسافت به متر (برای محاسبات ریاضی قیمت)
  int? durationValueDigits;   // مقدار دقیق زمان به ثانیه
  String? encodedPoints;      // جهت پشتیبانی از فرمول‌های قدیمی یا گوگل‌مپ
  List<LatLng>? polylinePoints; // 👈 نقاط دقیق مسیر برای رسم خطوط روی OpenStreetMap

  DirectionDetails({
    this.distanceTextString,
    this.durationTextString,
    this.distanceValueDigits,
    this.durationValueDigits,
    this.encodedPoints,
    this.polylinePoints,
  });
}