import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../methods/common_method.dart';
import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';
import '../dashboard.dart';
import 'basic_info_screen.dart';
import 'cnic_screen.dart';
import 'driving_license_screen.dart';
import 'selfie_screen.dart';
import 'vehicle_info_screen.dart';

class DriverRegistration extends StatefulWidget {
  const DriverRegistration({super.key});

  @override
  State<DriverRegistration> createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  bool isBasicInfoComplete = false;
  bool isCnicComplete = false;
  bool isSelfieComplete = false;
  bool isVehicleInfoComplete = false;
  bool isDrivingLicenseInfoComplete = false;
  bool isAllComplete = false;
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentStatus();
    });
  }

  // 🔄 دریافت آخرین اطلاعات و محاسبه دقیق تکمیل بودن هر مرحله
  Future<void> _loadCurrentStatus() async {
    final registrationProvider =
        Provider.of<RegistrationProvider>(context, listen: false);

    await registrationProvider.fetchUserData();

    if (!mounted) return;

    setState(() {
      // ۱. اطلاعات اولیه (نام، تخلص، ایمیل، آدرس و عکس پروفایل)
      isBasicInfoComplete =
          registrationProvider.firstNameController.text.trim().isNotEmpty &&
          registrationProvider.lastNameController.text.trim().isNotEmpty &&
          registrationProvider.emailController.text.trim().isNotEmpty &&
          registrationProvider.addressController.text.trim().isNotEmpty &&
          (registrationProvider.profilePhotoUrl != null &&
              registrationProvider.profilePhotoUrl!.isNotEmpty);

      // ۲. تذکره / کارت ملی
      isCnicComplete =
          registrationProvider.cnicController.text.trim().isNotEmpty &&
          (registrationProvider.cnicFrontImageUrl != null &&
              registrationProvider.cnicFrontImageUrl!.isNotEmpty) &&
          (registrationProvider.cnicBackImageUrl != null &&
              registrationProvider.cnicBackImageUrl!.isNotEmpty);

      // ۳. سلفی با تذکره
      isSelfieComplete =
          registrationProvider.cnicWithSelfieImageUrl != null &&
          registrationProvider.cnicWithSelfieImageUrl!.isNotEmpty;

      // ۴. جواز رانندگی
      isDrivingLicenseInfoComplete =
          registrationProvider.drivingLicenseController.text.trim().isNotEmpty &&
          (registrationProvider.drivingLicenseFrontImageUrl != null &&
              registrationProvider.drivingLicenseFrontImageUrl!.isNotEmpty) &&
          (registrationProvider.drivingLicenseBackImageUrl != null &&
              registrationProvider.drivingLicenseBackImageUrl!.isNotEmpty);

      // ۵. مشخصات خودرو و پلاک افغانستان
      isVehicleInfoComplete =
          registrationProvider.selectedVehicle != null &&
          registrationProvider.selectedVehicle!.isNotEmpty &&
          registrationProvider.brandController.text.trim().isNotEmpty &&
          registrationProvider.plateNumberController.text.trim().isNotEmpty &&
          registrationProvider.selectedProvince != null &&
          (registrationProvider.vehicleImageUrl != null &&
              registrationProvider.vehicleImageUrl!.isNotEmpty);

      _isCheckingStatus = false;
      _recalculateAllComplete();
    });
  }

  // تابع محاسبه مجدد تکمیل کامل تمامی مدارک
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
    if (_isCheckingStatus) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'reg_steps_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.cardBackground,
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 15),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // لیست چک‌لیست مراحل ثبت‌نام مدارک
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.cardBackground,
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        offset: const Offset(0, 4),
                        blurRadius: 12.0,
                      ),
                    ],
                  ),
                  width: MediaQuery.of(context).size.width * 0.93,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.grey.shade200,
                      thickness: 1,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildListTile(
                          title: 'step_basic_info_title'.tr(),
                          subtitle: 'step_basic_info_sub'.tr(),
                          isCompleted: isBasicInfoComplete,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BasicInfoScreen(),
                              ),
                            );
                            _loadCurrentStatus();
                          },
                        );
                      } else if (index == 1) {
                        return _buildListTile(
                          title: 'step_cnic_title'.tr(),
                          subtitle: 'step_cnic_sub'.tr(),
                          isCompleted: isCnicComplete,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CNICScreen(),
                              ),
                            );
                            _loadCurrentStatus();
                          },
                        );
                      } else if (index == 2) {
                        return _buildListTile(
                          title: 'step_selfie_title'.tr(),
                          subtitle: 'step_selfie_sub'.tr(),
                          isCompleted: isSelfieComplete,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SelfieScreen(),
                              ),
                            );
                            _loadCurrentStatus();
                          },
                        );
                      } else if (index == 3) {
                        return _buildListTile(
                          title: 'step_license_title'.tr(),
                          subtitle: 'step_license_sub'.tr(),
                          isCompleted: isDrivingLicenseInfoComplete,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DrivingLicenseScreen(),
                              ),
                            );
                            _loadCurrentStatus();
                          },
                        );
                      } else {
                        return _buildListTile(
                          title: 'step_vehicle_title'.tr(),
                          subtitle: 'step_vehicle_sub'.tr(),
                          isCompleted: isVehicleInfoComplete,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VehicleInfoScreen(),
                              ),
                            );
                            _loadCurrentStatus();
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
                                    'reg_success_msg'.tr(), context);
                              }
                            } catch (e) {
                              debugPrint("Error while saving data: $e");
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAllComplete
                          ? AppColors.primaryButton
                          : Colors.grey.shade400,
                      foregroundColor: AppColors.buttonText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: registrationProvider.isLoading
                        ? const CircularProgressIndicator(color: AppColors.buttonText)
                        : Text(
                            'submit_all_docs'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    'reg_terms_note'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
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
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: isCompleted
          ? const Icon(Icons.check_circle,
              color: AppColors.primaryBrand, size: 26)
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
