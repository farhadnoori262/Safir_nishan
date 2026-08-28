import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class VehicleRegistrationUpdateScreen extends StatefulWidget {
  const VehicleRegistrationUpdateScreen({super.key});

  @override
  State<VehicleRegistrationUpdateScreen> createState() =>
      _VehicleRegistrationUpdateScreenState();
}

class _VehicleRegistrationUpdateScreenState
    extends State<VehicleRegistrationUpdateScreen> {
  final _formKey = GlobalKey<FormState>();

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
            'reg_card_title'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بارگذاری روی جواز سیر
                  _buildImagePicker(
                    context,
                    'reg_card_front_label'.tr(),
                    registrationProvider.vehicleRegistrationFrontImage,
                    'assets/auth/cnic-front.png',
                    () => registrationProvider
                        .pickAndCropVehicleRegistrationImages(true),
                  ),
                  const SizedBox(height: 16),

                  // بارگذاری پشت جواز سیر
                  _buildImagePicker(
                    context,
                    'reg_card_back_label'.tr(),
                    registrationProvider.vehicleRegistrationBackImage,
                    'assets/auth/cnic-back.png',
                    () => registrationProvider
                        .pickAndCropVehicleRegistrationImages(false),
                  ),
                  const SizedBox(height: 24),

                  // دکمه ثبت و به‌روزرسانی
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: registrationProvider.vehicleRegistrationFrontImage != null &&
                              registrationProvider.vehicleRegistrationBackImage != null &&
                              !registrationProvider.isLoading
                          ? () async {
                              if (_formKey.currentState?.validate() == true) {
                                try {
                                  await registrationProvider
                                      .updateVehicleRegistraionImages(context);
                                  if (context.mounted) {
                                    commonMethods.displaySnackBar(
                                      'reg_card_success'.tr(),
                                      context,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint("Error while saving data: $e");
                                }
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
                              'update_docs'.tr(),
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
      ),
    );
  }

  Widget _buildImagePicker(
    BuildContext context,
    String label,
    XFile? imageFile,
    String placeholderAsset,
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
                    height: 150,
                    width: 240,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  placeholderAsset,
                  height: 150,
                  width: 240,
                  fit: BoxFit.contain,
                ),
          const SizedBox(height: 16),
          Container(
            width: 180,
            height: 42,
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
                'take_photo'.tr(),
                style: const TextStyle(
                  color: AppColors.primaryBrand,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
