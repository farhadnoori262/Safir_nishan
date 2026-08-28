import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profileUpdation/basic_driver_info_update_screen.dart'; 
import 'package:safir_drivers/pages/profileUpdation/cninc_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/driving_license_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/selfie_with_cninc_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicle_info_update_screen.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class DriverMainInfo extends StatefulWidget {
  const DriverMainInfo({super.key});

  @override
  State<DriverMainInfo> createState() => _DriverMainInfoState();
}

class _DriverMainInfoState extends State<DriverMainInfo> {
  bool _forceShowContent = false; // میان‌بر برای رد کردن لودینگ در صورت تایم‌اوت شبکه

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _fetchUserData();
    });
  }

  Future<void> _fetchUserData() async {
    // اگر بعد از ۴ ثانیه پاسخی از سرور نیامد، لودینگ را متوقف کن
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_forceShowContent) {
        setState(() {
          _forceShowContent = true;
        });
      }
    });

    try {
      await Provider.of<RegistrationProvider>(context, listen: false)
          .fetchUserData();
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(builder: (context, provider, child) {
      final isLoading = provider.isFetchLoading && !_forceShowContent;

      // آرایه آیتم‌های لیست برای کدهای تمیزتر و پویایی بهتر
      final List<Map<String, dynamic>> steps = [
        {
          'title': 'step_basic_info_title'.tr(),
          'subtitle': 'step_basic_info_sub'.tr(),
          'screen': const BasicDriverInfoUpdateScreen(),
        },
        {
          'title': 'step_cnic_title'.tr(),
          'subtitle': 'step_cnic_sub'.tr(),
          'screen': const CnincUpdateScreen(),
        },
        {
          'title': 'step_selfie_title'.tr(),
          'subtitle': 'step_selfie_sub'.tr(),
          'screen': const SelfieWithCnincUpdateScreen(),
        },
        {
          'title': 'step_license_title'.tr(),
          'subtitle': 'step_license_sub'.tr(),
          'screen': const DrivingLicenseUpdateScreen(),
        },
        {
          'title': 'step_vehicle_title'.tr(),
          'subtitle': 'step_vehicle_sub'.tr(),
          'screen': const VehicleInfoUpdateScreen(),
        },
      ];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          title: Text(
            'reg_steps_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'please_wait'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(
                      color: AppColors.primaryBrand,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.cardBackground,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              offset: Offset(0, 2),
                              blurRadius: 6.0,
                            ),
                          ],
                        ),
                        width: MediaQuery.of(context).size.width * 0.92,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: steps.length,
                          separatorBuilder: (context, index) => const Divider(
                            color: Colors.black12,
                            thickness: 0.5,
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final step = steps[index];
                            return _buildListTile(
                              title: step['title'],
                              subtitle: step['subtitle'],
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => step['screen'],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      );
    });
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_left_rounded,
        size: 20,
        color: AppColors.iconSecondary,
      ),
      onTap: onTap,
    );
  }
}
