import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/auth/register_screen.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
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
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _targetScreen = null;
    });

    try {
      final User? user =
          await FirebaseAuth.instance.authStateChanges().first;

      if (!mounted) return;

      if (user == null) {
        setState(() {
          _isLoading = false;
          _targetScreen = const RegisterScreen();
        });
        return;
      }

      final AuthenticationProvider authProvider =
          Provider.of<AuthenticationProvider>(
        context,
        listen: false,
      );

      final RegistrationProvider registrationProvider =
          Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );

      try {
        await registrationProvider.retrieveCurrentDriverInfo().timeout(
          const Duration(seconds: 5),
        );
      } catch (e) {
        debugPrint('Driver information loading skipped: $e');
      }

      if (!mounted) return;

      final bool userExists =
          await authProvider.checkUserExistById().timeout(
        const Duration(seconds: 5),
        onTimeout: () => true,
      );

      if (!mounted) return;

      if (!userExists) {
        setState(() {
          _isLoading = false;
          _targetScreen = const RegisterScreen();
        });
        return;
      }

      final bool isBlocked =
          await authProvider.checkIfDriverIsBlocked().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _targetScreen =
            isBlocked ? const BlockedScreen() : const Dashboard();
      });
    } catch (e) {
      debugPrint('Splash authentication error: $e');

      if (!mounted) return;

      final User? currentUser =
          FirebaseAuth.instance.currentUser;

      setState(() {
        _isLoading = false;
        _hasError = currentUser == null;
        _targetScreen =
            currentUser != null ? const Dashboard() : null;
      });
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                      ),
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
                  padding: const EdgeInsets.all(20),
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.buttonText,
                ),
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
