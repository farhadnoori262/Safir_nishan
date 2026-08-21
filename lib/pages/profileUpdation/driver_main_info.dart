import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/pages/profileUpdation/basic_driver_info_update_screen.dart'; 
import 'package:safir_drivers/pages/profileUpdation/cninc_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/driving_license_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/selfie_with_cninc_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicle_info_update_screen.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

class DriverMainInfo extends StatefulWidget {
  const DriverMainInfo({super.key});

  @override
  _DriverMainInfoState createState() => _DriverMainInfoState();
}

class _DriverMainInfoState extends State<DriverMainInfo> {
  bool _forceShowContent = false; // میان‌بر برای رد کردن لودینگ در صورت تحریم بودن سرور

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _fetchUserData();
    });
  }

  Future<void> _fetchUserData() async {
    // اگر بعد از ۴ ثانیه به خاطر تحریم/اینترنت پاسخی از فایربیس نیامد، لودینگ را متوقف کن
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _forceShowContent == false) {
        setState(() {
          _forceShowContent = true;
        });
      }
    });

    try {
      await Provider.of<RegistrationProvider>(context, listen: false)
          .fetchUserData();
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF145A41); // سبز برند سفیر

    return Consumer<RegistrationProvider>(builder: (context, provider, child) {
      // اگر دیتابیس هنوز لود نشده بود اما زمان تایم‌اوت ۴ ثانیه‌ای ما تمام شد، محتوا را نشان بده
      final isLoading = provider.isFetchLoading && !_forceShowContent;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'reg_steps_title'),
            style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
        ),
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr(context, 'please_wait'),
                      style: const TextStyle(fontFamily: 'IranYekan', fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(
                      color: brandColor,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Column(
                  children: [
                    Center(
                      child: Container(
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
                        width: MediaQuery.of(context).size.width * 0.92,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(), 
                          itemCount: 5,
                          separatorBuilder: (context, index) => const Divider(
                            color: Colors.black12,
                            thickness: 0.5,
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildListTile(
                                title: tr(context, 'step_basic_info_title'),
                                subtitle: tr(context, 'step_basic_info_sub'),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const BasicDriverInfoUpdateScreen(),
                                    ),
                                  );
                                },
                              );
                            } else if (index == 1) {
                              return _buildListTile(
                                title: tr(context, 'step_cnic_title'),
                                subtitle: tr(context, 'step_cnic_sub'),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CnincUpdateScreen(),
                                    ),
                                  );
                                },
                              );
                            } else if (index == 2) {
                              return _buildListTile(
                                title: tr(context, 'step_selfie_title'),
                                subtitle: tr(context, 'step_selfie_sub'),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SelfieWithCnincUpdateScreen(),
                                    ),
                                  );
                                },
                              );
                            } else if (index == 3) {
                              return _buildListTile(
                                title: tr(context, 'step_license_title'),
                                subtitle: tr(context, 'step_license_sub'),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DrivingLicenseUpdateScreen(),
                                    ),
                                  );
                                },
                              );
                            } else {
                              return _buildListTile(
                                title: tr(context, 'step_vehicle_title'),
                                subtitle: tr(context, 'step_vehicle_sub'),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const VehicleInfoUpdateScreen(),
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      );
    });
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required Function() onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'IranYekan', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontFamily: 'IranYekan', fontSize: 12, color: Colors.black54),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38), // اصلاح جهت آیکون برای حالت راست‌چین
      onTap: onTap,
    );
  }
}
