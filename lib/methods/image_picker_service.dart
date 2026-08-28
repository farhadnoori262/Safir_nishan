import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  Future<XFile?> pickCropImage({
    required BuildContext context,
    required CropAspectRatio cropAspectRatio,
    required ImageSource imageSource,
  }) async {
    final XFile? pickImage = await ImagePicker().pickImage(
      source: imageSource,
      imageQuality: 85,
    );
    
    if (pickImage == null) return null;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickImage.path,
      aspectRatio: cropAspectRatio,
      compressQuality: 90,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'crop_profile_picture_title'.tr(),
          toolbarColor: const Color(0xFF145A41), // رنگ سبز اختصاصی سفیر
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'crop_profile_picture_title'.tr(),
          doneButtonTitle: 'confirm'.tr(),
          cancelButtonTitle: 'cancel'.tr(),
        ),
      ],
    );

    if (croppedFile == null) return null;
    return XFile(croppedFile.path);
  }
}
