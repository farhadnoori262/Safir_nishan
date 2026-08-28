class MapThemeMethods {
  // استایل‌های وکتوری نقشه سفیر (با قابلیت چرخش و رندر روان)
  static const String lightThemeStyle = 
      "https://demotiles.maplibre.org/style.json";
      
  static const String darkThemeStyle = 
      "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json";

  /// دریافت آدرس استایل نقشه MapLibre بر اساس تم تاریک/روشن
  String getMapStyle(bool isDarkMode) {
    if (isDarkMode) {
      return darkThemeStyle;
    }
    return lightThemeStyle;
  }
}

final MapThemeMethods mapThemeMethods = MapThemeMethods();
