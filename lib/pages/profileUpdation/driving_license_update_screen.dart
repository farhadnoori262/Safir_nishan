import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class DrivingLicenseUpdateScreen extends StatefulWidget {
  const DrivingLicenseUpdateScreen({super.key});

  @override
  State<DrivingLicenseUpdateScreen> createState() =>
      _DrivingLicenseUpdateScreenState();
}

class _DrivingLicenseUpdateScreenState
    extends State<DrivingLicenseUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final CommonMethods commonMethods = CommonMethods();

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          title: Text(
            'license_screen_title'.tr(),
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
                  // بارگذاری روی لایسنس
                  _buildImagePicker(
                    context,
                    'license_front_hint'.tr(),
                    registrationProvider.drivingLicenseFrontImage,
                    'assets/auth/license-front.png',
                    () => registrationProvider
                        .pickAndCropDrivingLicenseImage(true),
                  ),
                  const SizedBox(height: 16),

                  // بارگذاری پشت لایسنس
                  _buildImagePicker(
                    context,
                    'license_back_hint'.tr(),
                    registrationProvider.drivingLicenseBackImage,
                    'assets/auth/license-back.png',
                    () => registrationProvider
                        .pickAndCropDrivingLicenseImage(false),
                  ),
                  const SizedBox(height: 16),

                  // فیلد شماره لایسنس
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: TextFormField(
                      controller: registrationProvider.drivingLicenseController,
                      decoration: InputDecoration(
                        labelText: 'license_number_label'.tr(),
                        helperText: 'license_number_helper'.tr(),
                        helperStyle: const TextStyle(fontSize: 11),
                        labelStyle: const TextStyle(fontSize: 13),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(12),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'err_license_required'.tr();
                        }
                        if (!registrationProvider.licenseRegExp.hasMatch(value)) {
                          return 'err_license_format'.tr();
                        }
                        return null;
                      },
                      onChanged: (value) => registrationProvider
                          .checkDrivingLicenseFormValidity(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // دکمه به‌روزرسانی
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: registrationProvider.isFormValidDrivingLicnese &&
                              !registrationProvider.isLoading
                          ? () async {
                              if (_formKey.currentState?.validate() == true) {
                                try {
                                  await registrationProvider
                                      .updatedriverLicenseInfo(context);

                                  if (context.mounted) {
                                    commonMethods.displaySnackBar(
                                      'license_update_success'.tr(),
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
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
