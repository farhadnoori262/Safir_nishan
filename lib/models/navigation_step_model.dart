import 'package:maplibre_gl/maplibre_gl.dart'; // 📌 استفاده از MapLibre به‌جای Google Maps
import 'package:easy_localization/easy_localization.dart'; // 📌 اتصال به easy_localization

class NavigationStepModel {
  final String instruction; // توضیحات گام
  final String modifier;    // right, left, straight, uturn, etc.
  final String type;        // turn, new name, depart, arrive
  final double distance;    // فاصله این گام به متر
  final LatLng location;    // مختصات نقطه‌ای که باید مانور انجام شود
  final String streetName;  // نام خیابان بعدی
  bool isAnnounced;         // جهت جلوگیری از تکرار چندباره گوینده

  NavigationStepModel({
    required this.instruction,
    required this.modifier,
    required this.type,
    required this.distance,
    required this.location,
    required this.streetName,
    this.isAnnounced = false,
  });

  factory NavigationStepModel.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'];
    final locationList = maneuver['location'];
    
    return NavigationStepModel(
      instruction: json['name'] ?? '',
      modifier: maneuver['modifier'] ?? 'straight',
      type: maneuver['type'] ?? 'turn',
      distance: (json['distance'] as num).toDouble(),
      // OSRM GeoJSON مختصات را به صورت [longitude, latitude] خروجی می‌دهد
      location: LatLng(locationList[1], locationList[0]),
      streetName: json['name'] != null && json['name'].toString().trim().isNotEmpty
          ? json['name']
          : 'unknown_street'.tr(), // 📌 فراخوانی چندزبانه نام پیش‌فرض خیابان
    );
  }
}
