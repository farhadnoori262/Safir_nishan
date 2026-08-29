import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';

class CNICScreen extends StatefulWidget {
  const CNICScreen({super.key});

  @override
  State<CNICScreen> createState() => _CNICScreenState();
}

class _CNICScreenState extends State<CNICScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker(); // تعریف ابزار دوربین سبک

  // متد بهینه‌شده برای گرفتن عکس کارت ملی/تذکره بدون کرش
  Future<void> _pickLightImage(bool isFront, RegistrationProvider provider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 40, // کیفیت ۴۰ درصد برای جلوگیری از بسته شدن برنامه
      );

      if (pickedFile != null) {
        setState(() {
          if (isFront) {
            provider.cnincFrontImage = pickedFile;
          } else {
            provider.cnincBackImage = pickedFile;
          }
          provider.checkCNICFormValidity(); // بررسی مجدد اعتبار فرم
        });
      }
    } catch (e) {
      debugPrint("Error picking CNIC image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'cnic_screen_title'.tr(),
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
                  
                  // بارگذاری تصویر روی کارت هویت / تذکره
                  _buildImagePicker(
                    context: context,
                    label: 'cnic_front_hint'.tr(),
                    imageFile: registrationProvider.cnincFrontImage,
                    buttonText: 'take_photo_front'.tr(),
                    defaultAssetPath: 'assets/auth/cnic-front.png',
                    onPressed: () => _pickLightImage(true, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // بارگذاری تصویر پشت کارت هویت / تذکره
                  _buildImagePicker(
                    context: context,
                    label: 'cnic_back_hint'.tr(),
                    imageFile: registrationProvider.cnincBackImage,
                    buttonText: 'take_photo_back'.tr(),
                    defaultAssetPath: 'assets/auth/cnic-back.png',
                    onPressed: () => _pickLightImage(false, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // فیلد شماره تذکره/کارت هویت
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
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller: registrationProvider.cnicController,
                        decoration: InputDecoration(
                          labelText: 'cnic_number_label'.tr(),
                          labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'err_cnic_required'.tr();
                          }
                          if (value.length != 13) {
                            return 'err_cnic_length'.tr();
                          }
                          return null;
                        },
                        onChanged: (value) =>
                            registrationProvider.checkCNICFormValidity(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // دکمه تایید نهایی مدارک
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: registrationProvider.isFormValidCninc
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
                        backgroundColor: registrationProvider.isFormValidCninc
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
                  errorBuilder: (c, e, s) => Icon(Icons.credit_card, size: 100, color: Colors.grey.shade300),
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
