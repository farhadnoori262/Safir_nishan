import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/auth/register_screen.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/widgets/blocked_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigation();
  }

  Future<void> _checkAuthAndNavigation() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // ۱. انتظار برای بازیابی وضعیت لاگین از حافظه داخلی توسط فایربیس
      final User? user = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => FirebaseAuth.instance.currentUser,
          );

      if (!mounted) return;

      // اگر هیچ کاربری لاگین نبود -> صفحه ثبت‌نام/ورود
      if (user == null) {
        setState(() {
          _isLoading = false;
          _targetScreen = const RegisterScreen();
        });
        return;
      }

      // کاربر لاگین است؛ بارگذاری اطلاعات تکمیلی از دیتابیس
      final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);

      try {
        await authProvider.getUserDataFromFirebaseDatabase();
      } catch (e) {
        debugPrint("Error loading driver info: $e");
      }

      // ۲. بررسی مسدود نبودن راننده
      bool isBlocked = false;
      try {
        isBlocked = await authProvider.checkIfDriverIsBlocked().timeout(
          const Duration(seconds: 4),
          onTimeout: () => false,
        );
      } catch (_) {
        isBlocked = false;
      }

      if (isBlocked) {
        setState(() {
          _isLoading = false;
          _targetScreen = const BlockedScreen();
        });
        return;
      }

      // ۳. بررسی تکمیل بودن مشخصات فرم راننده (اصلاح اصلی)
      bool isProfileComplete = false;
      try {
        isProfileComplete = await authProvider.checkDriverFieldsFilled().timeout(
          const Duration(seconds: 4),
          onTimeout: () => true, // در صورت کندی اینترنت راننده لاگین‌شده را بیرون نیندازد
        );
      } catch (_) {
        isProfileComplete = true;
      }

      if (isProfileComplete) {
        // پروفایل کامل است -> هدایت به داشبورد اصلی
        setState(() {
          _isLoading = false;
          _targetScreen = const Dashboard();
        });
      } else {
        // فرم راننده تکمیل نشده است -> تکمیل مشخصات
        setState(() {
          _isLoading = false;
          _targetScreen = const RegisterScreen();
        });
      }

    } catch (e) {
      if (!mounted) return;

      // در صورت بروز خطای غیرمنتظره، اگر کاربر لاگین است او را به داشبورد می‌فرستیم
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _isLoading = false;
          _targetScreen = const Dashboard();
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.primaryBrand,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/splash.png',
                      width: 140,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        'network_error_msg'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.buttonText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _checkAuthAndNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardBackground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'retry'.tr(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBrand,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _targetScreen == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryBrand,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/splash.png',
                width: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.buttonText),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      );
    }

    return _targetScreen!;
  }
}
