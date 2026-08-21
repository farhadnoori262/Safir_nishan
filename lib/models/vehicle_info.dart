class VehicleInfo {
  final String type;                             // نوع وسیله نقلیه (موتر، موتورسایکل، ریکشا)
  final String brand;                            // برند یا کمپنی سازنده
  final String color;                            // رنگ وسیله نقلیه
  final String registrationPlateNumber;          // شماره پلاک (مثلاً: 44892)
  
  // 🇦🇫 فیلدهای جدید جزییات پلاک افغانستان
  final String plateProvince;                    // ولایت ثبت پلاک (مثلاً: کابل)
  final String plateCategory;                    // حرف پلاک (مثلاً: ش)
  final String plateType;                        // نوع پلاک (مثلاً: شخصی یا موقت)

  final String vehiclePicture;                   // عکس وسیله نقلیه
  final String productionYear;                   // سال تولید یا مدل
  final String registrationCertificateFrontImage; // عکس روی سند مالکیت / جواز سیر
  final String registrationCertificateBackImage;  // عکس پشت سند مالکیت / جواز سیر

  VehicleInfo({
    required this.type,
    required this.brand,
    required this.color,
    required this.registrationPlateNumber,
    this.plateProvince = 'کابل',
    this.plateCategory = 'ش',
    this.plateType = 'شخصی',
    required this.vehiclePicture,
    required this.productionYear,
    required this.registrationCertificateFrontImage,
    required this.registrationCertificateBackImage,
  });

  // 👈 متد سازنده پیش‌فرض برای زمانی که هنوز اطلاعات وسیله نقلیه ثبت نشده است
  factory VehicleInfo.empty() {
    return VehicleInfo(
      type: 'economic_car',
      brand: '',
      color: '',
      registrationPlateNumber: '',
      plateProvince: 'کابل',
      plateCategory: 'ش',
      plateType: 'شخصی',
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

  // ساختن شیء از روی اطلاعات دریافتی از فایربیس با مدیریت ایمن Null-Safety
  factory VehicleInfo.fromMap(Map<String, dynamic> map) {
    return VehicleInfo(
      type: map['type'] ?? 'economic_car',
      brand: map['brand'] ?? '',
      color: map['color'] ?? '',
      registrationPlateNumber: map['registrationPlateNumber'] ?? '',
      plateProvince: map['plateProvince'] ?? 'کابل',
      plateCategory: map['plateCategory'] ?? 'ش',
      plateType: map['plateType'] ?? 'شخصی',
      vehiclePicture: map['vehiclePicture'] ?? '',
      productionYear: map['productionYear'] ?? '',
      registrationCertificateFrontImage: map['registrationCertificateFrontImage'] ?? '',
      registrationCertificateBackImage: map['registrationCertificateBackImage'] ?? '',
    );
  }
}
