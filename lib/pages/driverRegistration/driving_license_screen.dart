import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';

class DrivingLicenseScreen extends StatefulWidget {
  const DrivingLicenseScreen({super.key});

  @override
  State<DrivingLicenseScreen> createState() => _DrivingLicenseScreenState();
}

class _DrivingLicenseScreenState extends State<DrivingLicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker(); // تعریف ابزار دوربین سبک داخلی

  // متد بهینه‌شده برای گرفتن عکس گواهینامه/جواز رانندگی بدون کرش
  Future<void> _pickLightImage(bool isFront, RegistrationProvider provider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 40, // فشرده‌سازی قدرتمند جهت جلوگیری از بسته شدن برنامه روی گوشی
      );

      if (pickedFile != null) {
        setState(() {
          if (isFront) {
            provider.drivingLicenseFrontImage = pickedFile;
          } else {
            provider.drivingLicenseBackImage = pickedFile;
          }
          provider.checkDrivingLicenseFormValidity(); // بررسی مجدد اعتبار فرم
        });
      }
    } catch (e) {
      debugPrint("Error picking license image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'license_screen_title'.tr(),
            style: const TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.cardBackground,
          actions: [
            TextButton(
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
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  
                  // بارگذاری تصویر روی جواز رانندگی (بهینه‌شده)
                  _buildImagePicker(
                    context: context,
                    label: 'license_front_hint'.tr(),
                    imageFile: registrationProvider.drivingLicenseFrontImage,
                    buttonText: 'take_photo_front'.tr(),
                    defaultAssetPath: 'assets/auth/license-front.png',
                    onPressed: () => _pickLightImage(true, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // بارگذاری تصویر پشت جواز رانندگی (بهینه‌شده)
                  _buildImagePicker(
                    context: context,
                    label: 'license_back_hint'.tr(),
                    imageFile: registrationProvider.drivingLicenseBackImage,
                    buttonText: 'take_photo_back'.tr(),
                    defaultAssetPath: 'assets/auth/license-back.png',
                    onPressed: () => _pickLightImage(false, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // فیلد نمبر جواز رانندگی
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.cardBackground,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          offset: const Offset(0, 4),
                          blurRadius: 12.0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextFormField(
                            controller: registrationProvider.drivingLicenseController,
                            decoration: InputDecoration(
                              labelText: 'license_number_label'.tr(),
                              labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              helperText: 'license_number_helper'.tr(),
                              helperStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: AppColors.primaryBrand, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                            onChanged: (value) => registrationProvider.checkDrivingLicenseFormValidity(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // دکمه تایید نهایی جواز رانندگی
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: registrationProvider.isFormValidDrivingLicnese
                          ? () async {
                              if (_formKey.currentState?.validate() == true) {
                                try {
                                  Navigator.pop(context, true);
                                } catch (e) {
                                  debugPrint("Error while saving data: $e");
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: registrationProvider.isFormValidDrivingLicnese
                            ? AppColors.primaryButton
                            : Colors.grey.shade400,
                        foregroundColor: AppColors.buttonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'confirm_and_save'.tr(),
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
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

  // ویجت یکپارچه ساخت کادر دریافت عکس روی/پشت جواز رانندگی
  Widget _buildImagePicker({
    required BuildContext context,
    required String label,
    required XFile? imageFile,
    required String buttonText,
    required String defaultAssetPath,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(20),
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            offset: const Offset(0, 4), 
            blurRadius: 12.0,
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
                fontSize: 13, 
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imageFile.path), 
                    height: 150, 
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  defaultAssetPath, 
                  height: 150,
                  errorBuilder: (c, e, s) => Icon(Icons.badge, size: 100, color: Colors.grey.shade300),
                ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryBrand),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.camera_alt, color: AppColors.primaryBrand),
              label: Text(
                buttonText,
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
