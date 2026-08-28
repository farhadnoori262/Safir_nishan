import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';

class VehicleBasicInfoScreen extends StatefulWidget {
  const VehicleBasicInfoScreen({super.key});

  @override
  State<VehicleBasicInfoScreen> createState() => _VehicleBasicInfoScreenState();
}

class _VehicleBasicInfoScreenState extends State<VehicleBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  String _toEnglishNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < 10; i++) {
      input = input.replaceAll(farsi[i], english[i]);
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, RegistrationProvider registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'vehicle_info_title'.tr(),
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
              onPressed: () => Navigator.pop(context),
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
                registrationProvider.checkVehicleBasicFormValidity();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
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
                    child: Column(
                      children: [
                        CheckboxListTile(
                          activeColor: AppColors.primaryBrand,
                          title: Row(
                            children: [
                              Image.asset(
                                "assets/vehicles/home_car.png",
                                height: 50,
                                width: 100,
                                errorBuilder: (c, e, s) => const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'vehicle_car'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          value: registrationProvider.selectedVehicle == "Car",
                          onChanged: (bool? value) {
                            if (value == true) {
                              registrationProvider.setSelectedVehicle("Car");
                            }
                          },
                        ),
                        const SizedBox(height: 5),
                        CheckboxListTile(
                          activeColor: AppColors.primaryBrand,
                          title: Row(
                            children: [
                              Image.asset(
                                "assets/vehicles/bike.png",
                                height: 50,
                                width: 100,
                                errorBuilder: (c, e, s) => const Icon(Icons.motorcycle, size: 40, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'vehicle_bike'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          value: registrationProvider.selectedVehicle == "Bike",
                          onChanged: (bool? value) {
                            if (value == true) {
                              registrationProvider.setSelectedVehicle("Bike");
                            }
                          },
                        ),
                        const SizedBox(height: 5),
                        CheckboxListTile(
                          activeColor: AppColors.primaryBrand,
                          title: Row(
                            children: [
                              Image.asset(
                                "assets/vehicles/auto.png",
                                height: 50,
                                width: 100,
                                errorBuilder: (c, e, s) => const Icon(Icons.local_taxi, size: 40, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'vehicle_auto'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          value: registrationProvider.selectedVehicle == "Auto",
                          onChanged: (bool? value) {
                            if (value == true) {
                              registrationProvider.setSelectedVehicle("Auto");
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: registrationProvider.brandController,
                          decoration: InputDecoration(
                            labelText: 'label_brand'.tr(),
                            labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: AppColors.primaryBrand, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'err_brand_required'.tr();
                            }
                            return null;
                          },
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: registrationProvider.colorController,
                          decoration: InputDecoration(
                            labelText: 'label_color'.tr(),
                            labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: AppColors.primaryBrand, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'err_color_required'.tr();
                            }
                            return null;
                          },
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: registrationProvider.productionYearController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'label_year'.tr(),
                            labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: AppColors.primaryBrand, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'err_year_required'.tr();
                            }
                            return null;
                          },
                          onChanged: (val) {
                            final converted = _toEnglishNumbers(val);
                            if (converted != val) {
                              registrationProvider.productionYearController.value = TextEditingValue(
                                text: converted,
                                selection: TextSelection.collapsed(offset: converted.length),
                              );
                            }
                            registrationProvider.checkVehicleBasicFormValidity();
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: registrationProvider.numberPlateController,
                          decoration: InputDecoration(
                            labelText: 'label_plate'.tr(),
                            labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: AppColors.primaryBrand, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'err_plate_required'.tr();
                            }
                            return null;
                          },
                          onChanged: (val) {
                            final converted = _toEnglishNumbers(val);
                            if (converted != val) {
                              registrationProvider.numberPlateController.value = TextEditingValue(
                                text: converted,
                                selection: TextSelection.collapsed(offset: converted.length),
                              );
                            }
                            registrationProvider.checkVehicleBasicFormValidity();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: registrationProvider.isVehicleBasicFormValid
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
                        backgroundColor: registrationProvider.isVehicleBasicFormValid
                            ? AppColors.primaryButton
                            : Colors.grey.shade400,
                        foregroundColor: AppColors.buttonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'btn_confirm_register'.tr(),
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
