import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/driverRegistration/driver_registration.dart';
import 'package:safir_drivers/pages/earnings/earnings_page.dart';
import 'package:safir_drivers/pages/home/home_page.dart';
import 'package:safir_drivers/pages/profile/profile_page.dart';
import 'package:safir_drivers/pages/trips/trips_page.dart';
import 'package:safir_drivers/providers/dashboard_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final regProvider =
          Provider.of<RegistrationProvider>(context, listen: false);
      regProvider.retrieveCurrentDriverInfo();
      regProvider.fetchDriverEarnings();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final regProvider = Provider.of<RegistrationProvider>(context);

    // همگام‌سازی انیمیشنی کنترلر با پرووایدر
    if (controller.index != dashboardProvider.selectedIndex) {
      controller.animateTo(dashboardProvider.selectedIndex);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true, // اجازه می‌دهد محتوای صفحه پشت نوار شناور برود
      body: SafeArea(
        child: Column(
          children: [
            // بنر اطلاع‌رسانی جهت تکمیل مدارک راننده
            if (!regProvider.isDriverRegistered)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade700, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber.shade900, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ثبت‌نام شما هنوز تکمیل نشده است.',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IRANSans',
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrand,
                        foregroundColor: AppColors.buttonText,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DriverRegistration(),
                          ),
                        );
                      },
                      child: const Text(
                        'تکمیل مدارک',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IRANSans',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: controller,
                children: const [
                  HomePage(),
                  EarningsPage(),
                  TripsPage(),
                  ProfilePage(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BottomNavigationBar(
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.map_outlined, size: 22),
                  activeIcon: const Icon(Icons.map_rounded, size: 24),
                  label: 'nav_home'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 22),
                  activeIcon: const Icon(Icons.account_balance_wallet_rounded,
                      size: 24),
                  label: 'nav_earnings'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.route_outlined, size: 22),
                  activeIcon: const Icon(Icons.route_rounded, size: 24),
                  label: 'nav_trips'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline_rounded, size: 22),
                  activeIcon: const Icon(Icons.person_rounded, size: 24),
                  label: 'nav_profile'.tr(),
                ),
              ],
              currentIndex: dashboardProvider.selectedIndex,
              unselectedItemColor: AppColors.iconSecondary,
              selectedItemColor: AppColors.primaryBrand,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'IRANSans',
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                fontFamily: 'IRANSans',
              ),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              onTap: (index) {
                dashboardProvider.setIndex(index);
                controller.animateTo(index);
              },
            ),
          ),
        ),
      ),
    );
  }
}
