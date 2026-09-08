import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  TabController? controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);

    // 📌 فراخوانی و به‌روزرسانی اطلاعات راننده به محض ورود به داشبورد
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final regProvider = Provider.of<RegistrationProvider>(context, listen: false);
      regProvider.retrieveCurrentDriverInfo();
      regProvider.fetchDriverEarnings();
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    // همگام‌سازی ایندکس کنترلر با پرووایدر در صورت تغییر از پرووایدر
    if (controller != null && controller!.index != dashboardProvider.selectedIndex) {
      controller!.index = dashboardProvider.selectedIndex;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: controller,
        children: const [
          HomePage(),
          EarningsPage(),
          TripsPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBrand.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: BottomNavigationBar(
              items: [
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.map_outlined, size: 24),
                  ),
                  activeIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.map, size: 24),
                  ),
                  label: 'nav_home'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.account_balance_wallet_outlined, size: 24),
                  ),
                  activeIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.account_balance_wallet, size: 24),
                  ),
                  label: 'nav_earnings'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.route_outlined, size: 24),
                  ),
                  activeIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.route, size: 24),
                  ),
                  label: 'nav_trips'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_outline_rounded, size: 24),
                  ),
                  activeIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_rounded, size: 24),
                  ),
                  label: 'nav_profile'.tr(),
                ),
              ],
              currentIndex: dashboardProvider.selectedIndex,
              unselectedItemColor: AppColors.iconSecondary,
              selectedItemColor: AppColors.primaryBrand,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              onTap: (index) {
                dashboardProvider.setIndex(index);
                controller?.index = index;
              },
            ),
          ),
        ),
      ),
    );
  }
}
