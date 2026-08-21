import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart'; 
import 'package:safir_drivers/providers/registration_provider.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart';

class SelfieWithCnincUpdateScreen extends StatefulWidget {
  const SelfieWithCnincUpdateScreen({super.key});

  @override
  State<SelfieWithCnincUpdateScreen> createState() =>
      _SelfieWithCnincUpdateScreenState();
}

CommonMethods commonMethods = CommonMethods();

class _SelfieWithCnincUpdateScreenState
    extends State<SelfieWithCnincUpdateScreen> {
  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF145A41); // رنگ سبز برند سفیر

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'selfie_screen_title'),
            style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
          leading: TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              tr(context, 'close'),
              style: const TextStyle(fontFamily: 'IranYekan', color: Colors.black87, fontWeight: FontWeight.bold),
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
                  tr(context, 'selfie_label'),
                  registrationProvider.cnicWithSelfieImage,
                  registrationProvider.pickCnincImageWithSelfie,
                  tr(context, 'selfie_description'),
                ),
                const SizedBox(height: 24),

                // دکمه به‌روزرسانی
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        registrationProvider.cnicWithSelfieImage != null &&
                                registrationProvider.isLoading == false
                            ? () async {
                                try {
                                  await registrationProvider
                                      .updateSelfieWithCnincInfo(context);
                                  
                                  if (context.mounted) {
                                    commonMethods.displaySnackBar(
                                        tr(context, 'vehicle_update_success'), context);
                                  }
                                } catch (e) {
                                  print("Error while saving data: $e");
                                }
                              }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
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
                            tr(context, 'update_docs'),
                            style: const TextStyle(fontFamily: 'IranYekan', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
}

Widget _buildImagePicker(BuildContext context, String label, XFile? imageFile,
    VoidCallback onPressed, String description) {
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
        Text(
          label,
          style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(imageFile.path), height: 220, width: 220, fit: BoxFit.cover),
              )
            : Image.asset('assets/auth/selfie-with-id.png', height: 200, fit: BoxFit.contain),
        const SizedBox(height: 16),
        Container(
          width: 180,
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF145A41)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.camera_alt, color: Color(0xFF145A41), size: 18),
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
            style: const TextStyle(fontFamily: 'IranYekan', fontSize: 12, color: Colors.black54, height: 1.5),
            textAlign: TextAlign.justify,
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}