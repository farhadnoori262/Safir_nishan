import 'package:flutter/material.dart';

class NavigationRouteStyle {
  NavigationRouteStyle._();

  // رنگ حاشیه بیرونی مسیر
  static const Color outerColor = Color(0xFF0B5E3D);

  // رنگ اصلی مسیر
  static const Color routeColor = Color(0xFF168A61);

  // خط روشنِ وسط مسیر
  static const Color centerColor = Color(0xFF38C98B);

  // مسیری که راننده از آن رد شده
  static const Color passedRouteColor = Color(0xFF9CA3AF);

  // ضخامت‌ها
  static const double outerWidth = 15.0;
  static const double routeWidth = 11.0;
  static const double centerWidth = 2.2;

  // مسیر رفته
  static const double passedOuterWidth = 13.0;
  static const double passedRouteWidth = 9.0;
}
