import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/driver_car_image_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/vehicle_basic_info_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/vehicle_registration_update_screen.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class VehicleInfoUpdateScreen extends StatefulWidget {
  const VehicleInfoUpdateScreen({super.key});

  @override
  State<VehicleInfoUpdateScreen> createState() =>
      _VehicleInfoUpdateScreenState();
}

class _VehicleInfoUpdateScreenState extends State<VehicleInfoUpdateScreen> {
  @override
  Widget build(BuildContext context) {
    // آرایه زیرمجموعه‌های بخش اطلاعات موتر
    final List<Map<String, dynamic>> subSteps = [
      {
        'title': 'vehicle_basic_info_title'.tr(),
        'subtitle': 'vehicle_basic_info_subtitle'.tr(),
        'screen': const VehicleBasicInfoUpdateScreen(),
      },
      {
        'title': 'vehicle_image_title'.tr(),
        'subtitle': 'vehicle_image_subtitle'.tr(),
        'screen': const DriverCarImageUpdateScreen(),
      },
      {
        'title': 'vehicle_doc_title'.tr(),
        'subtitle': 'vehicle_doc_subtitle'.tr(),
        'screen': const VehicleRegistrationUpdateScreen(),
      },
    ];

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'vehicle_info_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Column(
              children: [
                Container(
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
                    itemCount: subSteps.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.black12,
                      thickness: 0.5,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final item = subSteps[index];
                      return _buildListTile(
                        title: item['title'],
                        subtitle: item['subtitle'],
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => item['screen'],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
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
