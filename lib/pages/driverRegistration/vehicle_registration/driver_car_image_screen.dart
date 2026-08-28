import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';

class DriverCarImageScreeen extends StatefulWidget {
  const DriverCarImageScreeen({super.key});

  @override
  State<DriverCarImageScreeen> createState() => _DriverCarImageScreeenState();
}

class _DriverCarImageScreeenState extends State<DriverCarImageScreeen> {
  final ImagePicker _picker = ImagePicker(); // ابزار دوربین سبک داخلی

  // متد بهینه‌شده برای گرفتن عکس موتر بدون پر شدن رم گوشی و کرش کردن
  Future<void> _takeLightCarPhoto(RegistrationProvider provider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600, // فشرده‌سازی عرض عکس
        maxHeight: 600, // فشرده‌سازی ارتفاع عکس
        imageQuality: 40, // کاهش کیفیت به ۴۰٪ برای سبک شدن فوق‌العاده فایل
      );

      if (pickedFile != null) {
        setState(() {
          provider.vehicleImage = pickedFile;
          // تغییر دادن وضعیت فلگ اضافه شدن عکس در پرووایدر
          provider.isVehiclePhotoAdded = true;
        });
      }
    } catch (e) {
      debugPrint("Error taking vehicle photo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'vehicle_image_title'.tr(),
            style: const TextStyle(
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
                // بخش انتخاب تصویر موتر/موتورسایکل راننده با دوربین سبک جدید
                _buildImagePicker(
                  context,
                  'vehicle_image_hint'.tr(),
                  registrationProvider.vehicleImage,
                  () => _takeLightCarPhoto(registrationProvider), // فراخوانی دوربین سبک
                ),
                const SizedBox(height: 25),

                // دکمه تایید و ثبت نهایی
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: registrationProvider.isVehiclePhotoAdded
                        ? () async {
                            try {
                              Navigator.pop(context, true);
                            } catch (e) {
                              debugPrint("Error while saving data: $e");
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: registrationProvider.isVehiclePhotoAdded
                          ? AppColors.primaryButton
                          : Colors.grey.shade400,
                      foregroundColor: AppColors.buttonText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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

  // ویجت سفارشی‌سازی شده برای کادر انتخاب تصویر
  Widget _buildImagePicker(
    BuildContext context,
    String label,
    XFile? imageFile,
    VoidCallback onPressed,
  ) {
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
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // نمایش عکس گرفته‌شده یا آیکون پیش‌فرض
          imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imageFile.path),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(
                  Icons.directions_car,
                  size: 100,
                  color: Colors.grey.shade300,
                ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryBrand),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.camera_alt, color: AppColors.primaryBrand),
              label: Text(
                'take_photo_camera'.tr(),
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
