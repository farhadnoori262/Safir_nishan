import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/pages/auth/login_screen.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/widgets/loading_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController userNameTextEditingController = TextEditingController();
  final TextEditingController userPhoneTextEditingController = TextEditingController();
  final TextEditingController emailTextEditingController = TextEditingController();
  final TextEditingController passwordTextEditingController = TextEditingController();
  final TextEditingController vehicleModelTextEditingController = TextEditingController();
  final TextEditingController vehicleColorTextEditingController = TextEditingController();
  final TextEditingController vehicleNumberTextEditingController = TextEditingController();
  
  final CommonMethods cMethods = CommonMethods();
  XFile? imageFile;
  String urlOfUploadedImage = "";
  String selectedVehicleType = "economic_car";

  @override
  void dispose() {
    userNameTextEditingController.dispose();
    userPhoneTextEditingController.dispose();
    emailTextEditingController.dispose();
    passwordTextEditingController.dispose();
    vehicleModelTextEditingController.dispose();
    vehicleColorTextEditingController.dispose();
    vehicleNumberTextEditingController.dispose();
    super.dispose();
  }

  void checkIfNetworkIsAvailable() {
    if (imageFile != null) {
      signUpFormValidation();
    } else {
      cMethods.displaySnackBar('select_pic_error'.tr(), context);
    }
  }

  void signUpFormValidation() {
    if (userNameTextEditingController.text.trim().length < 4) {
      cMethods.displaySnackBar('name_length_error'.tr(), context);
    } else if (userPhoneTextEditingController.text.trim().length < 8) {
      cMethods.displaySnackBar('phone_length_error'.tr(), context);
    } else if (!emailTextEditingController.text.contains("@")) {
      cMethods.displaySnackBar('invalid_email_error'.tr(), context);
    } else if (passwordTextEditingController.text.trim().length < 6) {
      cMethods.displaySnackBar('password_length_error'.tr(), context);
    } else if (vehicleModelTextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackBar('enter_vehicle_model_error'.tr(), context);
    } else if (vehicleColorTextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackBar('enter_vehicle_color_error'.tr(), context);
    } else if (vehicleNumberTextEditingController.text.isEmpty) {
      cMethods.displaySnackBar('enter_vehicle_plate_error'.tr(), context);
    } else {
      uploadImageToStorage();
    }
  }

  Future<void> uploadImageToStorage() async {
    try {
      String imageIDName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference referenceImage = FirebaseStorage.instance.ref().child("Images").child(imageIDName);

      UploadTask uploadTask = referenceImage.putFile(File(imageFile!.path));
      TaskSnapshot snapshot = await uploadTask;
      urlOfUploadedImage = await snapshot.ref.getDownloadURL();

      if (!mounted) return;
      registerNewDriver();
    } catch (errorMsg) {
      if (!mounted) return;
      cMethods.displaySnackBar(errorMsg.toString(), context);
    }
  }

  Future<void> registerNewDriver() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoadingDialog(messageText: 'registering_account'.tr()),
    );

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTextEditingController.text.trim(),
        password: passwordTextEditingController.text.trim(),
      );

      final User? userFirebase = userCredential.user;

      if (!mounted) return;
      Navigator.pop(context);

      if (userFirebase != null) {
        DatabaseReference usersRef = FirebaseDatabase.instance.ref().child("drivers").child(userFirebase.uid);

        Map<String, dynamic> driverCarInfo = {
          "type": selectedVehicleType,
          "carColor": vehicleColorTextEditingController.text.trim(),
          "carModel": vehicleModelTextEditingController.text.trim(),
          "carNumber": vehicleNumberTextEditingController.text.trim(),
        };

        Map<String, dynamic> driverDataMap = {
          "photo": urlOfUploadedImage,
          "car_details": driverCarInfo,
          "name": userNameTextEditingController.text.trim(),
          "email": emailTextEditingController.text.trim(),
          "phone": userPhoneTextEditingController.text.trim(),
          "id": userFirebase.uid,
          "blockStatus": "no",
        };
        
        await usersRef.set(driverDataMap);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const Dashboard()),
        );
      }
    } catch (errorMsg) {
      if (!mounted) return;
      Navigator.pop(context);
      cMethods.displaySnackBar(errorMsg.toString(), context);
    }
  }

  Future<void> chooseImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imageFile = pickedFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String>> vehicleTypeItems = [
      DropdownMenuItem(value: "economic_car", child: Text('economic_car'.tr())),
      DropdownMenuItem(value: "modern_car", child: Text('modern_car'.tr())),
      DropdownMenuItem(value: "motorbike", child: Text('motorbike'.tr())),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // انتخاب عکس پروفایل
                GestureDetector(
                  onTap: chooseImageFromGallery,
                  child: Stack(
                    children: [
                      imageFile == null
                          ? const CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey,
                              backgroundImage: AssetImage("assets/images/avatarman.png"),
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: FileImage(File(imageFile!.path)),
                                ),
                              ),
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBrand,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                GestureDetector(
                  onTap: chooseImageFromGallery,
                  child: Text(
                    'choose_profile_pic'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBrand,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // فرم اطلاعات
                Column(
                  children: [
                    _buildTextField(
                      controller: userNameTextEditingController,
                      label: 'full_name'.tr(),
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: userPhoneTextEditingController,
                      label: 'phone'.tr(),
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: emailTextEditingController,
                      label: 'email'.tr(),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: passwordTextEditingController,
                      label: 'password'.tr(),
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),

                    const SizedBox(height: 20),

                    // انتخاب نوع خودرو
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'vehicle_type'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedVehicleType,
                              items: vehicleTypeItems,
                              onChanged: (value) {
                                setState(() {
                                  selectedVehicleType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: vehicleModelTextEditingController,
                      label: 'vehicle_model_hint'.tr(),
                      icon: Icons.directions_car_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: vehicleColorTextEditingController,
                      label: 'vehicle_color_label'.tr(),
                      icon: Icons.palette_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: vehicleNumberTextEditingController,
                      label: 'vehicle_plate_label'.tr(),
                      icon: Icons.confirmation_number_outlined,
                    ),

                    const SizedBox(height: 32),

                    // دکمه ثبت‌نام
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: checkIfNetworkIsAvailable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'register_btn'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.buttonText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // دکمه بازگشت به صفحه ورود
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    'already_have_account'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, color: AppColors.iconSecondary),
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
        ),
      ),
    );
  }
}
