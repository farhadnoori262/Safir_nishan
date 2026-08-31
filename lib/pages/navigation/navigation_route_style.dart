import 'package:maplibre_gl/maplibre_gl.dart';

class NavigationRouteStyle {
  NavigationRouteStyle._();

  // همیشه استایل روز بارگذاری می‌شود
  static String get currentMapStyle => 'assets/map/style.json';

  static Future<void> drawRoute(
    MapLibreMapController controller,
    List<LatLng> points,
  ) async {
    if (points.length < 2) return;

    await controller.clearLines();

    await controller.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#000000',
        lineWidth: 18.0,
        lineOpacity: 0.96,
        lineJoin: 'round',
      ),
    );

    await controller.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#00B4D8',
        lineWidth: 11.0,
        lineOpacity: 1.0,
        lineJoin: 'round',
      ),
    );
  }
}
