import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';

class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key});

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen> {
  // تعریف ImagePicker داخلی برای کنترل سایز عکس
  final ImagePicker _picker = ImagePicker();

  // متد بهینه‌شده برای گرفتن عکس سلفی بدون درگیر کردن رم گوشی
  Future<void> _takeLightPhoto(RegistrationProvider registrationProvider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,       // عکس را فشرده می‌کند تا رم پر نشود
        maxHeight: 600,      // ارتفاع عکس را بهینه می‌کند
        imageQuality: 40,    // کیفیت را به ۴۰ درصد کاهش می‌دهد تا حجم به شدت کم شود
      );

      if (pickedFile != null) {
        setState(() {
          // قرار دادن عکس سبک داخل متغیر پرووایدر
          registrationProvider.cnicWithSelfieImage = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("خطا در گرفتن عکس سلفی سبک: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'selfie_screen_title'.tr(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // بخش بارگذاری تصویر سلفی تایید هویت
                _buildImagePicker(
                  context: context,
                  label: 'selfie_label'.tr(),
                  imageFile: registrationProvider.cnicWithSelfieImage,
                  onPressed: () => _takeLightPhoto(registrationProvider), // استفاده از دوربین بهینه‌شده
                  description: 'selfie_description'.tr(),
                ),
                const SizedBox(height: 25),

                // دکمه تایید نهایی سلفی
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: registrationProvider.cnicWithSelfieImage != null
                        ? () async {
                            try {
                              Navigator.pop(context, true);
                            } catch (e) {
                              debugPrint("Error while saving data: $e");
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: registrationProvider.cnicWithSelfieImage != null
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
    );
  }

  Widget _buildImagePicker({
    required BuildContext context,
    required String label,
    required XFile? imageFile,
    required VoidCallback onPressed,
    required String description,
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
              style: const TextStyle(
                fontSize: 15, 
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
                    height: 200, 
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/auth/selfie-with-id.png', 
                  height: 200,
                  errorBuilder: (c, e, s) => Icon(Icons.account_box, size: 130, color: Colors.grey.shade300),
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
              textAlign: TextAlign.justify,
              style: const TextStyle(
                fontSize: 12, 
                color: AppColors.textSecondary, 
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
