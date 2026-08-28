import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class NavigationStepModel {
  final String instruction; // توضیحات گام
  final String modifier; // right, left, straight, uturn, roundabout, etc.
  final String type; // turn, new name, depart, arrive
  final double distance; // فاصله این گام به متر
  final LatLng location; // مختصات نقطه‌ای که باید مانور انجام شود
  final String rawStreetName; // نام خیابان خام دریافتی از API
  bool isAnnounced; // جهت جلوگیری از تکرار چندباره گوینده

  NavigationStepModel({
    required this.instruction,
    required this.modifier,
    required this.type,
    required this.distance,
    required this.location,
    required this.rawStreetName,
    this.isAnnounced = false,
  });

  /// دریافت نام خیابان با پشتیبانی از چندزبانه بودن (در صورت خالی بودن نام)
  String get streetName {
    if (rawStreetName.trim().isEmpty) {
      return 'unknown_street'.tr();
    }
    return rawStreetName;
  }

  /// دریافت دستورالعمل کامل و ترجمه‌شده برای نمایش روی کارت مسیریابی
  String getLocalizedInstruction(BuildContext context) {
    if (type == 'arrive') {
      return 'arrived_at_destination'.tr();
    }

    final String actionText = _getManeuverTranslationKey(modifier).tr();
    
    if (rawStreetName.trim().isNotEmpty) {
      return '$actionText ${'into_street'.tr()} $rawStreetName';
    }
    return actionText;
  }

  /// نگاشت مانور حرکت به کلید ترجمه UI
  String _getManeuverTranslationKey(String modifier) {
    switch (modifier.toLowerCase().trim()) {
      case 'right':
      case 'slight right':
      case 'sharp right':
        return 'nav_turn_right';

      case 'left':
      case 'slight left':
      case 'sharp left':
        return 'nav_turn_left';

      case 'uturn':
        return 'nav_uturn';

      case 'roundabout':
      case 'rotary':
        return 'nav_roundabout';

      case 'straight':
      default:
        return 'nav_straight';
    }
  }

  factory NavigationStepModel.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] as Map<String, dynamic>? ?? {};
    final locationList = (maneuver['location'] as List<dynamic>?) ?? [0.0, 0.0];

    return NavigationStepModel(
      instruction: json['instruction'] ?? '',
      modifier: (maneuver['modifier'] ?? 'straight').toString(),
      type: (maneuver['type'] ?? 'turn').toString(),
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      // OSRM GeoJSON مختصات را به صورت [longitude, latitude] خروجی می‌دهد
      location: LatLng(
        (locationList[1] as num).toDouble(),
        (locationList[0] as num).toDouble(),
      ),
      rawStreetName: (json['name'] ?? '').toString(),
    );
  }
}
