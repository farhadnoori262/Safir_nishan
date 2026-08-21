import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/auth_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart'; // 👈 هیلپر زبان سفیر

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key});

  @override
  _BasicInfoScreenState createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
    final registrationProvider = Provider.of<RegistrationProvider>(context, listen: false);
    registrationProvider.initFields(authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'basic_info_title'),
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
            child: Form(
              key: _formKey,
              onChanged: () {
                registrationProvider.checkBasicFormValidity();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // بخش بارگذاری عکس پروفایل
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
                          radius: 60,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: registrationProvider.profilePhoto != null
                              ? FileImage(File(registrationProvider.profilePhoto!.path))
                              : null,
                          child: registrationProvider.profilePhoto == null
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF145A41)),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextButton.icon(
                            onPressed: () {
                              registrationProvider.pickProfileImageFromGallary();
                            },
                            icon: const Icon(Icons.add_a_photo, color: Color(0xFF145A41), size: 18),
                            label: Text(
                              tr(context, 'add_profile_photo'),
                              style: const TextStyle(fontFamily: 'IranYekan', color: Color(0xFF145A41), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // بخش فیلدهای متنی اطلاعات فردی
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
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextFormField(
                            controller: registrationProvider.firstNameController,
                            decoration: InputDecoration(
                              labelText: tr(context, 'first_name'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                              ),
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
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                              ),
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
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                              ),
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
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                              ),
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
                          Directionality(
                            textDirection: TextDirection.ltr, // جهت LTR برای شماره تلفن
                            child: TextFormField(
                              controller: registrationProvider.phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: tr(context, 'mobile_number'),
                                labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(15)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty || value.length < 9) {
                                  return tr(context, 'err_phone');
                                }
                                return null;
                              },
                              onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.dobController,
                            decoration: InputDecoration(
                              labelText: tr(context, 'dob'),
                              labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                              ),
                              suffixIcon: const Icon(Icons.calendar_month),
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
                  const SizedBox(height: 25),

                  // دکمه ثبت و ذخیره
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: registrationProvider.isFormValidBasic
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
                        backgroundColor: registrationProvider.isFormValidBasic
                            ? const Color(0xFF145A41) // سبز برند سفیر
                            : Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        tr(context, 'confirm_and_submit'),
                        style: const TextStyle(fontFamily: 'IranYekan', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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