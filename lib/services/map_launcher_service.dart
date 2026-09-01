import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  /// باز کردن مستقیم مسیریاب گوگل مپس به سمت مقصد
  static Future<void> openExternalMap({
    required double destLat,
    required double destLng,
  }) async {
    // ۱. لینک استاندارد مسیریابی مستقیم (Google Navigation Intent)
    final Uri googleMapsAppUrl = Uri.parse('google.navigation:q=$destLat,$destLng&mode=d');
    
    // ۲. لینک پشتیبان وب در صورتی که اپلیکیشن گوگل مپ نصب نباشد
    final Uri googleMapsWebUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving',
    );

    try {
      // ابتدا سعی می‌کند مستقیم اپلیکیشن Google Maps را در حالت مسیریابی باز کند
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(googleMapsWebUrl)) {
        await launchUrl(googleMapsWebUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      // در صورت بروز خطا، باز کردن لینک وب اجباری
      await launchUrl(googleMapsWebUrl, mode: LaunchMode.externalApplication);
    }
  }
}
