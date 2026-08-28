import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 🟢 برند و هویت visual
  static const Color primaryBrand = Color(0xFF1B7A57);
    // 📦 اضافه کردن موارد کمبود برای رفع خطای بیلد
  static const Color background = Color(0xFFF8F9FA); // یا همون backgroundLight
  
// و این خط را دقیقاً در انتهای فایل (خارج از کلاس AppColors) قرار دهید:
typedef SafirColors = AppColors;


  // 🟩 دکمه اصلی و حالت‌های لمس
  static const Color primaryButton = Color(0xFF169365);
  static const Color primaryButtonPressed = Color(0xFF0F4A35);
  static const Color primaryPressed = Color(0xFF0F4A35);
  static const Color buttonPressed = Color(0xFF0F4A35);

  // 📦 پس‌زمینه‌ها و کارت‌ها
  static const Color cardBackground = Color(0xFFEAF6F1);
  static const Color cardLightBg = Color(0xFFEAF6F1);
  static const Color cardBgLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color borderLight = Color(0xFFE0E0E0);

  // ✅ وضعیت‌ها
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);

  // 📝 متن‌ها و آیکون‌ها
  static const Color buttonText = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color iconSecondary = Color(0xFF757575);

  // 📍 نقشه
  static const Color originBlue = Color(0xFF2563EB);
}
