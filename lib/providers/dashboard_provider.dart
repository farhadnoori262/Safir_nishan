import 'package:flutter/material.dart';

class DashboardProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  // تغییر ایندکس تب منو و به‌روزرسانی رابط کاربری
  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners(); // مطلع کردن شنونده‌ها (Listeners) برای بازنشانی تب فعال
  }
}