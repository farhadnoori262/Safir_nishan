import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/controllers/navigation_controller.dart';
import 'package:safir_drivers/pages/splash_screen.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/providers/dashboard_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/providers/trip_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (
    FlutterErrorDetails details,
  ) {
    FlutterError.dumpErrorToConsole(details);
  };

  try {
    await EasyLocalization.ensureInitialized();
  } catch (error) {
    debugPrint(
      'EasyLocalization initialization error: $error',
    );
  }

  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint(
      'Firebase initialization error: $error',
    );
  }

  _requestPermissionsSafely();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fa'),
        Locale('ps'),
        Locale('en'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fa'),
      startLocale: const Locale('fa'),
      useFallbackTranslations: true,
      child: const MyApp(),
    ),
  );
}

Future<void> _requestPermissionsSafely() async {
  try {
    await Permission.locationWhenInUse.request();
    await Permission.notification.request();
  } catch (error) {
    debugPrint(
      'Permission request error: $error',
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (
      FlutterErrorDetails details,
    ) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'خطا در بارگذاری برنامه:
${details.exception}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppLanguageProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthenticationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => RegistrationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => TripProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationController(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Safir Drivers',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'IranYekan',
          primaryColor: SafirColors.primary,
          scaffoldBackgroundColor: const Color(0xFFFAFAFA),
          colorScheme: ColorScheme.fromSeed(
            seedColor: SafirColors.primary,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
