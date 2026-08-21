import 'package:flutter/material.dart';

class MapThemeMethods {
  // آدرس تم لایت (روشن) رایگان و استاندارد اوپن‌استریت‌مپ
  static const String lightThemeUrl = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
  
  // آدرس تم دارک (تیره) استاندارد و باکیفیت از سرورهای CartoDB بدون نیاز به کلید
  static const String darkThemeUrl = "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png";

  /// تابعی برای گرفتن آدرس کاشی‌های نقشه بر اساس وضعیت تم برنامه راننده سفیر
  String getMapTileUrl(bool isDarkMode) {
    if (isDarkMode) {
      return darkThemeUrl;
    }
    return lightThemeUrl;
  }
}