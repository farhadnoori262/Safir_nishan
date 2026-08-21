import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart'; // 👈 هیلپر زبان سفیر

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  @override
  void initState() {
    super.initState();
    // فراخوانی متد دریافت میزان درآمد راننده پس از مقداردهی اولیه صفحه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RegistrationProvider>(context, listen: false)
          .fetchDriverEarnings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF145A41), // رنگ برند سفیر
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Container(
                color: const Color(0xFF145A41),
                width: 300,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      // تصویر پیش‌فرض درآمد
                      Image.asset(
                        "assets/images/totalearnings.png",
                        width: 120,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.account_balance_wallet,
                          size: 100,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        tr(context, 'total_earnings_title'),
                        style: const TextStyle(
                          fontFamily: 'IranYekan',
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Consumer<RegistrationProvider>(
                        builder: (context, provider, child) {
                          // بررسی در حال بارگذاری بودن اطلاعات از دیتابیس
                          if (provider.driverEarnings == null) {
                            return const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            );
                          } else {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "${provider.driverEarnings}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tr(context, 'currency_unit'),
                                  style: const TextStyle(
                                    fontFamily: 'IranYekan',
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}