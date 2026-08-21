import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

class VehicleBasicInfoScreen extends StatefulWidget {
  const VehicleBasicInfoScreen({super.key});

  @override
  State<VehicleBasicInfoScreen> createState() => _VehicleBasicInfoScreenState();
}

class _VehicleBasicInfoScreenState extends State<VehicleBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // هیلپر برای تبدیل تمام اعداد فارسی/دری به اعداد استاندارد انگلیسی
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
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'vehicle_info_title'),
            style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr(context, 'close'),
                style: const TextStyle(fontFamily: 'IranYekan', color: Colors.black, fontWeight: FontWeight.bold),
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
                  // بخش انتخاب نوع وسیله نقلیه
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
                          title: Row(
                            children: [
                              Image.asset(
                                "assets/vehicles/home_car.png",
                                height: 50,
                                width: 100,
                                errorBuilder: (c, e, s) => const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Text(tr(context, 'vehicle_car'), style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15)),
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
                          title: Row(
                            children: [
                              Image.asset(
                                "assets/vehicles/bike.png",
                                height: 50,
                                width: 100,
                                errorBuilder: (c, e, s) => const Icon(Icons.motorcycle, size: 40, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Text(tr(context, 'vehicle_bike'), style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15)),
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
                          title: Row(
                            children: [
                              Image.asset(
                                "assets/vehicles/auto.png",
                                height: 50,
                                width: 100,
                                errorBuilder: (c, e, s) => const Icon(Icons.local_taxi, size: 40, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Text(tr(context, 'vehicle_auto'), style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15)),
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
                  
                  // بخش فیلدهای اطلاعات متنی وسیله نقلیه
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
                      children: [
                        TextFormField(
                          controller: registrationProvider.brandController,
                          decoration: InputDecoration(
                            labelText: tr(context, 'label_brand'),
                            labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr(context, 'err_brand_required');
                            }
                            return null;
                          },
                          onChanged: (_) => registrationProvider.checkVehicleBasicFormValidity(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: registrationProvider.colorController,
                          decoration: InputDecoration(
                            labelText: tr(context, 'label_color'),
                            labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr(context, 'err_color_required');
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
                            labelText: tr(context, 'label_year'),
                            labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr(context, 'err_year_required');
                            }
                            return null;
                          },
                          onChanged: (val) {
                            // تبدیل بلادرنگ اعداد تایپ شده به انگلیسی
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
                            labelText: tr(context, 'label_plate'),
                            labelStyle: const TextStyle(fontFamily: 'IranYekan', fontSize: 14),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr(context, 'err_plate_required');
                            }
                            return null;
                          },
                          onChanged: (val) {
                            // تبدیل اعداد پلاک به انگلیسی برای اعتبارسنجی درست در سرور یا پرووایدر
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
                  
                  // دکمه ذخیره و بازگشت
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
                                  print("Error while saving data: $e");
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: registrationProvider.isVehicleBasicFormValid
                            ? const Color(0xFF145A41)
                            : Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        tr(context, 'btn_confirm_register'),
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
