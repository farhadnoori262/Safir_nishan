import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class SelfieWithCnincUpdateScreen extends StatefulWidget {
  const SelfieWithCnincUpdateScreen({super.key});

  @override
  State<SelfieWithCnincUpdateScreen> createState() =>
      _SelfieWithCnincUpdateScreenState();
}

class _SelfieWithCnincUpdateScreenState
    extends State<SelfieWithCnincUpdateScreen> {
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
            'selfie_screen_title'.tr(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بخش انتخاب تصویر سلفی همراه تذکره
                _buildImagePicker(
                  context,
                  'selfie_label'.tr(),
                  registrationProvider.cnicWithSelfieImage,
                  registrationProvider.pickCnincImageWithSelfie,
                  'selfie_description'.tr(),
                ),
                const SizedBox(height: 24),

                // دکمه به‌روزرسانی
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        registrationProvider.cnicWithSelfieImage != null &&
                                !registrationProvider.isLoading
                            ? () async {
                                try {
                                  await registrationProvider
                                      .updateSelfieWithCnincInfo(context);

                                  if (context.mounted) {
                                    commonMethods.displaySnackBar(
                                      'selfie_update_success'.tr(),
                                      context,
                                    );
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
    );
  }

  Widget _buildImagePicker(
    BuildContext context,
    String label,
    XFile? imageFile,
    VoidCallback onPressed,
    String description,
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imageFile.path),
                    height: 220,
                    width: 220,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/auth/selfie-with-id.png',
                  height: 200,
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
                'selfie_take_photo'.tr(),
                style: const TextStyle(
                  color: AppColors.primaryBrand,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
