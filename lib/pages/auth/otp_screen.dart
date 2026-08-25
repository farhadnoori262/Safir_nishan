import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../methods/common_method.dart';
import '../../pages/dashboard.dart';
import '../../pages/driverRegistration/driver_registration.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/blocked_screen.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;
  const OTPScreen({super.key, required this.verificationId});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  String? smsCode;
  CommonMethods commonMethods = CommonMethods();

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthenticationProvider>(context, listen: true);
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 35),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'otp_title'.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'otp_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // فیلد ورود کد ۶ رقمی Pinput
                  Pinput(
                    length: 6,
                    showCursor: true,
                    defaultPinTheme: PinTheme(
                      width: 50,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 50,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        border: Border.all(color: AppColors.primaryBrand, width: 2),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onCompleted: (value) {
                      setState(() {
                        smsCode = value;
                      });

                      // اجرای متد بررسی کد پیامک
                      verifyOTP(smsCode: smsCode!);
                    },
                  ),

                  const SizedBox(height: 25),

                  // نمایش وضعیت در حال بررسی
                  authRepo.isLoading
                      ? const CircularProgressIndicator(
                          color: AppColors.primaryBrand,
                        )
                      : const SizedBox.shrink(),

                  // انیمیشن موفقیت‌آمیز بودن
                  authRepo.isSuccessful
                      ? Container(
                          height: 40,
                          width: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                          child: const Icon(
                            Icons.done,
                            color: AppColors.buttonText,
                            size: 30,
                          ),
                        )
                      : const SizedBox.shrink(),

                  const SizedBox(height: 25),

                  Text(
                    'didnt_receive_code'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // دکمه ارسال مجدد کد دسترسی
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.45,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // ارسال مجدد کد در صورت نیاز
                      },
                      child: Text(
                        'resend_code'.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // متد اصلاح‌شده برای عبور از لودینگ بی‌نهایت و هدایت سریع راننده
  void verifyOTP({required String smsCode}) {
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);

    authProvider.verifyOTP(
      context: context,
      verificationId: widget.verificationId,
      smsCode: smsCode,
      onSuccess: () async {
        try {
          // ۱. بررسی وجود راننده در دیتابیس
          bool driverExists = await authProvider.checkUserExistById().timeout(
            const Duration(seconds: 4),
            onTimeout: () => false,
          );

          if (driverExists) {
            // ۲. بررسی مسدود بودن راننده با مدیریت خطا
            bool isBlocked = false;
            try {
              isBlocked = await authProvider.checkIfDriverIsBlocked();
            } catch (e) {
              isBlocked = false; // اگر خطایی داد، فرض می‌کنیم مسدود نیست
            }

            if (isBlocked) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const BlockedScreen()),
              );
              return;
            }

            // ۳. دریافت اطلاعات با مدیریت خطا
            try {
              await authProvider.getUserDataFromFirebaseDatabase();
            } catch (e) {
              debugPrint("خطا در دریافت اطلاعات راننده: $e");
            }

            // ۴. بررسی پر بودن مدارک
            bool isDriverComplete = false;
            try {
              isDriverComplete = await authProvider.checkDriverFieldsFilled();
            } catch (e) {
              isDriverComplete = false; 
            }

            if (isDriverComplete) {
              navigate(isSignedIn: true);
            } else {
              navigate(isSignedIn: false);
              if (!mounted) return;
              commonMethods.displaySnackBar(
                'please_complete_documents'.tr(),
                context,
              );
            }
          } else {
            // اگر راننده وجود نداشت، مستقیم به ثبت‌نام برو
            navigate(isSignedIn: false);
          }
        } catch (globalError) {
          // 🚀 اگر هر خطای پیش‌بینی نشده‌ای رخ داد، برنامه قفل نشود و مستقیم به صفحه ثبت‌نام برود
          debugPrint("خطای کلی در ورود: $globalError");
          navigate(isSignedIn: false);
        }
      },
    );
  }

  // مدیریت ناوبری نهایی صفحات
  void navigate({required bool isSignedIn}) {
    if (!mounted) return;
    if (isSignedIn) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => DriverRegistration()),
        (route) => false,
      );
    }
  }
}
