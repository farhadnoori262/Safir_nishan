import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/pages/auth/signup_screen.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/widgets/loading_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailTextEditingController = TextEditingController();
  final TextEditingController passwordTextEditingController = TextEditingController();
  final CommonMethods cMethods = CommonMethods();

  @override
  void dispose() {
    emailTextEditingController.dispose();
    passwordTextEditingController.dispose();
    super.dispose();
  }

  void checkIfNetworkIsAvailable() {
    signInFormValidation();
  }

  void signInFormValidation() {
    if (!emailTextEditingController.text.contains("@")) {
      cMethods.displaySnackBar('invalid_email_error'.tr(), context);
    } else if (passwordTextEditingController.text.trim().length < 6) {
      cMethods.displaySnackBar('password_length_error'.tr(), context);
    } else {
      signInUser();
    }
  }

  Future<void> signInUser() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoadingDialog(messageText: 'logging_in'.tr()),
    );

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailTextEditingController.text.trim(),
        password: passwordTextEditingController.text.trim(),
      );

      final User? userFirebase = userCredential.user;

      if (!mounted) return;
      Navigator.pop(context); // بستن دایالوگ لودینگ

      if (userFirebase != null) {
        DatabaseReference usersRef = FirebaseDatabase.instance.ref().child("drivers").child(userFirebase.uid);
        final snap = await usersRef.once();

        if (!mounted) return;

        if (snap.snapshot.value != null) {
          final rawData = snap.snapshot.value;
          if (rawData is Map && rawData["blockStatus"] == "no") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const Dashboard()),
            );
          } else {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            cMethods.displaySnackBar('blocked_account_error'.tr(), context);
          }
        } else {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          cMethods.displaySnackBar('no_driver_record'.tr(), context);
        }
      }
    } catch (errorMsg) {
      if (!mounted) return;
      Navigator.pop(context); // بستن دایالوگ لودینگ در صورت خطا
      cMethods.displaySnackBar(errorMsg.toString(), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAlignment.center,
              children: [
                const SizedBox(height: 40),

                // تصویر لوگو/خودرو سفیر
                Image.asset(
                  "assets/images/uberexec.png",
                  width: 200,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 28),

                Text(
                  'driver_login_title'.tr(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 32),

                // فیلد ایمیل
                TextField(
                  controller: emailTextEditingController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'your_email'.tr(),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.iconSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // فیلد رمز عبور
                TextField(
                  controller: passwordTextEditingController,
                  obscureText: true,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.iconSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // دکمه ورود
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: checkIfNetworkIsAvailable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'login_btn'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.buttonText,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // دکمه ثبت نام
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const SignUpScreen()),
                    );
                  },
                  child: Text(
                    'no_account_signup'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
