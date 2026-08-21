import 'package:maplibre_gl/maplibre_gl.dart';
 // 👈 جایگزین گوگل‌مپ برای سازگاری با OpenStreetMap

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
}