import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/auth/register_screen.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/pages/driverRegistration/driver_registration.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriverAuthGate();
  }
}

class DriverAuthGate extends StatelessWidget {
  const DriverAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return const _ErrorScreen();
        }

        final User? user = snapshot.data;

        if (user == null) {
          return const RegisterScreen();
        }

        return const _DriverProfileGate();
      },
    );
  }
}

class _DriverProfileGate extends StatefulWidget {
  const _DriverProfileGate();

  @override
  State<_DriverProfileGate> createState() => _DriverProfileGateState();
}

class _DriverProfileGateState extends State<_DriverProfileGate> {
  late Future<bool> _profileCheck;

  @override
  void initState() {
    super.initState();
    _profileCheck = _checkDriverProfile();
  }

  Future<bool> _checkDriverProfile() async {
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
      await registrationProvider.retrieveCurrentDriverInfo();

      return await authProvider
          .checkDriverFieldsFilled()
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Driver profile check error: $e');

      // خطای شبکه نباید کاربر Auth‌شده را logout کند.
      // در این حالت ادامهٔ ثبت‌نام را باز می‌کنیم.
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _profileCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return const DriverRegistration();
        }

        final bool isComplete = snapshot.data ?? false;

        if (isComplete) {
          return const Dashboard();
        }

        return const DriverRegistration();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
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
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBrand,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/splash.png',
                width: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'خطا در بررسی وضعیت حساب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.buttonText,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
