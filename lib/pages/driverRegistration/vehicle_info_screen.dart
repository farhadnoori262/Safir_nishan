import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';
import 'vehicle_registration/driver_car_image_screen.dart';
import 'vehicle_registration/vehicle_basic_info_screen.dart';
import 'vehicle_registration/vehicle_registration_screen.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) {
        // متصل کردن وضعیت‌ها به پرووایدر
        bool isBasicComplete = registrationProvider.isVehicleBasicFormValid;
        bool isVehiclePictureComplete = registrationProvider.vehicleImage != null;
        bool isCertificateOfVehicleComplete = registrationProvider.vehicleRegistrationFrontImage != null &&
            registrationProvider.vehicleRegistrationBackImage != null;

        bool isAllComplete = isBasicComplete &&
            isVehiclePictureComplete &&
            isCertificateOfVehicleComplete;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'vehicle_screen_title'.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.cardBackground,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.cardBackground,
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          offset: const Offset(0, 4),
                          blurRadius: 12.0,
                        ),
                      ],
                    ),
                    width: MediaQuery.of(context).size.width * 0.93,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.grey.shade200,
                        thickness: 1,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _buildListTile(
                              title: 'v_step_basic_title'.tr(),
                              subtitle: 'v_step_basic_sub'.tr(),
                              isCompleted: isBasicComplete,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const VehicleBasicInfoScreen(),
                                  ),
                                );
                              },
                            );
                          case 1:
                            return _buildListTile(
                              title: 'v_step_pic_title'.tr(),
                              subtitle: 'v_step_pic_sub'.tr(),
                              isCompleted: isVehiclePictureComplete,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const DriverCarImageScreeen(),
                                  ),
                                );
                              },
                            );
                          case 2:
                            return _buildListTile(
                              title: 'v_step_docs_title'.tr(),
                              subtitle: 'v_step_docs_sub'.tr(),
                              isCompleted: isCertificateOfVehicleComplete,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const VehicleRegistrationScreen(),
                                  ),
                                );
                              },
                            );
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 25),

                  // دکمه ذخیره نهایی
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.93,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAllComplete
                            ? AppColors.primaryButton
                            : Colors.grey.shade400,
                        foregroundColor: AppColors.buttonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isAllComplete
                          ? () async {
                              Navigator.pop(context, true);
                            }
                          : null,
                      child: Text(
                        'v_submit_btn'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required bool isCompleted,
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
      trailing: isCompleted
          ? const Icon(Icons.check_circle, color: AppColors.primaryBrand, size: 26)
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
