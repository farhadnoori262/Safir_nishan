import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart'; // 👈 هیلپر زبان سفیر

class DrivingLicenseScreen extends StatefulWidget {
  const DrivingLicenseScreen({super.key});

  @override
  _DrivingLicenseScreenState createState() => _DrivingLicenseScreenState();
}

class _DrivingLicenseScreenState extends State<DrivingLicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker(); // تعریف ابزار دوربین سبک داخلی

  // متد بهینه‌شده برای گرفتن عکس گواهینامه رانندگی بدون کرش
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
      print("Error picking license image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'license_screen_title'),
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  
                  // بارگذاری تصویر روی جواز رانندگی (بهینه‌شده)
                  _buildImagePicker(
                    context: context,
                    label: tr(context, 'license_front_hint'),
                    imageFile: registrationProvider.drivingLicenseFrontImage,
                    buttonText: tr(context, 'take_photo_front'),
                    defaultAssetPath: 'assets/auth/license-front.png',
                    onPressed: () => _pickLightImage(true, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // بارگذاری تصویر پشت جواز رانندگی (بهینه‌شده)
                  _buildImagePicker(
                    context: context,
                    label: tr(context, 'license_back_hint'),
                    imageFile: registrationProvider.drivingLicenseBackImage,
                    buttonText: tr(context, 'take_photo_back'),
                    defaultAssetPath: 'assets/auth/license-back.png',
                    onPressed: () => _pickLightImage(false, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // فیلد نمبر جواز رانندگی
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 6.0,
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
                              labelText: tr(context, 'license_number_label'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                              helperText: tr(context, 'license_number_helper'),
                              helperStyle: const TextStyle(fontSize: 11),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(),
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return tr(context, 'err_license_required');
                              }
                              if (!registrationProvider.licenseRegExp.hasMatch(value)) {
                                return tr(context, 'err_license_format');
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
                                  print("Error while saving data: $e");
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: registrationProvider.isFormValidDrivingLicnese
                            ? const Color(0xFF145A41) // رنگ برند سفیر
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
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'IranYekan', fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          imageFile != null
              ? Image.file(File(imageFile.path), height: 150, fit: BoxFit.cover)
              : Image.asset(
                  defaultAssetPath, 
                  height: 150,
                  errorBuilder: (c, e, s) => Icon(Icons.badge, size: 120, color: Colors.grey.shade300),
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
                buttonText,
                style: const TextStyle(fontFamily: 'IranYekan', color: Color(0xFF145A41), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
