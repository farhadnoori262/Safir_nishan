import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'basic_info_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.cardBackground,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'close'.tr(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
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
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.cardBackground,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          offset: const Offset(0, 4),
                          blurRadius: 12.0,
                        ),
                      ],
                    ),
                    width: double.infinity,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: registrationProvider.profilePhoto != null
                              ? FileImage(File(registrationProvider.profilePhoto!.path))
                              : null,
                          child: registrationProvider.profilePhoto == null
                              ? Icon(Icons.person, size: 55, color: Colors.grey.shade400)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primaryBrand),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton.icon(
                            onPressed: () {
                              registrationProvider.pickProfileImageFromGallary();
                            },
                            icon: const Icon(Icons.add_a_photo, color: AppColors.primaryBrand, size: 18),
                            label: Text(
                              'add_profile_photo'.tr(),
                              style: const TextStyle(
                                color: AppColors.primaryBrand,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // بخش فیلدهای متنی اطلاعات فردی
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.cardBackground,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          offset: const Offset(0, 4),
                          blurRadius: 12.0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextFormField(
                            controller: registrationProvider.firstNameController,
                            decoration: InputDecoration(
                              labelText: 'first_name'.tr(),
                              labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: const BorderSide(color: AppColors.primaryBrand, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'err_first_name'.tr();
                              }
                              return null;
                            },
                            onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.lastNameController,
                            decoration: InputDecoration(
                              labelText: 'last_name'.tr(),
                              labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: const BorderSide(color: AppColors.primaryBrand, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'err_last_name'.tr();
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
                              labelText: 'email'.tr(),
                              labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: const BorderSide(color: AppColors.primaryBrand, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty || !value.contains('@')) {
                                return 'invalid_email_error'.tr();
                              }
                              return null;
                            },
                            onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.addressController,
                            decoration: InputDecoration(
                              labelText: 'home_address'.tr(),
                              labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: const BorderSide(color: AppColors.primaryBrand, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty || value.length < 5) {
                                return 'err_address'.tr();
                              }
                              return null;
                            },
                            onChanged: (_) => registrationProvider.checkBasicFormValidity(),
                          ),
                          const SizedBox(height: 16),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: TextFormField(
                              controller: registrationProvider.phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'mobile_number'.tr(),
                                labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                                  borderSide: const BorderSide(color: AppColors.primaryBrand, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty || value.length < 9) {
                                  return 'err_phone'.tr();
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
                              labelText: 'dob'.tr(),
                              labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: const BorderSide(color: AppColors.primaryBrand, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              suffixIcon: const Icon(Icons.calendar_month, color: AppColors.primaryBrand),
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
                                  debugPrint("Error while saving data: $e");
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: registrationProvider.isFormValidBasic
                            ? AppColors.primaryButton
                            : Colors.grey.shade400,
                        foregroundColor: AppColors.buttonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'confirm_and_submit'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
}
