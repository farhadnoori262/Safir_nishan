import 'package:maplibre_gl/maplibre_gl.dart';

class NavigationRouteStyle {
  NavigationRouteStyle._();

  static String get currentMapStyle {
    final hour = DateTime.now().hour;
    final isNight = hour >= 19 || hour < 6;

    return isNight
        ? 'https://tiles.stadiamaps.com/styles/alidade_smooth_dark.json'
        : 'assets/map/style.json';
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
      ),
    );

    await controller.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#19B879',
        lineWidth: 11.0,
        lineOpacity: 1.0,
      ),
    );
  }
}
