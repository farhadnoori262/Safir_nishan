import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/pages/driverRegistration/vehicle_registration/driver_car_image_screen.dart';
import 'package:safir_drivers/pages/driverRegistration/vehicle_registration/vehicle_basic_info_screen.dart'; // 👈 آدرس دقیق اصلاح شد
import 'package:safir_drivers/pages/driverRegistration/vehicle_registration/vehicle_registration_screen.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  _VehicleInfoScreenState createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) {
        // متصل کردن وضعیت‌ها به پرووایدر برای حل مشکل چرخ‌دنده و پریدن بیرون
        bool isBasicComplete = registrationProvider.isVehicleBasicFormValid;
        bool isVehiclePictureComplete = registrationProvider.vehicleImage != null;
        bool isCertificateOfVehicleComplete = registrationProvider.vehicleRegistrationFrontImage != null &&
            registrationProvider.vehicleRegistrationBackImage != null;

        bool isAllComplete = isBasicComplete &&
            isVehiclePictureComplete &&
            isCertificateOfVehicleComplete;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              tr(context, 'vehicle_screen_title'),
              style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
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
                    width: MediaQuery.of(context).size.width * 0.93,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      separatorBuilder: (context, index) => const Divider(
                        color: Colors.grey,
                        thickness: 0.3,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _buildListTile(
                              title: tr(context, 'v_step_basic_title'),
                              subtitle: tr(context, 'v_step_basic_sub'),
                              isCompleted: isBasicComplete,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const VehicleBasicInfoScreen(),
                                  ),
                                );
                              },
                            );
                          case 1:
                            return _buildListTile(
                              title: tr(context, 'v_step_pic_title'),
                              subtitle: tr(context, 'v_step_pic_sub'),
                              isCompleted: isVehiclePictureComplete,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const DriverCarImageScreeen(),
                                  ),
                                );
                              },
                            );
                          case 2:
                            return _buildListTile(
                              title: tr(context, 'v_step_docs_title'),
                              subtitle: tr(context, 'v_step_docs_sub'),
                              isCompleted: isCertificateOfVehicleComplete,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const VehicleRegistrationScreen(),
                                  ),
                                );
                              },
                            );
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 25),

                  // دکمه ذخیره نهایی
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.93,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAllComplete ? const Color(0xFF145A41) : Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isAllComplete
                          ? () async {
                              Navigator.pop(context, true);
                            }
                          : null,
                      child: Text(
                        tr(context, 'v_submit_btn'),
                        style: TextStyle(
                          fontFamily: 'IranYekan',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isAllComplete ? Colors.white : Colors.black38,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontFamily: 'IranYekan', fontSize: 12, color: Colors.black54),
      ),
      trailing: isCompleted
          ? const Icon(Icons.check_circle, color: Color(0xFF145A41), size: 26)
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black38),
      onTap: onTap,
    );
  }
}
