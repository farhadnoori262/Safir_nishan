import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  /// باز کردن گوگل مپس یا مسیریاب‌های دیگر بر اساس مختصات مبدأ و مقصد
  static Future<void> openExternalMap({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
  }) async {
    // لینک استاندارد Google Maps Navigation
    final String googleMapsUrl = originLat != null && originLng != null
        ? 'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving'
        : 'https://www.google.com/maps/search/?api=1&query=$destLat,$destLng';

    final Uri url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }
}
