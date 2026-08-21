import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart'; 
import 'package:safir_drivers/providers/registration_provider.dart'; 
// فرض بر این است که فایل هلپر در مسیر زیر قرار دارد، در صورت نیاز مسیر را اصلاح کن
import 'package:safir_drivers/utils/lang_helper.dart'; 

class BasicDriverInfoUpdateScreen extends StatefulWidget {
  const BasicDriverInfoUpdateScreen({super.key});

  @override
  State<BasicDriverInfoUpdateScreen> createState() =>
      _BasicDriverInfoUpdateScreenState();
}

class _BasicDriverInfoUpdateScreenState
    extends State<BasicDriverInfoUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  CommonMethods commonMethods = CommonMethods();

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF145A41); // رنگ سبز برند سفیر

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'basic_info_title'),
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
            child: Form(
              key: _formKey,
              onChanged: registrationProvider.checkBasicFormValidity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // بخش بارگذاری عکس پروفایل راننده
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, 2),
                            blurRadius: 6.0),
                      ],
                    ),
                    width: double.infinity,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        CircleAvatar(
                          radius: 55,
                          backgroundImage: registrationProvider.profilePhoto != null
                              ? FileImage(File(registrationProvider.profilePhoto!.path))
                              : const AssetImage('assets/auth/user.jpg') as ImageProvider,
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: brandColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton.icon(
                            onPressed: () {
                              registrationProvider.pickProfileImageFromGallary();
                            },
                            icon: const Icon(Icons.add_a_photo_outlined, color: brandColor, size: 16),
                            label: Text(
                              tr(context, 'add_profile_photo'),
                              style: const TextStyle(fontFamily: 'IranYekan', color: brandColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // کارت فرم اطلاعات متنی
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, 2),
                            blurRadius: 6.0),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextFormField(
                            controller: registrationProvider.firstNameController,
                            decoration: InputDecoration(
                              labelText: tr(context, 'first_name'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return tr(context, 'err_first_name');
                              }
                              return null;
                            },
                            onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.lastNameController,
                            decoration: InputDecoration(
                              labelText: tr(context, 'last_name'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return tr(context, 'err_last_name');
                              }
                              return null;
                            },
                            onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: tr(context, 'email'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty || !value.contains('@')) {
                                return tr(context, 'invalid_email_error');
                              }
                              return null;
                            },
                            onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.addressController,
                            decoration: InputDecoration(
                              labelText: tr(context, 'home_address'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty || value.length < 5) {
                                return tr(context, 'err_address');
                              }
                              return null;
                            },
                            onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.phoneController,
                            decoration: InputDecoration(
                              labelText: "${tr(context, 'phone')} (${tr(context, 'not_registered')})",
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            enabled: false,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.dobController,
                            decoration: InputDecoration(
                              labelText: tr(context, 'dob'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              suffixIcon: const Icon(Icons.calendar_month, size: 18),
                            ),
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000),
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now(),
                              );
                              if (pickedDate != null) {
                                registrationProvider.dobController.text =
                                    "${pickedDate.year}/${pickedDate.month}/${pickedDate.day}";
                              }
                            },
                            readOnly: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // دکمه به‌روزرسانی اطلاعات
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.93,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: registrationProvider.isLoading == false && registrationProvider.isFormValidBasic
                          ? () async {
                              if (_formKey.currentState?.validate() == true) {
                                try {
                                  await registrationProvider
                                      .updateBasicDriverInfo(context);

                                  if (context.mounted) {
                                    commonMethods.displaySnackBar(
                                        tr(context, 'vehicle_update_success'), context);
                                  }
                                } catch (e) {
                                  print("Error while saving data: $e");
                                }
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
                              tr(context, 'vehicle_update_btn'),
                              style: const TextStyle(fontFamily: 'IranYekan', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
}
