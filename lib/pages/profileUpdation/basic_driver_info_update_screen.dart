import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart'; 
import 'package:safir_drivers/providers/registration_provider.dart'; 
import 'package:safir_drivers/utils/app_colors.dart';

class BasicDriverInfoUpdateScreen extends StatefulWidget {
  const BasicDriverInfoUpdateScreen({super.key});

  @override
  State<BasicDriverInfoUpdateScreen> createState() =>
      _BasicDriverInfoUpdateScreenState();
}

class _BasicDriverInfoUpdateScreenState
    extends State<BasicDriverInfoUpdateScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final CommonMethods commonMethods = CommonMethods();

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          title: Text(
            'basic_info_title'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          leading: TextButton(
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
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.cardBackground,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 6.0,
                        ),
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
                            border: Border.all(color: AppColors.primaryBrand),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton.icon(
                            onPressed: () {
                              registrationProvider.pickProfileImageFromGallary();
                            },
                            icon: const Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.primaryBrand,
                              size: 16,
                            ),
                            label: Text(
                              'add_profile_photo'.tr(),
                              style: const TextStyle(
                                color: AppColors.primaryBrand,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
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
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.cardBackground,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 6.0,
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
                              labelStyle: const TextStyle(fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              labelStyle: const TextStyle(fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              labelStyle: const TextStyle(fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              labelStyle: const TextStyle(fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          TextFormField(
                            controller: registrationProvider.phoneController,
                            decoration: InputDecoration(
                              labelText: "${'phone'.tr()} (${'not_registered'.tr()})",
                              labelStyle: const TextStyle(fontSize: 13),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            enabled: false,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.dobController,
                            decoration: InputDecoration(
                              labelText: 'dob'.tr(),
                              labelStyle: const TextStyle(fontSize: 13),
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
                    height: 52,
                    child: ElevatedButton(
                      onPressed: !registrationProvider.isLoading && registrationProvider.isFormValidBasic
                          ? () async {
                              if (_formKey.currentState?.validate() == true) {
                                try {
                                  await registrationProvider.updateBasicDriverInfo(context);

                                  if (context.mounted) {
                                    commonMethods.displaySnackBar(
                                      'driver_info_update_success'.tr(),
                                      context,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint("Error while saving data: $e");
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrand,
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
                              'driver_info_update_btn'.tr(),
                              style: const TextStyle(
                                color: AppColors.buttonText,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
