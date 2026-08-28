import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

import '../../../global/global.dart';

class DriverCarImageUpdateScreen extends StatefulWidget {
  const DriverCarImageUpdateScreen({super.key});

  @override
  State<DriverCarImageUpdateScreen> createState() =>
      _DriverCarImageUpdateScreenState();
}

class _DriverCarImageUpdateScreenState
    extends State<DriverCarImageUpdateScreen> {
  @override
  Widget build(BuildContext context) {
    final CommonMethods commonMethods = CommonMethods();

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          title: Text(
            'car_img_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          leading: TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'close'.tr(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          leadingWidth: 70,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImagePicker(
                  context,
                  'car_img_picker_label'.tr(),
                  registrationProvider.vehicleImage,
                  registrationProvider.pickVehicleImageFromCamera,
                ),
                const SizedBox(height: 24),

                // دکمه ثبت نهایی
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: registrationProvider.isVehiclePhotoAdded &&
                            !registrationProvider.isLoading
                        ? () async {
                            try {
                              await registrationProvider
                                  .updateVehicleImage(context);
                              if (context.mounted) {
                                commonMethods.displaySnackBar(
                                    'car_img_success'.tr(), context);
                              }
                            } catch (e) {
                              debugPrint("Error while saving data: $e");
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: registrationProvider.isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(
                            'final_confirm'.tr(),
                            style: const TextStyle(
                              color: AppColors.buttonText,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(
    BuildContext context,
    String label,
    XFile? imageFile,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 6.0,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imageFile.path),
                    height: 160,
                    width: 260,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/vehicles/civic.jpg',
                  height: 160,
                  width: 260,
                  fit: BoxFit.contain,
                ),
          const SizedBox(height: 20),
          Container(
            width: 180,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryBrand),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(
                Icons.camera_alt,
                color: AppColors.primaryBrand,
                size: 18,
              ),
              label: Text(
                'car_img_take_photo'.tr(),
                style: const TextStyle(
                  color: AppColors.primaryBrand,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
