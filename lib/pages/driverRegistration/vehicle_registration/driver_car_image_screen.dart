import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart'; // 👈 هیلپر زبان سفیر

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
        maxWidth: 600,       // فشرده‌سازی عرض عکس
        maxHeight: 600,      // فشرده‌سازی ارتفاع عکس
        imageQuality: 40,    // کاهش کیفیت به ۴۰٪ برای سبک شدن فوق‌العاده فایل
      );

      if (pickedFile != null) {
        setState(() {
          provider.vehicleImage = pickedFile;
          // تغییر دادن وضعیت فلگ اضافه شدن عکس در پرووایدر (اگر متغیر متناظری دارد)
          provider.isVehiclePhotoAdded = true; 
        });
      }
    } catch (e) {
      print("Error taking vehicle photo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'vehicle_image_title'),
            style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                tr(context, 'close'), 
                style: const TextStyle(fontFamily: 'IranYekan', color: Colors.black, fontWeight: FontWeight.bold)
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
                  tr(context, 'vehicle_image_hint'),
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
                              print("Error while saving data: $e");
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: registrationProvider.isVehiclePhotoAdded
                          ? const Color(0xFF145A41) // رنگ سبز اختصاصی سفیر
                          : Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      tr(context, 'confirm_and_save'),
                      style: const TextStyle(
                        fontFamily: 'IranYekan', 
                        color: Colors.white, 
                        fontSize: 16, 
                        fontWeight: FontWeight.bold
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
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12, 
            offset: Offset(0, 2), 
            blurRadius: 6.0
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
              style: const TextStyle(fontFamily: 'IranYekan', fontSize: 14, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 16),
          
          // نمایش عکس گرفته‌شده یا آیکون پیش‌فرض
          imageFile != null
              ? Image.file(File(imageFile.path), height: 160, fit: BoxFit.cover)
              : Icon(Icons.directions_car, size: 120, color: Colors.grey.shade400),
              
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF145A41)), // مرز سبز سفیر
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.camera_alt, color: Color(0xFF145A41)),
              label: Text(
                tr(context, 'take_photo_camera'),
                style: const TextStyle(
                  fontFamily: 'IranYekan', 
                  color: Color(0xFF145A41), 
                  fontWeight: FontWeight.bold
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
