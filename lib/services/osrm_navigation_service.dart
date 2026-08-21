import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:easy_localization/easy_localization.dart'; // 📌 اتصال به easy_localization
import '../models/navigation_step_model.dart';

class OSRMNavigationService {
  /// دریافت لیست گام‌ها و مانورهای مسیر از API رایگان OSRM
  static Future<List<NavigationStepModel>> getRouteSteps(
    LatLng origin,
    LatLng destination,
  ) async {
    // ارسال پارامتر steps=true برای دریافت اطلاعات دقیق پیچ‌ها و نام خیابان‌ها
    final String url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final legs = data['routes'][0]['legs'][0];
          final stepsJson = legs['steps'] as List;

          List<NavigationStepModel> steps = [];
          for (var step in stepsJson) {
            steps.add(NavigationStepModel.fromJson(step));
          }
          return steps;
        }
      } else {
        debugPrint('osrm_status_error'.tr(args: [response.statusCode.toString()]));
      }
    } catch (e) {
      debugPrint('osrm_connection_error'.tr(args: [e.toString()]));
    }

    return [];
  }
}
