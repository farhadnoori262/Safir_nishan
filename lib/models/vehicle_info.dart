import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class VehicleInfo {
  final String type;                             // نوع وسیله نقلیه (economic_car, motorcycle, rickshaw, etc.)
  final String brand;                            // برند یا کمپنی سازنده
  final String color;                            // رنگ وسیله نقلیه
  final String registrationPlateNumber;          // شماره پلاک (مثلاً: 44892)
  
  // 🇦🇫 فیلدهای جزییات پلاک افغانستان
  final String plateProvince;                    // ولایت ثبت پلاک (کابل، هرات، بلخ و...)
  final String plateCategory;                    // حرف پلاک (ش، ت، م و...)
  final String plateType;                        // نوع پلاک (شخصی، موقت، تکسی و...)

  final String vehiclePicture;                   // عکس وسیله نقلیه
  final String productionYear;                   // سال تولید یا مدل
  final String registrationCertificateFrontImage; // عکس روی سند مالکیت / جواز سیر
  final String registrationCertificateBackImage;  // عکس پشت سند مالکیت / جواز سیر

  VehicleInfo({
    required this.type,
    required this.brand,
    required this.color,
    required this.registrationPlateNumber,
    this.plateProvince = 'Kabul',
    this.plateCategory = 'ش',
    this.plateType = 'personal',
    required this.vehiclePicture,
    required this.productionYear,
    required this.registrationCertificateFrontImage,
    required this.registrationCertificateBackImage,
  });

  /// دریافت پلاک نمایش داده شده به صورت یکپارچه
  String getFormattedPlate() {
    if (registrationPlateNumber.isEmpty) return '---';
    return '$plateProvince - $registrationPlateNumber - $plateCategory';
  }

  /// دریافت نوع وسیله نقلیه به صورت ترجمه‌شده
  String getLocalizedVehicleType(BuildContext context) {
    switch (type) {
      case 'motorcycle':
        return 'vehicle_type_motorcycle'.tr();
      case 'rickshaw':
        return 'vehicle_type_rickshaw'.tr();
      case 'comfort_car':
        return 'vehicle_type_comfort'.tr();
      case 'intercity_car':
        return 'vehicle_type_intercity'.tr();
      case 'cargo_van':
        return 'vehicle_type_cargo'.tr();
      case 'economic_car':
      default:
        return 'vehicle_type_economic'.tr();
    }
  }

  /// دریافت نوع پلاک به صورت ترجمه‌شده
  String getLocalizedPlateType(BuildContext context) {
    switch (plateType) {
      case 'taxi':
        return 'plate_type_taxi'.tr();
      case 'temporary':
        return 'plate_type_temporary'.tr();
      case 'personal':
      default:
        return 'plate_type_personal'.tr();
    }
  }

  // سازنده پیش‌فرض برای زمانی که اطلاعات ثبت نشده است
  factory VehicleInfo.empty() {
    return VehicleInfo(
      type: 'economic_car',
      brand: '',
      color: '',
      registrationPlateNumber: '',
      plateProvince: 'Kabul',
      plateCategory: 'ش',
      plateType: 'personal',
      vehiclePicture: '',
      productionYear: '',
      registrationCertificateFrontImage: '',
      registrationCertificateBackImage: '',
    );
  }

  // تبدیل شیء به مپ برای ذخیره در فایربیس
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'brand': brand,
      'color': color,
      'registrationPlateNumber': registrationPlateNumber,
      'plateProvince': plateProvince,
      'plateCategory': plateCategory,
      'plateType': plateType,
      'vehiclePicture': vehiclePicture,
      'productionYear': productionYear,
      'registrationCertificateFrontImage': registrationCertificateFrontImage,
      'registrationCertificateBackImage': registrationCertificateBackImage,
    };
  }

  // ساختن شیء از روی اطلاعات دریافتی از فایربیس
  factory VehicleInfo.fromMap(Map<String, dynamic> map) {
    return VehicleInfo(
      type: map['type'] ?? 'economic_car',
      brand: map['brand'] ?? '',
      color: map['color'] ?? '',
      registrationPlateNumber: map['registrationPlateNumber'] ?? '',
      plateProvince: map['plateProvince'] ?? 'Kabul',
      plateCategory: map['plateCategory'] ?? 'ش',
      plateType: map['plateType'] ?? 'personal',
      vehiclePicture: map['vehiclePicture'] ?? '',
      productionYear: map['productionYear'] ?? '',
      registrationCertificateFrontImage: map['registrationCertificateFrontImage'] ?? '',
      registrationCertificateBackImage: map['registrationCertificateBackImage'] ?? '',
    );
  }
}
