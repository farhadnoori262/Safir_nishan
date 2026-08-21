import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart'; // 👈 هیلپر زبان سفیر

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
      print("خطا در گرفتن عکس سلفی سبک: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'selfie_screen_title'),
            style: const TextStyle(fontFamily: 'IranYekan', fontSize: 16, fontWeight: FontWeight.bold),
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
                // بخش بارگذاری تصویر سلفی تایید هویت
                _buildImagePicker(
                  context: context,
                  label: tr(context, 'selfie_label'),
                  imageFile: registrationProvider.cnicWithSelfieImage,
                  onPressed: () => _takeLightPhoto(registrationProvider), // استفاده از دوربین بهینه‌شده
                  description: tr(context, 'selfie_description'),
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
                              print("Error while saving data: $e");
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: registrationProvider.cnicWithSelfieImage != null
                          ? const Color(0xFF145A41) // رنگ سبز برند سفیر
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

  Widget _buildImagePicker({
    required BuildContext context,
    required String label,
    required XFile? imageFile,
    required VoidCallback onPressed,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 6.0),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              label,
              style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          imageFile != null
              ? Image.file(File(imageFile.path), height: 200, fit: BoxFit.cover)
              : Image.asset(
                  'assets/auth/selfie-with-id.png', 
                  height: 200,
                  errorBuilder: (c, e, s) => Icon(Icons.account_box, size: 150, color: Colors.grey.shade300),
                ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF145A41)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.camera_alt, color: Color(0xFF145A41)),
              label: Text(
                tr(context, 'selfie_take_photo'),
                style: const TextStyle(fontFamily: 'IranYekan', color: Color(0xFF145A41), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              description,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontFamily: 'IranYekan', fontSize: 12, color: Colors.black54, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
