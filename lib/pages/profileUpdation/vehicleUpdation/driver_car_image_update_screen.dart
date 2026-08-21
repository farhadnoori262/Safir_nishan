import 'dart:io';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart'; // 👈 هیلپر زبان سفیر

import '../../../global/global.dart';

class DriverCarImageUpdateScreen extends StatefulWidget {
  const DriverCarImageUpdateScreen({super.key});

  @override
  State<DriverCarImageUpdateScreen> createState() =>
      _DriverCarImageUpdateScreenState();
}

class _DriverCarImageUpdateScreenState
    extends State<DriverCarImageUpdateScreen> {
  @override
  Widget build(BuildContext context) {CommonMethods commonMethods = CommonMethods();

    const Color brandColor = Color(0xFF145A41); // رنگ سبز برند سفیر

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'car_img_title'),
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
                _buildImagePicker(
                  context,
                  tr(context, 'car_img_picker_label'),
                  registrationProvider.vehicleImage,
                  registrationProvider.pickVehicleImageFromCamera,
                ),
                const SizedBox(height: 24),

                // دکمه ثبت نهایی
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: registrationProvider.isVehiclePhotoAdded &&
                            registrationProvider.isLoading == false
                        ? () async {
                            try {
                              await registrationProvider
                                  .updateVehicleImage(context);
                              if (context.mounted) {
                                commonMethods.displaySnackBar(
                                    tr(context, 'car_img_success'), context);
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
                            tr(context, 'final_confirm'),
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

  Widget _buildImagePicker(BuildContext context, String label, XFile? imageFile,
      VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, offset: Offset(0, 2), blurRadius: 6.0),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              label,
              style: const TextStyle(fontFamily: 'IranYekan', fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(imageFile.path), height: 160, width: 260, fit: BoxFit.cover),
                )
              : Image.asset('assets/vehicles/civic.jpg', height: 160, width: 260, fit: BoxFit.contain),
          const SizedBox(height: 20),
          Container(
            width: 180,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF145A41)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.camera_alt, color: Color(0xFF145A41), size: 18),
              label: Text(
                tr(context, 'car_img_take_photo'),
                style: const TextStyle(fontFamily: 'IranYekan', color: Color(0xFF145A41), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}