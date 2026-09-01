import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class VehicleBasicInfoUpdateScreen extends StatefulWidget {
  const VehicleBasicInfoUpdateScreen({super.key});

  @override
  State<VehicleBasicInfoUpdateScreen> createState() =>
      _VehicleBasicInfoUpdateScreenState();
}

class _VehicleBasicInfoUpdateScreenState
    extends State<VehicleBasicInfoUpdateScreen> {
  final _formKey = GlobalKey<FormState>();

  // لیست ولایت‌های افغانستان
  final List<String> afghanistanProvinces = [
    'کابل', 'هرات', 'بلخ', 'قندهار', 'ننگرهار', 'غزنی', 'پکتیا', 'پروان', 'کندز', 'دایکندی', 'بامیان'
  ];

  // حروف پلاک
  final List<String> plateCategories = [
    'ش', 'الف', 'ب', 'ت', 'ج', 'د', 'ر', 'ز', 'س', 'ص', 'ط', 'ع', 'ف', 'ق', 'ک', 'م', 'ن', 'و', 'هـ', 'ی'
  ];

  // نوع پلاک
  final List<String> plateTypes = ['شخصی', 'موقتی', 'تاکسی', 'دولتی'];

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
            'vehicle_info_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
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
              onChanged: () {
                registrationProvider.checkVehicleBasicFormValidity();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ۱. کارت انتخاب نوع وسیله نقلیه
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
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
                    child: Column(
                      children: [
                        CheckboxListTile(
                          activeColor: AppColors.primaryBrand,
                          title: Row(
                            children: [
                              Image.asset("assets/vehicles/home_car.png", height: 40, width: 80),
                              const SizedBox(width: 10),
                              Text('vehicle_car'.tr(), style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                          value: registrationProvider.selectedVehicle == "Car",
                          onChanged: (bool? value) {
                            if (value == true) {
                              registrationProvider.setSelectedVehicle("Car");
                              registrationProvider.checkVehicleBasicFormValidity();
                            }
                          },
                        ),
                        const SizedBox(height: 5),
                        CheckboxListTile(
                          activeColor: AppColors.primaryBrand,
                          title: Row(
                            children: [
                              Image.asset("assets/vehicles/bike.png", height: 40, width: 80),
                              const SizedBox(width: 10),
                              Text('vehicle_bike'.tr(), style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                          value: registrationProvider.selectedVehicle == "Bike",
                          onChanged: (bool? value) {
                            if (value == true) {
                              registrationProvider.setSelectedVehicle("Bike");
                              registrationProvider.checkVehicleBasicFormValidity();
                            }
                          },
                        ),
                        const SizedBox(height: 5),
                        CheckboxListTile(
                          activeColor: AppColors.primaryBrand,
                          title: Row(
                            children: [
                              Image.asset("assets/vehicles/auto.png", height: 40, width: 80),
                              const SizedBox(width: 10),
                              Text('vehicle_auto'.tr(), style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                          value: registrationProvider.selectedVehicle == "Auto",
                          onChanged: (bool? value) {
                            if (value == true) {
                              registrationProvider.setSelectedVehicle("Auto");
                              registrationProvider.checkVehicleBasicFormValidity();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // ۲. کادر مشخصات موتر و پلاک
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // برند
                        TextFormField(
                          controller: registrationProvider.brandController,
                          decoration: InputDecoration(
                            labelText: 'vehicle_brand_label'.tr(),
                            labelStyle: const TextStyle(fontSize: 13),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'vehicle_brand_error'.tr() : null,
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        const SizedBox(height: 14),

                        // رنگ
                        TextFormField(
                          controller: registrationProvider.colorController,
                          decoration: InputDecoration(
                            labelText: 'vehicle_color_label'.tr(),
                            labelStyle: const TextStyle(fontSize: 13),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'vehicle_color_error'.tr() : null,
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        const SizedBox(height: 14),

                        // سال تولید
                        TextFormField(
                          controller: registrationProvider.productionYearController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'vehicle_year_label'.tr(),
                            labelStyle: const TextStyle(fontSize: 13),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'vehicle_year_error'.tr() : null,
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        
                        const SizedBox(height: 20),
                        Text(
                          'plate_info_header'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBrand),
                        ),
                        const SizedBox(height: 12),

                        // 🇦🇫 سطر سه تایی پلاک: ولایت + حرف + شماره پلاک
                        Row(
                          children: [
                            // انتخاب ولایت
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: afghanistanProvinces.contains(registrationProvider.plateProvince)
                                    ? registrationProvider.plateProvince
                                    : afghanistanProvinces.first,
                                decoration: InputDecoration(
                                  labelText: 'province'.tr(),
                                  labelStyle: const TextStyle(fontSize: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                items: afghanistanProvinces.map((prov) {
                                  return DropdownMenuItem(
                                    value: prov, 
                                    child: Text(prov, style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    registrationProvider.setPlateProvince(val);
                                    registrationProvider.checkVehicleBasicFormValidity();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // انتخاب حرف
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: plateCategories.contains(registrationProvider.plateCategory)
                                    ? registrationProvider.plateCategory
                                    : plateCategories.first,
                                decoration: InputDecoration(
                                  labelText: 'plate_letter'.tr(),
                                  labelStyle: const TextStyle(fontSize: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                ),
                                items: plateCategories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat, 
                                    child: Text(cat, style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    registrationProvider.setPlateCategory(val);
                                    registrationProvider.checkVehicleBasicFormValidity();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // شماره پلاک (ارقام)
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: registrationProvider.numberPlateController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'plate_number'.tr(),
                                  labelStyle: const TextStyle(fontSize: 11),
                                  hintText: '44892',
                                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                validator: (value) => (value == null || value.isEmpty) ? 'plate_number_error'.tr() : null,
                                onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 14),

                        // انتخاب نوع پلاک (شخصی، موقتی، تاکسی، ...)
                        DropdownButtonFormField<String>(
                          value: plateTypes.contains(registrationProvider.plateType)
                              ? registrationProvider.plateType
                              : plateTypes.first,
                          decoration: InputDecoration(
                            labelText: 'plate_type'.tr(),
                            labelStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: plateTypes.map((type) {
                            return DropdownMenuItem(
                              value: type, 
                              child: Text(type, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              registrationProvider.setPlateType(val);
                              registrationProvider.checkVehicleBasicFormValidity();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // دکمه تایید و ثبت اطلاعات
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: !registrationProvider.isLoading
                          ? () async {
                              if (_formKey.currentState?.validate() == true) {
                                try {
                                  await registrationProvider.updateVehicleBasicInfo(context);
                                  if (context.mounted) {
                                    commonMethods.displaySnackBar('save_success'.tr(), context);
                                    Navigator.pop(context);
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
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'confirm_and_submit'.tr(),
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
