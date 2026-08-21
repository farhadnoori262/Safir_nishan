import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/pages/driverRegistration/basic_info_screen.dart';
import 'package:safir_drivers/pages/driverRegistration/cninc_screen.dart'; // 👈 اصلاح غلط املایی cninc به cnic
import 'package:safir_drivers/pages/driverRegistration/driving_license_screen.dart';
import 'package:safir_drivers/pages/driverRegistration/selfie_screen.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart';
import 'vehicle_info_screen.dart';

class DriverRegistration extends StatefulWidget {
  const DriverRegistration({super.key});

  @override
  _DriverRegistrationState createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  bool isBasicInfoComplete = false;
  bool isCnicComplete = false;
  bool isSelfieComplete = false;
  bool isVehicleInfoComplete = false;
  bool isDrivingLicenseInfoComplete = false;
  bool isAllComplete = false;

  // متد پشتیبان جهت اطمینان از کارکرد صحیح tr حتی در صورت نبود فایل هیلپر کامل
  String _getTranslatedText(BuildContext context, String key) {
    try {
      return tr(context, key);
    } catch (e) {
      return key;
    }
  }

  // تابع بازخوانی وضعیت تکمیل تمامی مدارک
  void _recalculateAllComplete() {
    setState(() {
      isAllComplete = isBasicInfoComplete &&
          isCnicComplete &&
          isSelfieComplete &&
          isVehicleInfoComplete &&
          isDrivingLicenseInfoComplete;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            _getTranslatedText(context, 'reg_steps_title'),
            style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 15),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // لیست چک‌لیست مراحل ثبت‌نام مدارک
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 6.0),
                    ],
                  ),
                  width: MediaQuery.of(context).size.width * 0.93,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.grey,
                      thickness: 0.3,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildListTile(
                          title: _getTranslatedText(context, 'step_basic_info_title'),
                          subtitle: _getTranslatedText(context, 'step_basic_info_sub'),
                          isCompleted: isBasicInfoComplete,
                          onTap: () async {
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BasicInfoScreen(),
                              ),
                            );
                            if (result != null && result) {
                              setState(() {
                                isBasicInfoComplete = true;
                                _recalculateAllComplete();
                              });
                            }
                          },
                        );
                      } else if (index == 1) {
                        return _buildListTile(
                          title: _getTranslatedText(context, 'step_cnic_title'),
                          subtitle: _getTranslatedText(context, 'step_cnic_sub'),
                          isCompleted: isCnicComplete,
                          onTap: () async {
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CNICScreen(),
                              ),
                            );
                            if (result != null && result) {
                              setState(() {
                                isCnicComplete = true;
                                _recalculateAllComplete();
                              });
                            }
                          },
                        );
                      } else if (index == 2) {
                        return _buildListTile(
                          title: _getTranslatedText(context, 'step_selfie_title'),
                          subtitle: _getTranslatedText(context, 'step_selfie_sub'),
                          isCompleted: isSelfieComplete,
                          onTap: () async {
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SelfieScreen(),
                              ),
                            );
                            if (result != null && result) {
                              setState(() {
                                isSelfieComplete = true;
                                _recalculateAllComplete();
                              });
                            }
                          },
                        );
                      } else if (index == 3) {
                        return _buildListTile(
                          title: _getTranslatedText(context, 'step_license_title'),
                          subtitle: _getTranslatedText(context, 'step_license_sub'),
                          isCompleted: isDrivingLicenseInfoComplete,
                          onTap: () async {
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DrivingLicenseScreen(),
                              ),
                            );
                            if (result != null && result) {
                              setState(() {
                                isDrivingLicenseInfoComplete = true;
                                _recalculateAllComplete();
                              });
                            }
                          },
                        );
                      } else {
                        return _buildListTile(
                          title: _getTranslatedText(context, 'step_vehicle_title'),
                          subtitle: _getTranslatedText(context, 'step_vehicle_sub'),
                          isCompleted: isVehicleInfoComplete,
                          onTap: () async {
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VehicleInfoScreen(),
                              ),
                            );
                            if (result != null && result) {
                              setState(() {
                                isVehicleInfoComplete = true;
                                _recalculateAllComplete();
                              });
                            }
                          },
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 25),

                // دکمه ثبت نهایی حساب
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.93,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isAllComplete && !registrationProvider.isLoading
                        ? () async {
                            registrationProvider.startLoading();
                            try {
                              await registrationProvider.saveUserData(context);
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => const Dashboard(),
                                  ),
                                );
                                CommonMethods commonMethods = CommonMethods();
                                commonMethods.displaySnackBar(
                                    _getTranslatedText(context, 'reg_success_msg'),
                                    context);
                              }
                            } catch (e) {
                              print("Error while saving data: $e");
                            } finally {
                              registrationProvider.stopLoading();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAllComplete ? const Color(0xFF145A41) : Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: registrationProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _getTranslatedText(context, 'submit_all_docs'),
                            style: const TextStyle(
                              fontFamily: 'IranYekan', 
                              color: Colors.white, 
                              fontSize: 16, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    _getTranslatedText(context, 'reg_terms_note'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'IranYekan', fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // متد ساخت کاستوم لیست‌تایل‌ها
  Widget _buildListTile({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required Function() onTap,
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
