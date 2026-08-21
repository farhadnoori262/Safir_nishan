import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

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
    CommonMethods commonMethods = CommonMethods();
    const Color brandColor = Color(0xFF145A41);

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'vehicle_info_title'),
            style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
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
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
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
                          activeColor: brandColor,
                          title: Row(
                            children: [
                              Image.asset("assets/vehicles/home_car.png", height: 40, width: 80),
                              const SizedBox(width: 10),
                              const Text('موتر', style: TextStyle(fontFamily: 'IranYekan', fontSize: 14)),
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
                          activeColor: brandColor,
                          title: Row(
                            children: [
                              Image.asset("assets/vehicles/bike.png", height: 40, width: 80),
                              const SizedBox(width: 10),
                              const Text('موتورسایکل', style: TextStyle(fontFamily: 'IranYekan', fontSize: 14)),
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
                          activeColor: brandColor,
                          title: Row(
                            children: [
                              Image.asset("assets/vehicles/auto.png", height: 40, width: 80),
                              const SizedBox(width: 10),
                              const Text('ریکشا / دری چرخ', style: TextStyle(fontFamily: 'IranYekan', fontSize: 14)),
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
                  
                  // ۲. کادر مشخصات موتر و پلاک
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
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
                          decoration: const InputDecoration(
                            labelText: 'برند یا کمپنی (مثلاً تویوتا)',
                            labelStyle: TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'لطفاً برند را وارد کنید' : null,
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        const SizedBox(height: 14),

                        // رنگ
                        TextFormField(
                          controller: registrationProvider.colorController,
                          decoration: const InputDecoration(
                            labelText: 'رنگ موتر (مثلاً سفید)',
                            labelStyle: TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'لطفاً رنگ را وارد کنید' : null,
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        const SizedBox(height: 14),

                        // سال تولید
                        TextFormField(
                          controller: registrationProvider.productionYearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سال تولید (مدل)',
                            labelStyle: TextStyle(fontFamily: 'IranYekan', fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'لطفاً سال تولید را وارد کنید' : null,
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        
                        const SizedBox(height: 20),
                        const Text(
                          'مشخصات پلاک موتر (افغانستان)',
                          style: TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 13, color: brandColor),
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
                                  labelText: 'ولایت',
                                  labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                items: afghanistanProvinces.map((prov) {
                                  return DropdownMenuItem(
                                    value: prov, 
                                    child: Text(prov, style: const TextStyle(fontFamily: 'IranYekan', fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    registrationProvider.setPlateProvince(val);
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
                                  labelText: 'حرف',
                                  labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                ),
                                items: plateCategories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat, 
                                    child: Text(cat, style: const TextStyle(fontFamily: 'IranYekan', fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    registrationProvider.setPlateCategory(val);
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
                                decoration: const InputDecoration(
                                  labelText: 'نمبر پلاک',
                                  labelStyle: TextStyle(fontFamily: 'IranYekan', fontSize: 11),
                                  hintText: '44892',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                validator: (value) => (value == null || value.isEmpty) ? 'نمبر پلاک را وارد کنید' : null,
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
                            labelText: 'نوع پلاک',
                            labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: plateTypes.map((type) {
                            return DropdownMenuItem(
                              value: type, 
                              child: Text(type, style: const TextStyle(fontFamily: 'IranYekan', fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              registrationProvider.setPlateType(val);
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
                    height: 50,
                    child: ElevatedButton(
                      onPressed: registrationProvider.isVehicleBasicFormValid &&
                              !registrationProvider.isLoading
                          ? () async {
                              if (_formKey.currentState?.validate() == true) {
                                try {
                                  await registrationProvider.updateVehicleBasicInfo(context);
                                  if (context.mounted) {
                                    commonMethods.displaySnackBar('اطلاعات با موفقیت ثبت شد', context);
                                    Navigator.pop(context);
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
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'تایید و ثبت نام',
                              style: TextStyle(fontFamily: 'IranYekan', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
