class TripStatus {
  static const String searching = 'searching'; // مسافر درخواست داده و منتظر راننده است
  static const String accepted = 'accepted';   // راننده قبول کرده و به سمت مبدأ می‌رود
  static const String arrived = 'arrived';     // راننده به مبدأ رسید
  static const String onTrip = 'ontrip';       // سفر شروع شد (به سمت مقصد)
  static const String completed = 'completed'; // سفر تمام شد
  static const String cancelledByPassenger = 'cancelled_by_passenger'; // لغو توسط مسافر
  static const String cancelledByDriver = 'cancelled_by_driver';       // لغو توسط راننده
}
