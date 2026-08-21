import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  Future<XFile?> pickCropImage({
    required CropAspectRatio cropAspectRatio,
    required ImageSource imageSource,
  }) async {
    XFile? pickImage = await ImagePicker().pickImage(source: imageSource);
    if (pickImage == null) return null;
    
    CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickImage.path,
        aspectRatio: cropAspectRatio,
        compressQuality: 90,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ویرایش عکس پروفایل', // عنوان تولبار کراپ
            toolbarColor: const Color(0xFF145A41), // رنگ سبز اختصاصی سفیر
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'ویرایش عکس پروفایل',
            doneButtonTitle: 'تایید',
            cancelButtonTitle: 'انصراف',
          ),
        ],
    );
    
    if (croppedFile == null) return null;
    return XFile(croppedFile.path);
  }
}