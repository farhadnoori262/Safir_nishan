import 'package:maplibre_gl/maplibre_gl.dart';

class NavigationRouteStyle {
  NavigationRouteStyle._();

  static String get currentMapStyle {
    // حالت شب غیرفعال شد و همیشه استایل روز بازگردانده می‌شود
    return 'assets/map/style.json';
  }

  static Future<void> drawRoute(
    MapLibreMapController controller,
    List<LatLng> points,
  ) async {
    if (points.length < 2) return;

    await controller.clearLines();

    await controller.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#07553D',
        lineWidth: 18.0,
        lineOpacity: 0.96,
        lineJoin: 'round',
      ),
    );

    await controller.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#19B879',
        lineWidth: 11.0,
        lineOpacity: 1.0,
        lineJoin: 'round',
      ),
    );
  }
}
