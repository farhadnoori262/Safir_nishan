import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🔢 متد کمکی برای تبدیل اعداد انگلیسی به فارسی/پشتو
extension PersianNumberExtension on String {
  String toPersianDigits(BuildContext context) {
    // اگر زبان برنامه انگلیسی (en) بود، اعداد همان انگلیسی می‌مانند
    if (Localizations.localeOf(context).languageCode == 'en') {
      return this;
    }
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi   = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    
    String output = this;
    for (int i = 0; i < english.length; i++) {
      output = output.replaceAll(english[i], farsi[i]);
    }
    return output;
  }
}

// کلاس کمکی برای مدیریت و بارگذاری زبان از فایل‌های JSON
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  late Map<String, String> _localizedStrings;

  // 🟢 بارگذاری فایل JSON از پوشه translations
  Future<bool> load() async {
    try {
      String jsonString = await rootBundle.loadString('assets/translations/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      return true;
    } catch (e) {
      print("خطا در بارگذاری فایل زبان: $e");
      _localizedStrings = {};
      return false;
    }
  }

  // گرفتن ترجمه بر اساس کلید + تبدیل خودکار اعداد موجود در متن
  String translate(String key, BuildContext context) {
    String text = _localizedStrings[key] ?? key;
    return text.toPersianDigits(context); // 👈 اعداد داخل متن‌های فایل ترجمه هم اتوماتیک فارسی می‌شوند
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['fa', 'ps', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// 👈 تابع جهانی tr که اعداد را هم خودکار بر اساس زبان فارسی/پشتو می‌کند
String tr(BuildContext context, String key) {
  return AppLocalizations.of(context)?.translate(key, context) ?? key.toPersianDigits(context);
}

// پرووایدر مدیریت زبان برنامه
class AppLanguageProvider extends ChangeNotifier {
  Locale _appLocale = const Locale('fa'); // زبان پیش‌فرض: فارسی

  Locale get appLocal => _appLocale;

  void changeLanguage(Locale type) {
    if (_appLocale == type) return;
    _appLocale = type;
    notifyListeners();
  }
}
