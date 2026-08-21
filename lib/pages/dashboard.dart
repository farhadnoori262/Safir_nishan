import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/pages/earnings/earnings_page.dart'; 
import 'package:safir_drivers/pages/home/home_page.dart'; 
import 'package:safir_drivers/pages/profile/profile_page.dart'; 
import 'package:safir_drivers/pages/trips/trips_page.dart'; 
import 'package:safir_drivers/providers/dashboard_provider.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  TabController? controller;

  // 🎨 تعریف ثوابت پالت رنگی سفیر
  static const Color primaryBrand = Color(0xFF145A41);
  static const Color cardBgLight = Color(0xFFEAF6F1);

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    return Scaffold(
      backgroundColor: cardBgLight, // پس‌زمینه روشن استاندارد سفیر
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
      // 🌟 منوی پایینی مدرن منطبق با پالت سفیر
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: primaryBrand.withOpacity(0.08), // سایه نرم بر پایه رنگ برند
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
                  label: tr(context, 'nav_home'),
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
                  label: tr(context, 'nav_earnings'),
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
                  label: tr(context, 'nav_trips'),
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
                  label: tr(context, 'nav_profile'),
                ),
              ],
              currentIndex: dashboardProvider.selectedIndex,
              unselectedItemColor: Colors.grey.shade400,
              selectedItemColor: primaryBrand, // استفاده از #145A41
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontFamily: 'IranYekan', 
                fontSize: 12, 
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'IranYekan', 
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              onTap: (index) {
                dashboardProvider.setIndex(index);
                controller!.index = index;
              },
            ),
          ),
        ),
      ),
    );
  }
}
