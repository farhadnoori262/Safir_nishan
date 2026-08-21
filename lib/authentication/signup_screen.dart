import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import '../widgets/loading_dialog.dart';
import '../utils/lang_helper.dart'; // 👈 اضافه شدن هیلپر ترجمه
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  TextEditingController userNameTextEditingController = TextEditingController();
  TextEditingController userPhoneTextEditingController = TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();
  TextEditingController vehicleModelTextEditingController = TextEditingController();
  TextEditingController vehicleColorTextEditingController = TextEditingController();
  TextEditingController vehicleNumberTextEditingController = TextEditingController();
  CommonMethods cMethods = CommonMethods();
  XFile? imageFile;
  String urlOfUploadedImage = "";

  String selectedVehicleType = "economic_car";

  checkIfNetworkIsAvailable() {
    if (imageFile != null) {
      signUpFormValidation();
    } else {
      cMethods.displaySnackBar(tr(context, 'select_pic_error'), context);
    }
  }

  signUpFormValidation() {
    if (userNameTextEditingController.text.trim().length < 4) { // اصلاح اعتبارسنجی با توجه به متن پیام ارور
      cMethods.displaySnackBar(tr(context, 'name_length_error'), context);
    } else if (userPhoneTextEditingController.text.trim().length < 8) { // اصلاح منطق مطابق حداقل ۸ رقم
      cMethods.displaySnackBar(tr(context, 'phone_length_error'), context);
    } else if (!emailTextEditingController.text.contains("@")) {
      cMethods.displaySnackBar(tr(context, 'invalid_email_error'), context);
    } else if (passwordTextEditingController.text.trim().length < 6) {
      cMethods.displaySnackBar(tr(context, 'password_length_error'), context);
    } else if (vehicleModelTextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackBar(tr(context, 'enter_vehicle_model_error'), context);
    } else if (vehicleColorTextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackBar(tr(context, 'enter_vehicle_color_error'), context);
    } else if (vehicleNumberTextEditingController.text.isEmpty) {
      cMethods.displaySnackBar(tr(context, 'enter_vehicle_plate_error'), context);
    } else {
      uploadImageToStorage();
    }
  }

  uploadImageToStorage() async {
    String imageIDName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference referenceImage = FirebaseStorage.instance.ref().child("Images").child(imageIDName);

    UploadTask uploadTask = referenceImage.putFile(File(imageFile!.path));
    TaskSnapshot snapshot = await uploadTask;
    urlOfUploadedImage = await snapshot.ref.getDownloadURL();

    setState(() {
      urlOfUploadedImage;
    });

    registerNewDriver();
  }

  registerNewDriver() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => LoadingDialog(messageText: tr(context, 'registering_account')),
      );

      final User? userFirebase = (await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTextEditingController.text.trim(),
        password: passwordTextEditingController.text.trim(),
      ))
          .user;

      if (!context.mounted) return;
      Navigator.pop(context);

      DatabaseReference usersRef = FirebaseDatabase.instance.ref().child("drivers").child(userFirebase!.uid);

      Map driverCarInfo = {
        "type": selectedVehicleType, 
        "carColor": vehicleColorTextEditingController.text.trim(),
        "carModel": vehicleModelTextEditingController.text.trim(),
        "carNumber": vehicleNumberTextEditingController.text.trim(),
      };

      Map driverDataMap = {
        "photo": urlOfUploadedImage,
        "car_details": driverCarInfo,
        "name": userNameTextEditingController.text.trim(),
        "email": emailTextEditingController.text.trim(),
        "phone": userPhoneTextEditingController.text.trim(),
        "id": userFirebase.uid,
        "blockStatus": "no",
      };
      usersRef.set(driverDataMap);

      Navigator.push(context, MaterialPageRoute(builder: (c) => const Dashboard()));
    } catch (errorMsg) {
      Navigator.pop(context);
      cMethods.displaySnackBar(errorMsg.toString(), context);
    }
  }

  chooseImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imageFile = pickedFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ایجاد داینامیک لیست کشویی برای پشتیبانی کامل از تغییر زبان منوها
    final List<DropdownMenuItem<String>> vehicleTypeItems = [
      DropdownMenuItem(value: "economic_car", child: Text(tr(context, 'economic_car'), style: const TextStyle(fontFamily: 'IranYekan'))),
      DropdownMenuItem(value: "modern_car", child: Text(tr(context, 'modern_car'), style: const TextStyle(fontFamily: 'IranYekan'))),
      DropdownMenuItem(value: "motorbike", child: Text(tr(context, 'motorbike'), style: const TextStyle(fontFamily: 'IranYekan'))),
    ];

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const SizedBox(height: 40),

              imageFile == null
                  ? const CircleAvatar(
                      radius: 86,
                      backgroundImage: AssetImage("assets/images/avatarman.png"),
                    )
                  : Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                          image: DecorationImage(
                              fit: BoxFit.fitHeight,
                              image: FileImage(File(imageFile!.path)))),
                    ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  chooseImageFromGallery();
                },
                child: Text(
                  tr(context, 'choose_profile_pic'),
                  style: const TextStyle(
                    fontFamily: 'IranYekan',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    TextField(
                      controller: userNameTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: tr(context, 'full_name'),
                        labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: userPhoneTextEditingController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: tr(context, 'phone'),
                        labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: emailTextEditingController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: tr(context, 'email'),
                        labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: passwordTextEditingController,
                      obscureText: true,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: tr(context, 'password'),
                        labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${tr(context, 'vehicle_type')}:",
                          style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15, color: Colors.grey),
                        ),
                        DropdownButton<String>(
                          value: selectedVehicleType,
                          items: vehicleTypeItems,
                          onChanged: (value) {
                            setState(() {
                              selectedVehicleType = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    TextField(
                      controller: vehicleModelTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: tr(context, 'vehicle_model_hint'),
                        labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: vehicleColorTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: tr(context, 'vehicle_color_label'),
                        labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: vehicleNumberTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: tr(context, 'vehicle_plate_label'),
                        labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: () {
                        checkIfNetworkIsAvailable();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF145A41), 
                          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 10)),
                      child: Text(
                        tr(context, 'register_btn'),
                        style: const TextStyle(
                          fontFamily: 'IranYekan',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
                },
                child: Text(
                  tr(context, 'already_have_account'),
                  style: const TextStyle(
                    fontFamily: 'IranYekan',
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}