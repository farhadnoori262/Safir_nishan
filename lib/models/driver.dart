import 'package:safir_drivers/models/vehicle_info.dart';

class Driver {
  final String id;
  final String profilePicture;         // عکس پروفایل راننده
  final String firstName;              // نام
  final String secondName;             // نام خانوادگی
  final String phoneNumber;            // شماره تلفن
  final String address;                // آدرس
  final String dob;                    // تاریخ تولد
  final String email;                  // ایمیل
  final String cnicNumber;             // شماره تذکره / کارت هویت ملی
  final String cnicFrontImage;         // عکس روی کارت هویت
  final String cnicBackImage;          // عکس پشت کارت هویت
  final String driverFaceWithCnic;     // عکس سلفی راننده همراه با کارت هویت
  final String drivingLicenseNumber;   // شماره گواهی‌نامه رانندگی
  final String drivingLicenseFrontImage; // عکس روی گواهی‌نامه
  final String drivingLicenseBackImage;  // عکس پشت گواهی‌نامه
  final String blockStatus;            // وضعیت مسدودی (yes/no)
  final String deviceToken;            // توکن دستگاه برای ارسال نوتیفیکیشن
  final String earnings;               // مجموع درآمد راننده
  final String driverRatings;          // امتیاز راننده
  final VehicleInfo vehicleInfo;       // اطلاعات وسیله نقلیه (موتر/موتورسایکل)

  Driver({
    required this.id,
    required this.profilePicture,
    required this.firstName,
    required this.secondName,
    required this.phoneNumber,
    required this.address,
    required this.dob,
    required this.email,
    required this.cnicNumber,
    required this.cnicFrontImage,
    required this.cnicBackImage,
    required this.driverFaceWithCnic,
    required this.drivingLicenseNumber,
    required this.drivingLicenseFrontImage,
    required this.drivingLicenseBackImage,
    required this.blockStatus,
    required this.deviceToken,
    required this.earnings,
    required this.driverRatings,
    required this.vehicleInfo,
  });

  // تبدیل شیء راننده به مپ برای ذخیره‌سازی در فایربیس
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profilePicture': profilePicture,
      'firstName': firstName,
      'secondName': secondName,
      'phoneNumber': phoneNumber,
      'address': address,
      'dob': dob,
      'email': email,
      'cnicNumber': cnicNumber,
      'cnicFrontImage': cnicFrontImage,
      'cnicBackImage': cnicBackImage,
      'driverFaceWithCnic': driverFaceWithCnic,
      'drivingLicenseNumber': drivingLicenseNumber,
      'drivingLicenseFrontImage': drivingLicenseFrontImage,
      'drivingLicenseBackImage': drivingLicenseBackImage,
      'blockStatus': blockStatus,
      'deviceToken': deviceToken,
      'earnings': earnings,
      'driverRatings': driverRatings,
      'vehicleInfo': vehicleInfo.toMap(), // تبدیل اطلاعات تودرتوی وسیله نقلیه
    };
  }

  // ساختن شیء راننده از روی اطلاعات دریافتی از فایربیس با مدیریت ایمن Null-Safety
  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'] ?? '',
      profilePicture: map['profilePicture'] ?? '',
      firstName: map['firstName'] ?? '',
      secondName: map['secondName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      dob: map['dob'] ?? '',
      email: map['email'] ?? '',
      cnicNumber: map['cnicNumber'] ?? '',
      cnicFrontImage: map['cnicFrontImage'] ?? '',
      cnicBackImage: map['cnicBackImage'] ?? '',
      driverFaceWithCnic: map['driverFaceWithCnic'] ?? '',
      drivingLicenseNumber: map['drivingLicenseNumber'] ?? '',
      drivingLicenseFrontImage: map['drivingLicenseFrontImage'] ?? '',
      drivingLicenseBackImage: map['drivingLicenseBackImage'] ?? '',
      blockStatus: map['blockStatus'] ?? 'no',
      deviceToken: map['deviceToken'] ?? '',
      earnings: map['earnings'] ?? '0',
      // پشتیبانی همزمان از کلید قدیمی و جدید برای جلوگیری از ارور
      driverRatings: map['driverRatings'] ?? map['driverRattings'] ?? '0',
      vehicleInfo: map['vehicleInfo'] != null 
          ? VehicleInfo.fromMap(Map<String, dynamic>.from(map['vehicleInfo']))
          : VehicleInfo.empty(), // در صورت خالی بودن مقدار خالی برمی‌گرداند
    );
  }
}